import Twill

struct KeyBindingsFooter: View {
    struct Binding {
        let key: String
        let action: String
    }

    let bindings: [Binding]

    var body: some View {
        Text(bindings.map { "\($0.key): \($0.action)" }.joined(separator: "  "))
    }
}
