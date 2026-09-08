struct RawJSONTypeDocumentationRenderer: Sendable {
    func render(_ document: TypeDocumentationDocument) -> String {
        // DocC JSON has already passed decoding, so preserve a non-optional rendering contract.
        // swiftlint:disable:next optional_data_string_conversion
        return String(decoding: document.data, as: UTF8.self)
    }
}
