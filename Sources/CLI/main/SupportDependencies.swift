#if DEBUG
    protocol AppleSupportServiceProvider {
        associatedtype SupportService: AppleSupportService
        var supportService: SupportService { get }
    }

    protocol SupportRendererProvider {
        associatedtype SupportOutputRenderer: SupportRenderer
        func supportRenderer(output: OutputOptions) -> SupportOutputRenderer
    }

    typealias SupportCommandDependencies = any (
        AppleSupportServiceProvider & SupportRendererProvider & CommandOutputWriterProvider & TelemetryProvider
    )
    extension Dependencies: AppleSupportServiceProvider, SupportRendererProvider {}
#else
    typealias SupportCommandDependencies = Dependencies
#endif

extension Dependencies {
    func supportRenderer(output: OutputOptions) -> DefaultSupportRenderer {
        DefaultSupportRenderer(output: output.format, audience: output.audience)
    }
}
