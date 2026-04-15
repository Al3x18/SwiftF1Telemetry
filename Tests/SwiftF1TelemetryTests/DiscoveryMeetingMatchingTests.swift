import Foundation
import Testing
@testable import SwiftF1Telemetry

@Test func shortQuerySpaDoesNotResolveToSpanishGrandPrix() async throws {
    let client = makeClientForMeetingMatching()

    let sessions = try await client.availableSessions(in: 2023, event: "Spa")
    #expect(sessions.isEmpty == false)
    #expect(Set(sessions.map(\.eventName)) == ["Belgian Grand Prix"])
}

@Test func fullQueryBarcelonaStillResolvesSpanishGrandPrix() async throws {
    let client = makeClientForMeetingMatching()

    let sessions = try await client.availableSessions(in: 2023, event: "Barcelona")
    #expect(sessions.isEmpty == false)
    #expect(Set(sessions.map(\.eventName)) == ["Spanish Grand Prix"])
}

@Test func longerPrefixMonzaMatchesItalianGrandPrix() async throws {
    let client = makeClientForMeetingMatching()

    let sessions = try await client.availableSessions(in: 2023, event: "Monza")
    #expect(sessions.isEmpty == false)
    #expect(Set(sessions.map(\.eventName)) == ["Italian Grand Prix"])
}

private func makeClientForMeetingMatching() -> F1Client {
    let indexJSON = """
    {
      "Year": 2023,
      "Meetings": [
        {
          "Name": "Spanish Grand Prix",
          "OfficialName": "FORMULA 1 AWS GRAN PREMIO DE ESPAÑA 2023",
          "Location": "Barcelona",
          "Circuit": { "ShortName": "Catalunya" },
          "Sessions": [
            {
              "Key": 7001,
              "Type": "Qualifying",
              "Number": null,
              "Name": "Qualifying",
              "StartDate": "2023-06-03T14:00:00",
              "EndDate": "2023-06-03T15:00:00",
              "GmtOffset": "+02:00:00",
              "Path": "2023/spanish/q/"
            }
          ]
        },
        {
          "Name": "Belgian Grand Prix",
          "OfficialName": "FORMULA 1 MSC CRUISES BELGIAN GRAND PRIX 2023",
          "Location": "Spa-Francorchamps",
          "Circuit": { "ShortName": "Spa-Francorchamps" },
          "Sessions": [
            {
              "Key": 7002,
              "Type": "Qualifying",
              "Number": null,
              "Name": "Qualifying",
              "StartDate": "2023-07-28T14:00:00",
              "EndDate": "2023-07-28T15:00:00",
              "GmtOffset": "+02:00:00",
              "Path": "2023/belgian/q/"
            }
          ]
        },
        {
          "Name": "Italian Grand Prix",
          "OfficialName": "FORMULA 1 PIRELLI GRAN PREMIO D’ITALIA 2023",
          "Location": "Monza",
          "Circuit": { "ShortName": "Monza" },
          "Sessions": [
            {
              "Key": 7003,
              "Type": "Qualifying",
              "Number": null,
              "Name": "Qualifying",
              "StartDate": "2023-09-02T14:00:00",
              "EndDate": "2023-09-02T15:00:00",
              "GmtOffset": "+02:00:00",
              "Path": "2023/italian/q/"
            }
          ]
        }
      ]
    }
    """

    let responseMap = [
        "https://livetiming.formula1.com/static/2023/Index.json": Data(indexJSON.utf8),
    ]

    let backend = DefaultBackend(
        httpClient: StubHTTPClient(responses: responseMap),
        cacheStore: MockCacheStore(),
        configuration: .default
    )
    return F1Client(backend: backend, cacheStore: MockCacheStore())
}

private struct StubHTTPClient: HTTPClient {
    let responses: [String: Data]

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let data = responses[request.url.absoluteString] else {
            throw F1TelemetryError.networkFailure(description: "No stub response for \(request.url.absoluteString)")
        }
        return HTTPResponse(statusCode: 200, headers: [:], body: data)
    }
}
