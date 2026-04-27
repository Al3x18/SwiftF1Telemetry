import Foundation
import CZlib

struct RawJSONStreamLine {
    let sessionTime: TimeInterval
    let jsonObject: Any
}

struct RawEnvelopeParser {
    func normalizedData(from data: Data) throws -> Data {
        if data.isEmpty {
            throw F1TelemetryError.parseFailure(dataset: "envelope", description: "Payload is empty")
        }
        return data
    }

    func parseJSONStream(_ string: String) throws -> [RawJSONStreamLine] {
        let normalized = string.replacingOccurrences(of: "\u{feff}", with: "")
        return try normalized
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine in
                let line = String(rawLine)
                guard !line.isEmpty else { return nil }
                guard line.count > 12 else {
                    throw F1TelemetryError.parseFailure(dataset: "jsonStream", description: "Malformed stream line")
                }

                let prefix = String(line.prefix(12))
                let payload = String(line.dropFirst(12))
                let time = TimeUtils.parseClockDuration(prefix) ?? 0
                let payloadData = Data(payload.utf8)
                let object = try JSONSerialization.jsonObject(with: payloadData)
                return RawJSONStreamLine(sessionTime: time, jsonObject: object)
            }
    }

    func parseCompressedJSONStream(_ string: String) throws -> [RawJSONStreamLine] {
        let normalized = string.replacingOccurrences(of: "\u{feff}", with: "")
        return try normalized
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine in
                let line = String(rawLine)
                guard !line.isEmpty else { return nil }
                guard line.count > 12 else {
                    throw F1TelemetryError.parseFailure(dataset: "compressedJsonStream", description: "Malformed compressed stream line")
                }

                let prefix = String(line.prefix(12))
                let encoded = String(line.dropFirst(12)).trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmed = encoded.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                guard let compressedData = Data(base64Encoded: trimmed) else {
                    throw F1TelemetryError.parseFailure(dataset: "compressedJsonStream", description: "Invalid base64 frame")
                }
                let inflated = try inflateRawDeflate(compressedData)
                let object = try JSONSerialization.jsonObject(with: inflated)
                return RawJSONStreamLine(
                    sessionTime: TimeUtils.parseClockDuration(prefix) ?? 0,
                    jsonObject: object
                )
            }
    }

    private func inflateRawDeflate(_ data: Data) throws -> Data {
        if data.isEmpty { return Data() }

        var stream = z_stream()
        var status: Int32
        let windowBits = -MAX_WBITS

        status = inflateInit2_(&stream, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else {
            throw F1TelemetryError.parseFailure(dataset: "compressedJsonStream", description: "inflateInit2 failed with status \(status)")
        }
        defer { inflateEnd(&stream) }

        var output = Data()
        let chunkSize = 16_384
        var mutableInput = data

        return try mutableInput.withUnsafeMutableBytes { inputBuffer in
            guard let inputBase = inputBuffer.bindMemory(to: Bytef.self).baseAddress else {
                throw F1TelemetryError.parseFailure(dataset: "compressedJsonStream", description: "Missing input buffer")
            }

            stream.next_in = inputBase
            stream.avail_in = uInt(data.count)

            repeat {
                var chunk = Data(count: chunkSize)
                let count = try chunk.withUnsafeMutableBytes { outputBuffer -> Int in
                    guard let outputBase = outputBuffer.bindMemory(to: Bytef.self).baseAddress else {
                        throw F1TelemetryError.parseFailure(dataset: "compressedJsonStream", description: "Missing output buffer")
                    }

                    stream.next_out = outputBase
                    stream.avail_out = uInt(chunkSize)
                    status = inflate(&stream, Z_NO_FLUSH)
                    guard status == Z_OK || status == Z_STREAM_END else {
                        throw F1TelemetryError.parseFailure(dataset: "compressedJsonStream", description: "inflate failed with status \(status)")
                    }
                    return chunkSize - Int(stream.avail_out)
                }

                chunk.count = count
                output.append(chunk)
            } while status != Z_STREAM_END

            return output
        }
    }
}
