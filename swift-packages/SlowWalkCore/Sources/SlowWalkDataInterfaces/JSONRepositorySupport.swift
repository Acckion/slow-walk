import Foundation
import SlowWalkDomain

public enum JSONRepositoryError: Error, Sendable, Equatable {
    case fileNotFound
    case emptyFile
    case corruptedJSON
    case unsupportedSchemaVersion(found: Int)
    case unableToCreateDirectory
    case atomicWriteFailed
}

struct JSONRepositoryFile<Value: Codable & Sendable>: Sendable {
    let baseDirectory: URL
    let fileName: String
    let schemaVersion: Int
    let uuidProvider: any UUIDProviding

    var fileURL: URL {
        baseDirectory.appendingPathComponent(
            fileName,
            isDirectory: false
        )
    }

    func load() throws -> [Value] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else {
            throw JSONRepositoryError.fileNotFound
        }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            throw JSONRepositoryError.emptyFile
        }

        let decoder = Self.makeDecoder()
        let header: JSONRepositorySchemaHeader
        do {
            header = try decoder.decode(
                JSONRepositorySchemaHeader.self,
                from: data
            )
        } catch {
            throw JSONRepositoryError.corruptedJSON
        }
        guard header.schemaVersion == schemaVersion else {
            throw JSONRepositoryError.unsupportedSchemaVersion(
                found: header.schemaVersion
            )
        }
        do {
            return try decoder.decode(
                JSONRepositoryEnvelope<Value>.self,
                from: data
            ).records
        } catch {
            throw JSONRepositoryError.corruptedJSON
        }
    }

    func write(_ values: [Value]) throws {
        let manager = FileManager.default
        do {
            try manager.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            throw JSONRepositoryError.unableToCreateDirectory
        }

        let data: Data
        do {
            data = try Self.makeEncoder().encode(
                JSONRepositoryEnvelope(
                    schemaVersion: schemaVersion,
                    records: values
                )
            )
        } catch {
            throw JSONRepositoryError.atomicWriteFailed
        }

        let token = uuidProvider.makeUUID().uuidString
        let temporaryURL = baseDirectory.appendingPathComponent(
            ".\(fileName).\(token).tmp",
            isDirectory: false
        )
        let backupName = ".\(fileName).\(token).backup"
        defer {
            if manager.fileExists(atPath: temporaryURL.path) {
                try? manager.removeItem(at: temporaryURL)
            }
            let backupURL = baseDirectory.appendingPathComponent(
                backupName,
                isDirectory: false
            )
            if manager.fileExists(atPath: backupURL.path) {
                try? manager.removeItem(at: backupURL)
            }
        }

        do {
            try data.write(to: temporaryURL, options: .withoutOverwriting)
            if manager.fileExists(atPath: fileURL.path) {
                _ = try manager.replaceItemAt(
                    fileURL,
                    withItemAt: temporaryURL,
                    backupItemName: backupName
                )
            } else {
                try manager.moveItem(
                    at: temporaryURL,
                    to: fileURL
                )
            }
        } catch {
            throw JSONRepositoryError.atomicWriteFailed
        }
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct JSONRepositorySchemaHeader: Decodable {
    let schemaVersion: Int
}

private struct JSONRepositoryEnvelope<Value: Codable & Sendable>:
    Codable,
    Sendable
{
    let schemaVersion: Int
    let records: [Value]
}
