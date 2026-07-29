import Foundation
import SlowWalkAPIContracts

/// Shared loading support for the versioned Medicine demo fixtures.
///
/// `demo-fixtures/` is the single source of truth. Tests locate it by walking
/// upward from this file and looking for `demo-fixtures/README.md` as the
/// repository anchor instead of relying on a fixed number of
/// `deletingLastPathComponent()` calls.
enum DemoFixtureSupport {
    /// Maximum number of parent directories searched for the repository
    /// anchor before giving up.
    static let maximumAnchorSearchDepth = 8

    static let anchorRelativePath = "demo-fixtures/README.md"

    /// Resolves the repository `demo-fixtures` directory or throws a clear
    /// error. A missing fixture directory is a broken checkout and must fail
    /// the test, never skip it.
    static func fixtureDirectory() throws -> URL {
        var directory = URL(
            fileURLWithPath: #filePath
        )
        .deletingLastPathComponent()
        var searched = [directory.path]

        for _ in 0 ... maximumAnchorSearchDepth {
            let anchor = directory.appendingPathComponent(
                anchorRelativePath
            )
            if FileManager.default.fileExists(atPath: anchor.path) {
                return directory.appendingPathComponent("demo-fixtures")
            }
            directory.deleteLastPathComponent()
            searched.append(directory.path)
        }

        throw DemoFixtureLoadError.anchorNotFound(
            anchor: anchorRelativePath,
            searchedDirectories: searched
        )
    }

    /// Loads and decodes one fixture file. Errors always name the fixture
    /// file, the resolved directory, and whether the file exists.
    static func load(
        _ filename: String
    ) throws -> MedicineDemoFixturePayload {
        let directory: URL
        do {
            directory = try fixtureDirectory()
        } catch {
            throw DemoFixtureLoadError.directoryResolutionFailed(
                fixture: filename,
                underlying: error
            )
        }
        let fileURL = directory.appendingPathComponent(filename)
        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        guard exists else {
            throw DemoFixtureLoadError.fixtureMissing(
                fixture: filename,
                directory: directory.path,
                fileExists: false
            )
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw DemoFixtureLoadError.fixtureUnreadable(
                fixture: filename,
                directory: directory.path,
                fileExists: true,
                underlying: error
            )
        }
        do {
            return try SlowWalkJSONCoding.makeDecoder().decode(
                MedicineDemoFixturePayload.self,
                from: data
            )
        } catch {
            throw DemoFixtureLoadError.fixtureUndecodable(
                fixture: filename,
                directory: directory.path,
                fileExists: true,
                underlying: error
            )
        }
    }
}

enum DemoFixtureLoadError: Error, CustomStringConvertible {
    case anchorNotFound(anchor: String, searchedDirectories: [String])
    case directoryResolutionFailed(fixture: String, underlying: any Error)
    case fixtureMissing(fixture: String, directory: String, fileExists: Bool)
    case fixtureUnreadable(
        fixture: String,
        directory: String,
        fileExists: Bool,
        underlying: any Error
    )
    case fixtureUndecodable(
        fixture: String,
        directory: String,
        fileExists: Bool,
        underlying: any Error
    )

    var description: String {
        switch self {
        case let .anchorNotFound(anchor, searched):
            return """
                Could not locate the repository anchor "\(anchor)". \
                Searched upward from the test file through: \
                \(searched.joined(separator: " -> ")). \
                Run tests from a complete repository checkout.
                """
        case let .directoryResolutionFailed(fixture, underlying):
            return """
                Could not resolve demo-fixtures directory while loading \
                "\(fixture)": \(underlying)
                """
        case let .fixtureMissing(fixture, directory, fileExists):
            return """
                Demo fixture "\(fixture)" is missing. \
                Resolved directory: \(directory). \
                File exists: \(fileExists). \
                The demo-fixtures directory is required; the test fails \
                instead of skipping.
                """
        case let .fixtureUnreadable(fixture, directory, fileExists, underlying):
            return """
                Demo fixture "\(fixture)" could not be read. \
                Resolved directory: \(directory). \
                File exists: \(fileExists). Underlying error: \(underlying)
                """
        case let .fixtureUndecodable(fixture, directory, fileExists, underlying):
            return """
                Demo fixture "\(fixture)" could not be decoded as canonical \
                DTOs. Resolved directory: \(directory). \
                File exists: \(fileExists). Underlying error: \(underlying)
                """
        }
    }
}

struct MedicineDemoFixturePayload: Decodable {
    let fixtureID: String
    let disclaimer: String
    let request: MedicineAssessmentRequestDTO
    let response: MedicineAssessmentResponseDTO
    let expectation: MedicineDemoExpectation
}

struct MedicineDemoExpectation: Decodable {
    let allowsOrdinaryExplanation: Bool
    let expectedActionCardPrimaryInstruction: String
    let expectedActionCardTitle: String
    let expectedPresentationVariant: String
    let expectedRiskLevel: String
    let expectedViewState: String
    let recommendContactFamily: Bool
    let recommendContactHealthcareProfessional: Bool
}
