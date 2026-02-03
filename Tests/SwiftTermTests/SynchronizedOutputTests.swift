import Testing
@testable import SwiftTerm

@Suite(.serialized)
@MainActor
final class SynchronizedOutputTests {
    private class TestDelegate: TerminalDelegate {
        func showCursor(source: Terminal) {}
        func hideCursor(source: Terminal) {}
        func setTerminalTitle(source: Terminal, title: String) {}
        func setTerminalIconTitle(source: Terminal, title: String) {}
        func windowCommand(source: Terminal, command: Terminal.WindowManipulationCommand) -> [UInt8]? { return nil }
        func sizeChanged(source: Terminal) {}
        func send(source: Terminal, data: ArraySlice<UInt8>) {}
        func scrolled(source: Terminal, yDisp: Int) {}
        func linefeed(source: Terminal) {}
        func bufferActivated(source: Terminal) {}
        func bell(source: Terminal) {}
    }

    private func topLineText(from buffer: Buffer, terminal: Terminal? = nil) -> String {
        let characterProvider: ((CharData) -> Character)?
        if let terminal {
            characterProvider = { terminal.getCharacter(for: $0) }
        } else {
            characterProvider = nil
        }
        return buffer.translateBufferLineToString(
            lineIndex: buffer.yDisp,
            trimRight: true,
            startCol: 0,
            endCol: -1,
            skipNullCellsFollowingWide: true,
            characterProvider: characterProvider
        ).replacingOccurrences(of: "\u{0}", with: " ")
    }

    // MARK: - Synchronized Output (Mode 2026)

    @Test func testSynchronizedOutputBlocksDisplayUntilReset() {
        let terminal = Terminal(
            delegate: TestDelegate(),
            options: TerminalOptions(cols: 20, rows: 5, scrollback: 0)
        )
        let esc = "\u{1b}"

        terminal.feed(text: "\(esc)[2J\(esc)[HOLD")
        #expect(topLineText(from: terminal.displayBuffer).hasPrefix("OLD"))

        terminal.feed(text: "\(esc)[?2026h")
        terminal.feed(text: "\(esc)[2J\(esc)[HNEW")

        #expect(topLineText(from: terminal.displayBuffer).hasPrefix("OLD"))
        #expect(topLineText(from: terminal.buffer).hasPrefix("NEW"))

        terminal.feed(text: "\(esc)[?2026l")
        #expect(topLineText(from: terminal.displayBuffer).hasPrefix("NEW"))
    }

    @Test func testSynchronizedOutputQueryReportsCorrectState() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Query mode 2026 before activation
        terminal.feed(text: "\u{1b}[?2026$p")
        if let last = delegate.sentData.last, let response = String(bytes: last, encoding: .utf8) {
            // DECRPM: should contain 2026;2 (reset)
            #expect(response.contains("2026") == true)
        }

        // Activate mode 2026
        terminal.feed(text: "\u{1b}[?2026h")

        // Query again
        terminal.feed(text: "\u{1b}[?2026$p")
        if let last = delegate.sentData.last, let response = String(bytes: last, encoding: .utf8) {
            // DECRPM: should contain 2026;1 (set)
            #expect(response.contains("2026") == true)
        }
    }

    // MARK: - Process Exit Cleanup (cleanupForProcessExit)

    @Test func testCleanupResetsAltBuffer() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: "normal content")

        // Switch to alt buffer
        terminal.feed(text: "\u{1b}[?1049h")
        #expect(terminal.isCurrentBufferAlternate == true)

        terminal.feed(text: "alt content")

        terminal.cleanupForProcessExit()

        #expect(terminal.isCurrentBufferAlternate == false)

        // Normal buffer content preserved
        let line = TerminalTestHarness.lineText(buffer: terminal.buffer, terminal: terminal, row: 0)
        #expect(line == "normal content")
    }

    @Test func testCleanupResetsBracketedPaste() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: "\u{1b}[?2004h")
        #expect(terminal.bracketedPasteMode == true)

        terminal.cleanupForProcessExit()
        #expect(terminal.bracketedPasteMode == false)
    }

    @Test func testCleanupResetsMouseMode() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Enable any-event mouse tracking
        terminal.feed(text: "\u{1b}[?1003h")
        #expect(terminal.mouseMode != .off)

        terminal.cleanupForProcessExit()
        #expect(terminal.mouseMode == .off)
    }

    @Test func testCleanupResetsKittyKeyboard() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Push Kitty keyboard flags = 3
        terminal.feed(text: "\u{1b}[>3u")

        // Verify flags are set
        terminal.feed(text: "\u{1b}[?u")
        if let last = delegate.sentData.last, let response = String(bytes: last, encoding: .utf8) {
            #expect(response == "\u{1b}[?3u")
        }

        terminal.cleanupForProcessExit()

        // After cleanup, flags should be 0
        terminal.feed(text: "\u{1b}[?u")
        if let last = delegate.sentData.last, let response = String(bytes: last, encoding: .utf8) {
            #expect(response == "\u{1b}[?0u")
        }
    }

    @Test func testCleanupResetsCursorHidden() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Hide cursor
        terminal.feed(text: "\u{1b}[?25l")
        #expect(terminal.cursorHidden == true)

        terminal.cleanupForProcessExit()
        #expect(terminal.cursorHidden == false)
    }

    @Test func testCleanupEndsSynchronizedOutput() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: "original")

        // Begin synchronized output and write new content
        terminal.feed(text: "\u{1b}[?2026h")
        terminal.feed(text: "\u{1b}[H\u{1b}[2Knew content")

        // displayBuffer still shows snapshot
        #expect(topLineText(from: terminal.displayBuffer) == "original")

        // Process exit should end sync and reveal live buffer
        terminal.cleanupForProcessExit()
        #expect(topLineText(from: terminal.displayBuffer) == "new content")
    }

    @Test func testCleanupFromFullAISessionState() {
        // Simulates a Claude Code / Codex session that enabled many modes then crashed
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 80, rows: 24)

        // Enter alt screen
        terminal.feed(text: "\u{1b}[?1049h")
        // Enable bracketed paste
        terminal.feed(text: "\u{1b}[?2004h")
        // Enable mouse any-event tracking
        terminal.feed(text: "\u{1b}[?1003h")
        // Hide cursor
        terminal.feed(text: "\u{1b}[?25l")
        // Push Kitty keyboard flags
        terminal.feed(text: "\u{1b}[>5u")
        // Begin synchronized output
        terminal.feed(text: "\u{1b}[?2026h")

        // Verify everything is in the "dirty" state
        #expect(terminal.isCurrentBufferAlternate == true)
        #expect(terminal.bracketedPasteMode == true)
        #expect(terminal.mouseMode != .off)
        #expect(terminal.cursorHidden == true)

        // Simulate process crash — cleanup everything
        terminal.cleanupForProcessExit()

        // Verify all state is restored
        #expect(terminal.isCurrentBufferAlternate == false)
        #expect(terminal.bracketedPasteMode == false)
        #expect(terminal.mouseMode == .off)
        #expect(terminal.cursorHidden == false)

        // Kitty keyboard flags should be 0
        terminal.feed(text: "\u{1b}[?u")
        if let last = delegate.sentData.last, let response = String(bytes: last, encoding: .utf8) {
            #expect(response == "\u{1b}[?0u")
        }

        // Sync output should be ended (displayBuffer == buffer)
        terminal.feed(text: "post-cleanup")
        #expect(topLineText(from: terminal.displayBuffer, terminal: terminal) == "post-cleanup")
    }
}
