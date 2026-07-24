import SlowWalkAPIContracts

enum RequestDecodingFailure {
    case malformedJSON
    case validation(APIErrorDetailDTO)

    init(error: DecodingError) {
        switch error {
        case .keyNotFound(let key, let context):
            self = .validation(
                APIErrorDetailDTO(
                    field: Self.fieldPath(
                        context.codingPath,
                        appending: key
                    ),
                    code: "missing_required_field",
                    message: "A required field is missing."
                )
            )

        case .valueNotFound(_, let context):
            self = .validation(
                APIErrorDetailDTO(
                    field: Self.fieldPath(context.codingPath),
                    code: "missing_required_value",
                    message: "A required field cannot be null."
                )
            )

        case .typeMismatch(_, let context):
            self = .validation(
                APIErrorDetailDTO(
                    field: Self.fieldPath(context.codingPath),
                    code: "invalid_type",
                    message: "The field has an invalid JSON type."
                )
            )

        case .dataCorrupted(let context):
            if let field = Self.fieldPath(context.codingPath) {
                self = .validation(
                    APIErrorDetailDTO(
                        field: field,
                        code: "invalid_value",
                        message: "The field value is invalid."
                    )
                )
            } else {
                self = .malformedJSON
            }

        @unknown default:
            self = .malformedJSON
        }
    }

    private static func fieldPath(
        _ codingPath: [any CodingKey],
        appending key: (any CodingKey)? = nil
    ) -> String? {
        var components = codingPath.map { $0.stringValue }
        if let key {
            components.append(key.stringValue)
        }
        guard !components.isEmpty else {
            return nil
        }
        return components.joined(separator: ".")
    }
}
