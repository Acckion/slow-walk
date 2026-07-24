import Foundation
import SlowWalkDomain

/// Deterministic, cross-platform normalization for simulated OCR medicine text.
///
/// The normalizer deliberately avoids fuzzy correction and does not invent
/// medicine names. It only folds text, removes known presentation noise, and
/// records every removed value in `NormalizedMedicineName`.
public protocol MedicineNameNormalizing: Sendable {
    func normalize(
        _ input: MedicineRecognitionInput
    ) -> NormalizedMedicineName
    func normalizeName(_ value: String) -> String
    func normalizeQuery(_ value: String) -> String
}

public struct MedicineNameNormalizer: MedicineNameNormalizing, Sendable {
    public static let version = "slowwalk-name-normalizer-v1"

    private static let dosageFormTokens: Set<String> = [
        "capsule",
        "capsules",
        "cream",
        "injection",
        "ointment",
        "solution",
        "spray",
        "syrup",
        "tablet",
        "tablets",
        "分散片",
        "口服液",
        "咀嚼片",
        "喷雾",
        "注射液",
        "片",
        "片剂",
        "缓释片",
        "肠溶片",
        "胶囊",
        "胶囊剂",
        "软膏",
        "颗粒",
        "颗粒剂",
    ]

    private static let dosageFormSuffixes = dosageFormTokens.sorted {
        if $0.count != $1.count {
            return $0.count > $1.count
        }
        return $0 < $1
    }

    private static let discardedNoiseTokens: Set<String> = [
        "demo",
        "medicine",
        "otc",
        "rx",
        "sample",
        "国药准字",
        "演示",
        "药品",
    ]

    private static let englishManufacturerMarkers: Set<String> = [
        "co",
        "company",
        "corporation",
        "inc",
        "limited",
        "ltd",
        "pharma",
        "pharmaceutical",
        "pharmaceuticals",
    ]

    private static let chineseManufacturerMarkers: Set<String> = [
        "制药",
        "制药厂",
        "医药",
        "有限公司",
        "药业",
    ]

    private static let specificationUnits: Set<String> = [
        "g",
        "iu",
        "kg",
        "l",
        "mcg",
        "mg",
        "ml",
        "percent",
        "ug",
        "unit",
        "units",
        "支",
        "片",
        "粒",
        "袋",
    ]

    private static let specificationUnitSuffixes =
        specificationUnits.sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0 < $1
        }

    public init() {}

    public func normalize(
        _ input: MedicineRecognitionInput
    ) -> NormalizedMedicineName {
        let normalizedLines = input.recognizedTexts
            .flatMap {
                $0.components(separatedBy: .newlines)
            }
            .map(normalizeName)
            .filter { !$0.isEmpty }
        let lineAnalyses = normalizedLines.map(analyze)
        let normalizedText = normalizedLines.joined(separator: " ")
        let combinedAnalysis = analyze(normalizedText)

        let primaryQuery = lineAnalyses
            .map(\.query)
            .first(where: { !$0.isEmpty })
            ?? combinedAnalysis.query
        let variants = uniqueInEncounterOrder(
            [primaryQuery]
                + lineAnalyses.map(\.query)
                + [combinedAnalysis.query]
        )
        .filter { !$0.isEmpty }

        return NormalizedMedicineName(
            normalizedText: normalizedText,
            normalizedQuery: primaryQuery,
            queryVariants: variants,
            dosageForms: uniqueInEncounterOrder(
                lineAnalyses.flatMap(\.dosageForms)
            ),
            removedSpecifications: uniqueInEncounterOrder(
                lineAnalyses.flatMap(\.removedSpecifications)
            ),
            discardedNoise: uniqueInEncounterOrder(
                lineAnalyses.flatMap(\.discardedNoise)
            )
        )
    }

    /// A stable comparison key that preserves specifications and dosage forms.
    public func normalizeName(_ value: String) -> String {
        let folded = value.folding(
            options: [
                .caseInsensitive,
                .diacriticInsensitive,
                .widthInsensitive,
            ],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let percentageAware = folded.replacingOccurrences(
            of: "%",
            with: " percent "
        )
        let decimalJoined = percentageAware.replacingOccurrences(
            of: ".",
            with: ""
        )
        let separated = decimalJoined.unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar)
                ? String(scalar)
                : " "
        }
        .joined()

        return separated
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: " ")
    }

    /// A catalog-side key using the same conservative stripping as OCR input.
    public func normalizeQuery(_ value: String) -> String {
        analyze(normalizeName(value)).query
    }

    private func analyze(_ normalizedValue: String) -> TokenAnalysis {
        let tokens = normalizedValue
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        if tokens.contains(where: isManufacturerMarker) {
            return TokenAnalysis(
                query: "",
                dosageForms: [],
                removedSpecifications: [],
                discardedNoise: tokens
            )
        }
        var retained = [String]()
        var dosageForms = [String]()
        var removedSpecifications = [String]()
        var discardedNoise = [String]()
        var index = 0

        while index < tokens.count {
            var token = tokens[index]

            if Self.discardedNoiseTokens.contains(token) {
                discardedNoise.append(token)
                index += 1
                continue
            }

            if token.allSatisfy(\.isNumber),
               index + 1 < tokens.count,
               Self.specificationUnits.contains(tokens[index + 1]) {
                if Self.dosageFormTokens.contains(tokens[index + 1]) {
                    dosageForms.append(tokens[index + 1])
                }
                removedSpecifications.append(
                    "\(token) \(tokens[index + 1])"
                )
                index += 2
                continue
            }

            if let split = splitSpecificationSuffix(token) {
                removedSpecifications.append(split.specification)
                if let dosageForm = split.dosageForm {
                    dosageForms.append(dosageForm)
                }
                guard !split.base.isEmpty else {
                    index += 1
                    continue
                }
                token = split.base
            }

            if Self.dosageFormTokens.contains(token) {
                dosageForms.append(token)
                index += 1
                continue
            }

            if let split = splitDosageFormSuffix(token) {
                dosageForms.append(split.dosageForm)
                if !split.base.isEmpty {
                    retained.append(split.base)
                }
                index += 1
                continue
            }

            retained.append(token)
            index += 1
        }

        return TokenAnalysis(
            query: retained.joined(separator: " "),
            dosageForms: dosageForms,
            removedSpecifications: removedSpecifications,
            discardedNoise: discardedNoise
        )
    }

    private func splitSpecificationSuffix(
        _ token: String
    ) -> (
        base: String,
        specification: String,
        dosageForm: String?
    )? {
        guard let digitIndex = token.firstIndex(where: \.isNumber) else {
            return nil
        }

        let base = String(token[..<digitIndex])
        let suffix = String(token[digitIndex...])
        guard let unit = specificationUnit(in: suffix) else {
            return nil
        }
        let dosageForm = Self.dosageFormTokens.contains(unit)
            ? unit
            : nil
        return (base, suffix, dosageForm)
    }

    private func specificationUnit(in value: String) -> String? {
        guard value.contains(where: \.isNumber) else {
            return nil
        }

        return Self.specificationUnitSuffixes.first { unit in
            guard value.hasSuffix(unit) else {
                return false
            }
            let numericPart = value.dropLast(unit.count)
            return !numericPart.isEmpty
                && numericPart.allSatisfy(\.isNumber)
        }
    }

    private func isManufacturerMarker(_ token: String) -> Bool {
        Self.englishManufacturerMarkers.contains(token)
            || Self.chineseManufacturerMarkers.contains {
                token.contains($0)
            }
    }

    private func splitDosageFormSuffix(
        _ token: String
    ) -> (base: String, dosageForm: String)? {
        for dosageForm in Self.dosageFormSuffixes
        where token != dosageForm && token.hasSuffix(dosageForm) {
            return (
                String(token.dropLast(dosageForm.count)),
                dosageForm
            )
        }
        return nil
    }

    private func uniqueInEncounterOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

/// Compatibility alias for callers that adopted the initial draft name.
public typealias NameNormalizer = MedicineNameNormalizer

private struct TokenAnalysis {
    let query: String
    let dosageForms: [String]
    let removedSpecifications: [String]
    let discardedNoise: [String]
}
