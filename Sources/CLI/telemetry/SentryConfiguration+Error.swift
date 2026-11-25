import Foundation

#if canImport(SentrySwift)
    @preconcurrency import SentrySwift

    extension SentryConfiguration {
        static let swiftErrorMechanism = "apple-docs.swift"

        static func errorEvent(for error: any Error) -> Event {
            let event = Event(level: .error)
            let exception: Exception
            switch error {
            case DecodingError.keyNotFound(let key, let context):
                exception = Exception(
                    value: "Missing required key at \(codingPath(context.codingPath + [key]))",
                    type: "Swift.DecodingError.keyNotFound")
            case DecodingError.valueNotFound(let type, let context):
                exception = Exception(
                    value: "Missing \(String(reflecting: type)) value at \(codingPath(context.codingPath))",
                    type: "Swift.DecodingError.valueNotFound")
            case DecodingError.typeMismatch(let type, let context):
                exception = Exception(
                    value: "Expected \(String(reflecting: type)) at \(codingPath(context.codingPath))",
                    type: "Swift.DecodingError.typeMismatch")
            case DecodingError.dataCorrupted(let context):
                exception = Exception(
                    value: "Invalid documentation data at \(codingPath(context.codingPath))",
                    type: "Swift.DecodingError.dataCorrupted")
            default:
                exception = Exception(
                    value: "Command failed (code: \((error as NSError).code))",
                    type: String(reflecting: type(of: error)))
            }
            exception.mechanism = Mechanism(type: swiftErrorMechanism)
            event.exceptions = [exception]
            return event
        }

        private static func codingPath(_ path: [any CodingKey]) -> String {
            path.isEmpty
                ? "<root>"
                : path.map { key in
                    key.intValue.map { "[\($0)]" } ?? key.stringValue
                }.joined(separator: ".")
        }
    }
#endif
