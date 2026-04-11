import Foundation

struct DefaultBackend: BackendProtocol, Sendable {
    private let baseURL = URL(string: "https://livetiming.formula1.com/static/")!
    private let httpClient: HTTPClient
    private let cacheStore: CacheStore
    private let configuration: F1Client.Configuration
    private let decoder: JSONDecoder

    init(
        httpClient: HTTPClient,
        cacheStore: CacheStore,
        configuration: F1Client.Configuration
    ) {
        self.httpClient = httpClient
        self.cacheStore = cacheStore
        self.configuration = configuration
        self.decoder = JSONDecoder()
    }

    func resolveSession(
        year: Int,
        meeting: String,
        session: SessionType
    ) async throws -> SessionRef {
        let indexData = try await fetchDirect(relativePath: "\(year)/Index.json")
        let season = try decoder.decode(RawSeasonIndex.self, from: indexData)

        guard let matchedMeeting = season.meetings.first(where: { matchesMeeting(query: meeting, meeting: $0) }),
              let matchedSession = matchedMeeting.sessions.first(where: { matchesSession(type: session, archiveSession: $0) }) else {
            throw F1TelemetryError.sessionNotFound(year: year, meeting: meeting, session: session.rawValue)
        }

        return SessionRef(
            year: year,
            meeting: matchedMeeting.name,
            sessionType: session,
            backendIdentifier: String(matchedSession.key),
            archivePath: matchedSession.path
        )
    }

    func fetchSessionMetadata(for session: SessionRef) async throws -> Data {
        let key = CacheKey(session: session, dataset: "metadata")
        return try await cachedData(for: key) {
            let info = try await fetchText(relativePath: session.archivePath + "SessionInfo.jsonStream")
            let sessionData = try await fetchText(relativePath: session.archivePath + "SessionData.json")
            return try JSONEncoder().encode(
                RawSessionMetadataEnvelope(
                    sessionInfoStream: info,
                    sessionDataJSON: sessionData
                )
            )
        }
    }

    func fetchTimingData(for session: SessionRef) async throws -> Data {
        let key = CacheKey(session: session, dataset: "timing")
        return try await cachedData(for: key) {
            let timingData = try await fetchText(relativePath: session.archivePath + "TimingData.jsonStream")
            let timingAppData = try? await fetchText(relativePath: session.archivePath + "TimingAppData.jsonStream")
            let heartbeat = try? await fetchText(relativePath: session.archivePath + "Heartbeat.jsonStream")
            let sessionStartDate = try? await resolvedSessionStart(for: session)
            return try JSONEncoder().encode(
                RawTimingEnvelope(
                    timingDataStream: timingData,
                    timingAppDataStream: timingAppData,
                    heartbeatStream: heartbeat,
                    sessionStartDate: sessionStartDate
                )
            )
        }
    }

    func fetchCarData(for session: SessionRef) async throws -> Data {
        let key = CacheKey(session: session, dataset: "car")
        return try await cachedData(for: key) {
            let sessionStartDate = try await resolvedSessionStart(for: session)
            let stream = try await fetchText(relativePath: session.archivePath + "CarData.z.jsonStream")
            return try JSONEncoder().encode(
                RawTelemetryEnvelope(
                    sessionStartDate: sessionStartDate,
                    stream: stream
                )
            )
        }
    }

    func fetchPositionData(for session: SessionRef) async throws -> Data {
        let key = CacheKey(session: session, dataset: "position")
        return try await cachedData(for: key) {
            let sessionStartDate = try await resolvedSessionStart(for: session)
            let stream = try await fetchText(relativePath: session.archivePath + "Position.z.jsonStream")
            return try JSONEncoder().encode(
                RawTelemetryEnvelope(
                    sessionStartDate: sessionStartDate,
                    stream: stream
                )
            )
        }
    }

    private func cachedData(
        for key: CacheKey,
        fetcher: @Sendable () async throws -> Data
    ) async throws -> Data {
        if let data = try await cacheStore.data(for: key) {
            return data
        }

        let data = try await fetcher()
        try await cacheStore.save(data, for: key)
        return data
    }

    private func fetchDirect(relativePath: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(relativePath)
        let request = HTTPRequest(
            url: url,
            headers: [
                "User-Agent": configuration.userAgent,
                "Accept-Encoding": "gzip, identity",
                "Connection": "close",
                "TE": "identity",
            ],
            timeout: configuration.requestTimeout
        )
        let response = try await httpClient.execute(request)
        return response.body
    }

    private func fetchText(relativePath: String) async throws -> String {
        let data = try await fetchDirect(relativePath: relativePath)
        guard let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf8) else {
            throw F1TelemetryError.invalidResponse(description: "Unable to decode UTF-8 payload at \(relativePath)")
        }
        return string
    }

    private func resolvedSessionStart(for session: SessionRef) async throws -> Date {
        let metadataData = try await fetchSessionMetadata(for: session)
        let metadata = try SessionParser().parseMetadata(from: metadataData)
        guard let actualStart = metadata.actualStart else {
            throw F1TelemetryError.invalidResponse(description: "Missing session start date for \(session.archivePath)")
        }
        return actualStart
    }

    private func matchesMeeting(query: String, meeting: RawMeeting) -> Bool {
        let normalizedQuery = normalize(query)
        let candidates = [
            meeting.name,
            meeting.officialName,
            meeting.location,
            meeting.circuit.shortName,
        ].map(normalize)

        return candidates.contains(where: { $0.contains(normalizedQuery) || normalizedQuery.contains($0) })
    }

    private func matchesSession(type: SessionType, archiveSession: RawArchiveSession) -> Bool {
        let normalizedName = normalize(archiveSession.name)
        let normalizedType = normalize(archiveSession.type)

        switch type {
        case .practice1:
            return normalizedType == "practice" && archiveSession.number == 1
        case .practice2:
            return normalizedType == "practice" && archiveSession.number == 2
        case .practice3:
            return normalizedType == "practice" && archiveSession.number == 3
        case .sprintShootout:
            return normalizedName.contains("sprintqualifying") || normalizedName.contains("sprintshootout")
        case .sprint:
            return normalizedName == "sprint"
        case .qualifying:
            return normalizedName == "qualifying"
        case .race:
            return normalizedName == "race"
        }
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
