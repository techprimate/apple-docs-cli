import Foundation

#if DEBUG
    protocol CommandOutputWriting {
        func write(_ line: String)
        func writeWarning(_ warning: String)
    }

    extension DefaultCommandOutputWriter: CommandOutputWriting {}

    protocol CommandOutputWriterProvider {
        associatedtype OutputWriter: CommandOutputWriting
        var commandOutputWriter: OutputWriter { get }
    }

    extension Dependencies: CommandOutputWriterProvider {}
#else
    typealias CommandOutputWriting = DefaultCommandOutputWriter
#endif

struct DefaultCommandOutputWriter {
    func write(_ line: String) {
        print(line)
    }

    func writeWarning(_ warning: String) {
        FileHandle.standardError.write(Data(warning.utf8))
    }
}
