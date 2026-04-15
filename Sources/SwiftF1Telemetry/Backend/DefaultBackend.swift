import Foundation

struct DefaultBackend: BackendProtocol, Sendable {
    private let baseURL = URL(string: "https://livetiming.formula1.com/static/")!
    private let minimumArchiveYear = 2018
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

    func availableYears() async throws -> [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        var years: [Int] = []

        for year in stride(from: currentYear, through: minimumArchiveYear, by: -1) {
            do {
                _ = try await seasonIndex(for: year)
                years.append(year)
            } catch let error as F1TelemetryError {
                switch error {
                case .networkFailure, .invalidResponse:
                    continue
                default:
                    throw error
                }
            }
        }

        return years.sorted()
    }

    func availableEvents(in year: Int) async throws -> [EventDescriptor] {
        let season = try await availableSeasonIndex(for: year)
        return season.meetings.map { meeting in
            EventDescriptor(
                year: year,
                name: meeting.name,
                officialName: meeting.officialName,
                location: meeting.location,
                circuitName: meeting.circuit.shortName
            )
        }
    }

    func availableSessions(in year: Int, event: String) async throws -> [SessionDescriptor] {
        let season = try await availableSeasonIndex(for: year)

        guard let meeting = season.meetings.first(where: { matchesMeeting(query: event, meeting: $0) }) else {
            throw F1TelemetryError.eventNotAvailable(year: year, event: event)
        }

        let sessions: [SessionDescriptor] = meeting.sessions.compactMap { archiveSession in
            guard archiveSession.path != nil,
                  archiveSession.key != nil,
                  let sessionType = sessionType(for: archiveSession) else { return nil }
            return SessionDescriptor(
                year: year,
                eventName: meeting.name,
                sessionType: sessionType,
                name: archiveSessionDisplayName(archiveSession),
                startDate: parseArchiveDate(archiveSession.startDate, gmtOffset: archiveSession.gmtOffset),
                endDate: parseArchiveDate(archiveSession.endDate, gmtOffset: archiveSession.gmtOffset)
            )
        }

        guard sessions.isEmpty == false else {
            throw F1TelemetryError.sessionNotAvailable(year: year, event: meeting.name, session: "any supported session")
        }

        return sessions
    }

    func resolveSession(
        year: Int,
        meeting: String,
        session: SessionType
    ) async throws -> SessionRef {
        let season = try await seasonIndex(for: year)

        guard let matchedMeeting = season.meetings.first(where: { matchesMeeting(query: meeting, meeting: $0) }),
              let matchedSession = matchedMeeting.sessions.first(where: {
                  $0.path != nil && $0.key != nil && sessionType(for: $0) == session
              }),
              let matchedKey = matchedSession.key,
              let matchedPath = matchedSession.path else {
            throw F1TelemetryError.sessionNotFound(year: year, meeting: meeting, session: session.rawValue)
        }

        return SessionRef(
            year: year,
            meeting: matchedMeeting.name,
            sessionType: session,
            backendIdentifier: String(matchedKey),
            archivePath: matchedPath
        )
    }

    func fetchSessionMetadata(for session: SessionRef) async throws -> Data {
        let key = CacheKey(session: session, dataset: "metadata")
        return try await cachedData(for: key) {
            async let info = fetchText(relativePath: session.archivePath + "SessionInfo.jsonStream")
            async let sessionData = try? fetchText(relativePath: session.archivePath + "SessionData.json")
            return try JSONEncoder().encode(
                RawSessionMetadataEnvelope(
                    sessionInfoStream: try await info,
                    // Some historical sessions return 403 for SessionData.json.
                    // Keep metadata loading resilient by falling back to an empty payload.
                    sessionDataJSON: (await sessionData) ?? "{}"
                )
            )
        }
    }

    func fetchTimingData(for session: SessionRef) async throws -> Data {
        let key = CacheKey(session: session, dataset: "timing")
        return try await cachedData(for: key) {
            async let td = fetchText(relativePath: session.archivePath + "TimingData.jsonStream")
            async let tad = fetchText(relativePath: session.archivePath + "TimingAppData.jsonStream")
            async let hb = fetchText(relativePath: session.archivePath + "Heartbeat.jsonStream")
            async let ssd = resolvedSessionStart(for: session)
            return try JSONEncoder().encode(
                RawTimingEnvelope(
                    timingDataStream: try await td,
                    timingAppDataStream: try? await tad,
                    heartbeatStream: try? await hb,
                    sessionStartDate: try? await ssd
                )
            )
        }
    }

    func fetchCarData(for session: SessionRef) async throws -> Data {
        let key = CacheKey(session: session, dataset: "car")
        return try await cachedData(for: key) {
            async let sessionStartDate = resolvedSessionStart(for: session)
            async let stream = fetchText(relativePath: session.archivePath + "CarData.z.jsonStream")
            return try JSONEncoder().encode(
                RawTelemetryEnvelope(
                    sessionStartDate: try await sessionStartDate,
                    stream: try await stream
                )
            )
        }
    }

    func fetchPositionData(for session: SessionRef) async throws -> Data {
        let key = CacheKey(session: session, dataset: "position")
        return try await cachedData(for: key) {
            async let sessionStartDate = resolvedSessionStart(for: session)
            async let stream = fetchText(relativePath: session.archivePath + "Position.z.jsonStream")
            return try JSONEncoder().encode(
                RawTelemetryEnvelope(
                    sessionStartDate: try await sessionStartDate,
                    stream: try await stream
                )
            )
        }
    }

    func fetchDriverList(for session: SessionRef) async throws -> Data {
        let key = CacheKey(session: session, dataset: "driverlist")
        return try await cachedData(for: key) {
            let text = try await fetchText(relativePath: session.archivePath + "DriverList.jsonStream")
            return Data(text.utf8)
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

    private func seasonIndex(for year: Int) async throws -> RawSeasonIndex {
        let currentYear = Calendar.current.component(.year, from: Date())
        let indexData: Data
        if year < currentYear {
            let key = CacheKey(yearIndex: year)
            indexData = try await cachedData(for: key) {
                try await fetchDirect(relativePath: "\(year)/Index.json")
            }
        } else {
            indexData = try await fetchDirect(relativePath: "\(year)/Index.json")
        }

        return try decoder.decode(RawSeasonIndex.self, from: indexData)
    }

    private func availableSeasonIndex(for year: Int) async throws -> RawSeasonIndex {
        do {
            return try await seasonIndex(for: year)
        } catch let error as F1TelemetryError {
            switch error {
            case .networkFailure, .invalidResponse:
                throw F1TelemetryError.yearNotAvailable(year: year)
            default:
                throw error
            }
        }
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
        if let actualStart = metadata.actualStart {
            return actualStart
        }
        if let scheduledStart = metadata.scheduledStart {
            return scheduledStart
        }
        throw F1TelemetryError.invalidResponse(description: "Missing session start date for \(session.archivePath)")
    }

    private func matchesMeeting(query: String, meeting: RawMeeting) -> Bool {
        let normalizedQuery = normalize(query)
        let queryTokens = tokens(from: query)
        let rawCandidates = [
            meeting.name,
            meeting.officialName,
            meeting.location,
            meeting.circuit.shortName,
        ]

        let normalizedCandidates = rawCandidates.map(normalize)
        if normalizedCandidates.contains(normalizedQuery) {
            return true
        }

        // Avoid overly broad substring matching (e.g. "spa" matching "españa")
        // by only applying contains checks for longer queries.
        if normalizedQuery.count >= 4,
           normalizedCandidates.contains(where: { $0.contains(normalizedQuery) }) {
            return true
        }

        guard !queryTokens.isEmpty else { return false }
        let candidateTokens = rawCandidates.flatMap(tokens)
        return queryTokens.allSatisfy { queryToken in
            if queryToken.count <= 3 {
                return candidateTokens.contains(queryToken)
            }
            return candidateTokens.contains(where: { candidate in
                candidate == queryToken || candidate.hasPrefix(queryToken)
            })
        }
    }

    private func sessionType(for archiveSession: RawArchiveSession) -> SessionType? {
        let normalizedName = normalize(archiveSession.name ?? archiveSession.type)
        let normalizedType = normalize(archiveSession.type)

        if normalizedType == "practice" && archiveSession.number == 1 {
            return .practice1
        }
        if normalizedType == "practice" && archiveSession.number == 2 {
            return .practice2
        }
        if normalizedType == "practice" && archiveSession.number == 3 {
            return .practice3
        }
        if normalizedName.contains("sprintqualifying") || normalizedName.contains("sprintshootout") {
            return .sprintShootout
        }
        if normalizedName == "sprint" {
            return .sprint
        }
        if normalizedName == "qualifying" {
            return .qualifying
        }
        if normalizedName == "race" {
            return .race
        }
        return nil
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func tokens(from value: String) -> [String] {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func parseArchiveDate(_ value: String?, gmtOffset: String?) -> Date? {
        guard let value,
              let localDate = TimeUtils.parseArchiveLocalDate(value),
              let offset = parsedGMTOffset(gmtOffset ?? "+00:00:00") else {
            return nil
        }
        return localDate.addingTimeInterval(-offset)
    }

    private func parsedGMTOffset(_ value: String) -> TimeInterval? {
        guard !value.isEmpty else { return nil }
        let sign: Double = value.first == "-" ? -1 : 1
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "+-"))
        guard let duration = TimeUtils.parseClockDuration(trimmed) else { return nil }
        return sign * duration
    }

    private func archiveSessionDisplayName(_ archiveSession: RawArchiveSession) -> String {
        if let name = archiveSession.name, !name.isEmpty {
            return name
        }

        if normalize(archiveSession.type) == "practice", let number = archiveSession.number {
            return "Practice \(number)"
        }

        return archiveSession.type
    }
}
