import Testing
@testable import SwiftTerm

@Suite(.serialized)
struct KittyKeyboardTests {
    private func assertLastResponse(_ delegate: TerminalTestDelegate, equals expected: String) {
        guard let last = delegate.sentData.last, let response = String(bytes: last, encoding: .utf8) else {
            #expect(Bool(false))
            return
        }
        #expect(response == expected)
    }

    @Test func testKittyKeyboardQueryPushPop() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 5, rows: 1)

        terminal.feed(text: "\u{1b}[?u")
        assertLastResponse(delegate, equals: "\u{1b}[?0u")

        terminal.feed(text: "\u{1b}[>1u")
        terminal.feed(text: "\u{1b}[?u")
        assertLastResponse(delegate, equals: "\u{1b}[?1u")

        terminal.feed(text: "\u{1b}[>3u")
        terminal.feed(text: "\u{1b}[?u")
        assertLastResponse(delegate, equals: "\u{1b}[?3u")

        terminal.feed(text: "\u{1b}[<u")
        terminal.feed(text: "\u{1b}[?u")
        assertLastResponse(delegate, equals: "\u{1b}[?1u")

        // Pop beyond stack depth should reset to defaults.
        terminal.feed(text: "\u{1b}[<2u")
        terminal.feed(text: "\u{1b}[?u")
        assertLastResponse(delegate, equals: "\u{1b}[?0u")
    }
}
