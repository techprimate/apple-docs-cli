import Foundation
import Logging

@testable import CLI

func makeDocumentationRepository<Transport: HTTPDataTransport>(
    logger: Logger, dependencies: Transport,
    baseURL: URL = URL(string: "https://developer.apple.com/tutorials/data/")!
) -> DefaultAppleDocumentationRepository<DefaultAppleDocumentationClient<Transport>> {
    DefaultAppleDocumentationRepository(
        logger: logger,
        dependencies: DefaultAppleDocumentationClient(logger: logger, dependencies: dependencies, baseURL: baseURL))
}
