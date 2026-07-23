import Foundation

/// Factory for API v1 JSON coders.
///
/// A new coder is returned for each use because Foundation coders are mutable
/// reference types and should not be shared across concurrent requests.
public enum SlowWalkJSONCoding {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, valueEncoder in
            var container = valueEncoder.singleValueContainer()
            try container.encode(ISO8601DateCodec.string(from: date))
        }
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { valueDecoder in
            let container = try valueDecoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = ISO8601DateCodec.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected an ISO 8601 UTC date string."
                )
            }
            return date
        }
        return decoder
    }
}

private enum ISO8601DateCodec {
    static func string(from date: Date) -> String {
        makeFormatter(includingFractionalSeconds: true).string(from: date)
    }

    static func date(from value: String) -> Date? {
        let fractionalFormatter = makeFormatter(includingFractionalSeconds: true)
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let wholeSecondsFormatter = makeFormatter(includingFractionalSeconds: false)
        return wholeSecondsFormatter.date(from: value)
    }

    private static func makeFormatter(
        includingFractionalSeconds: Bool
    ) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        if includingFractionalSeconds {
            formatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds,
            ]
        } else {
            formatter.formatOptions = [.withInternetDateTime]
        }
        return formatter
    }
}
