import Foundation
import Testing
@testable import SwiftF1Telemetry

@Test func parsersDecodeTypedPayloads() throws {
    let metadataData = try JSONEncoder().encode(
        RawSessionMetadata(
            officialName: "2026 Monza Grand Prix",
            circuitName: "Monza",
            scheduledStart: nil,
            actualStart: nil,
            timezoneIdentifier: "Europe/Rome"
        )
    )

    let sessionMetadata = try SessionParser().parseMetadata(from: metadataData)
    #expect(sessionMetadata.officialName == "2026 Monza Grand Prix")

    let timingData = try JSONEncoder().encode([
        RawLapRecord(
            driverNumber: "16",
            lapNumber: 2,
            startSessionTime: 90,
            endSessionTime: 178.4,
            lapTime: 88.4,
            sector1: 29,
            sector2: 29,
            sector3: 30.4,
            isAccurate: true
        )
    ])

    let laps = try TimingParser().parseLaps(from: timingData)
    #expect(laps.count == 1)
    #expect(laps.first?.driverNumber == "16")
}

@Test func archiveCarAndPositionFormatsAreParsed() throws {
    let sessionStart = try #require(TimeUtils.parseISO8601("2024-08-31T14:00:00.070Z"))

    let carStream = """
    00:01:14.306"7ZQxC8MgEIX/y81JuDs1imvIP2iXlg6hBFooDmm24H9vYucub+ni8hT1g7vn8TYa07o85zfF60bn9U6RlNW2HFojJzHRcRTpvFhxvblQQ8O07K83kkOGx5TS/CoHTJEb0qKmqC3qvvtjyblcQZwFOWEURDsUuNQeBQMIKmqOKgqi/6+oq+rRSUUHwMIzjvboHAj2aKkedTVgru7o74DSjr0VVl8DqgZUDagaUH8JqFv+AA=="
    """
    let carEnvelope = try JSONEncoder().encode(RawTelemetryEnvelope(sessionStartDate: sessionStart, stream: carStream))
    let carSamples = try CarDataParser().parseSamples(from: carEnvelope)
    #expect(carSamples.contains { $0.driverNumber == "16" && $0.rpm == 0 })

    let positionStream = """
    00:00:28.259"7ZOxDoIwEIbf5WYk7dH2oLuzJjIoxoEYBmIAA3UivLvoC9ibZLjlT5p8w9+7+2Y4DlMb2qEHf52hbLtmCnX3BA+o0OxUvst0qTNvCo821YaoyPIKEtj3YWybCfwM+hOnUIfX+oRDX471/bEiZ/Aqgcs3qzWXBLJ41MSjWjFYRlvN6eAYbB7PIuNviAyWsQpkzAGJcQ2MXRjO6TD6WhvPOkYHYswhj57DsiS/LTWOyFgtloqlYulmLSUkUtaJpWKpWLpRS12qkJw4Ko6Ko39y9La8AQ=="
    """
    let positionEnvelope = try JSONEncoder().encode(RawTelemetryEnvelope(sessionStartDate: sessionStart, stream: positionStream))
    let positionSamples = try PositionParser().parseSamples(from: positionEnvelope)
    #expect(positionSamples.contains { $0.driverNumber == "16" && $0.status == "OnTrack" })
}
