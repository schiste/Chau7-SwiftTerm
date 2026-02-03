import Testing
@testable import SwiftTerm

@Suite(.serialized)
@MainActor
final class DecrqmTests {

    // MARK: - Helper Functions

    private func assertLastResponse(
        _ delegate: TerminalTestDelegate,
        contains substrings: String...
    ) {
        guard let last = delegate.sentData.last,
              let response = String(bytes: last, encoding: .utf8) else {
            #expect(Bool(false), "No response sent by terminal")
            return
        }

        for substring in substrings {
            #expect(
                response.contains(substring),
                "Response '\(response)' does not contain '\(substring)'"
            )
        }
    }

    private func assertLastResponse(
        _ delegate: TerminalTestDelegate,
        equals expected: String
    ) {
        guard let last = delegate.sentData.last,
              let response = String(bytes: last, encoding: .utf8) else {
            #expect(Bool(false), "No response sent by terminal")
            return
        }
        #expect(response == expected)
    }

    // MARK: - DECRQM Tests for modifyOtherKeys

    @Test func testDecrqmModifyOtherKeysReset() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Ensure modifyOtherKeys is off (level 0)
        #expect(terminal.currentModifyOtherKeysLevel == 0)

        // Query mode 2048 (modifyOtherKeys)
        terminal.feed(text: "\u{1b}[?2048$p")

        // Response should contain "2048" and ";2" (reset/off)
        assertLastResponse(delegate, contains: "2048", ";2")
    }

    @Test func testDecrqmModifyOtherKeysSet() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Set modifyOtherKeys level 2 (full)
        terminal.feed(text: "\u{1b}[>4;2m")
        #expect(terminal.currentModifyOtherKeysLevel == 2)

        // Query mode 2048
        terminal.feed(text: "\u{1b}[?2048$p")

        // Response should contain "2048" and ";1" (set/on)
        assertLastResponse(delegate, contains: "2048", ";1")
    }

    @Test func testDecrqmModifyOtherKeysLevel1() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Set modifyOtherKeys level 1
        terminal.feed(text: "\u{1b}[>4;1m")
        #expect(terminal.currentModifyOtherKeysLevel == 1)

        // Query mode 2048
        terminal.feed(text: "\u{1b}[?2048$p")

        // Response should contain "2048" and ";1" (set/on)
        assertLastResponse(delegate, contains: "2048", ";1")
    }

    // MARK: - DECRQM Tests for Bracketed Paste

    @Test func testDecrqmBracketedPasteReset() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Ensure bracketed paste is off
        #expect(terminal.bracketedPasteMode == false)

        // Query mode 2004 (bracketed paste)
        terminal.feed(text: "\u{1b}[?2004$p")

        // Response should contain "2004" and ";2" (reset)
        assertLastResponse(delegate, contains: "2004", ";2")
    }

    @Test func testDecrqmBracketedPasteSet() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Enable bracketed paste mode
        terminal.feed(text: "\u{1b}[?2004h")
        #expect(terminal.bracketedPasteMode == true)

        // Query mode 2004
        terminal.feed(text: "\u{1b}[?2004$p")

        // Response should contain "2004" and ";1" (set)
        assertLastResponse(delegate, contains: "2004", ";1")
    }

    // MARK: - DECRQM Tests for Synchronized Output

    @Test func testDecrqmSyncOutputReset() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Query mode 2026 (synchronized output) when off
        terminal.feed(text: "\u{1b}[?2026$p")

        // Response should contain "2026" and ";2" (reset)
        assertLastResponse(delegate, contains: "2026", ";2")
    }

    @Test func testDecrqmSyncOutputSet() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Enable synchronized output mode
        terminal.feed(text: "\u{1b}[?2026h")

        // Query mode 2026
        terminal.feed(text: "\u{1b}[?2026$p")

        // Response should contain "2026" and ";1" (set)
        assertLastResponse(delegate, contains: "2026", ";1")
    }

    // MARK: - resetToInitialState Tests for modifyOtherKeys

    @Test func testResetToInitialStateClearsModifyOtherKeys() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Set modifyOtherKeys to level 2
        terminal.feed(text: "\u{1b}[>4;2m")
        #expect(terminal.currentModifyOtherKeysLevel == 2)

        // Call resetToInitialState
        terminal.resetToInitialState()

        // modifyOtherKeys should be cleared back to 0
        #expect(terminal.currentModifyOtherKeysLevel == 0)
    }

    // MARK: - resetToInitialState Tests for Kitty Keyboard

    @Test func testResetToInitialStateClearsKittyKeyboard() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Push Kitty keyboard flags level 3
        terminal.feed(text: "\u{1b}[>3u")

        // Verify flags are set
        terminal.feed(text: "\u{1b}[?u")
        assertLastResponse(delegate, equals: "\u{1b}[?3u")

        // Call resetToInitialState
        terminal.resetToInitialState()

        // Query again — should return to 0
        terminal.feed(text: "\u{1b}[?u")
        assertLastResponse(delegate, equals: "\u{1b}[?0u")
    }

    @Test func testResetToInitialStateClearsKittyKeyboardMultipleLevels() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Push Kitty keyboard flags progressively
        terminal.feed(text: "\u{1b}[>1u")
        terminal.feed(text: "\u{1b}[?u")
        assertLastResponse(delegate, equals: "\u{1b}[?1u")

        terminal.feed(text: "\u{1b}[>5u")
        terminal.feed(text: "\u{1b}[?u")
        assertLastResponse(delegate, equals: "\u{1b}[?5u")

        // Reset to initial state
        terminal.resetToInitialState()

        // Should be back to 0
        terminal.feed(text: "\u{1b}[?u")
        assertLastResponse(delegate, equals: "\u{1b}[?0u")
    }

    // MARK: - resetToInitialState Tests for Semantic State

    @Test func testResetToInitialStateClearsSemanticState() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Feed OSC 133 sequence to set semantic prompt state (using ST terminator)
        terminal.feed(text: "\u{1b}]133;A\u{1b}\\")
        #expect(terminal.currentSemanticPromptState == .prompt)

        // Call resetToInitialState
        terminal.resetToInitialState()

        // Semantic state should be back to unknown
        #expect(terminal.currentSemanticPromptState == .unknown)
    }

    @Test func testResetToInitialStateClearsSemanticStateBel() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Feed OSC 133 sequence using BEL terminator
        terminal.feed(text: "\u{1b}]133;A\u{07}")
        #expect(terminal.currentSemanticPromptState == .prompt)

        terminal.feed(text: "\u{1b}]133;B\u{07}")
        #expect(terminal.currentSemanticPromptState == .input)

        // Reset
        terminal.resetToInitialState()

        #expect(terminal.currentSemanticPromptState == .unknown)
    }

    @Test func testResetToInitialStateClearsSemanticStateFromOutput() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Build a semantic state chain
        terminal.feed(text: "\u{1b}]133;A\u{1b}\\")
        terminal.feed(text: "\u{1b}]133;B\u{1b}\\")
        terminal.feed(text: "\u{1b}]133;C\u{1b}\\")
        #expect(terminal.currentSemanticPromptState == .output)

        // Reset
        terminal.resetToInitialState()

        #expect(terminal.currentSemanticPromptState == .unknown)
    }

    // MARK: - resetToInitialState Tests for Bracketed Paste

    @Test func testResetToInitialStateClearsBracketedPaste() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Enable bracketed paste
        terminal.feed(text: "\u{1b}[?2004h")
        #expect(terminal.bracketedPasteMode == true)

        // Reset
        terminal.resetToInitialState()

        #expect(terminal.bracketedPasteMode == false)
    }

    // MARK: - resetToInitialState Tests for Synchronized Output

    @Test func testResetToInitialStateClearsSynchronizedOutput() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Enable synchronized output
        terminal.feed(text: "\u{1b}[?2026h")

        // Reset
        terminal.resetToInitialState()

        // Query to verify it's off
        terminal.feed(text: "\u{1b}[?2026$p")
        assertLastResponse(delegate, contains: ";2")
    }

    // MARK: - Comprehensive resetToInitialState Test

    @Test func testResetToInitialStateClearsAllState() {
        let (terminal, delegate) = TerminalTestHarness.makeTerminal(cols: 80, rows: 24)

        // Set multiple modes
        terminal.feed(text: "\u{1b}[>4;2m")  // modifyOtherKeys level 2
        terminal.feed(text: "\u{1b}[?2004h") // bracketed paste
        terminal.feed(text: "\u{1b}[?2026h") // synchronized output
        terminal.feed(text: "\u{1b}[>3u")    // Kitty keyboard flags = 3
        terminal.feed(text: "\u{1b}]133;A\u{1b}\\") // semantic state = prompt

        // Verify everything is set
        #expect(terminal.currentModifyOtherKeysLevel == 2)
        #expect(terminal.bracketedPasteMode == true)
        #expect(terminal.currentSemanticPromptState == .prompt)

        // Reset everything
        terminal.resetToInitialState()

        // Verify all state is cleared
        #expect(terminal.currentModifyOtherKeysLevel == 0)
        #expect(terminal.bracketedPasteMode == false)
        #expect(terminal.currentSemanticPromptState == .unknown)

        // Query Kitty keyboard
        terminal.feed(text: "\u{1b}[?u")
        assertLastResponse(delegate, equals: "\u{1b}[?0u")

        // Query synchronized output
        terminal.feed(text: "\u{1b}[?2026$p")
        assertLastResponse(delegate, contains: "2026", ";2")

        // Query modifyOtherKeys
        terminal.feed(text: "\u{1b}[?2048$p")
        assertLastResponse(delegate, contains: "2048", ";2")

        // Query bracketed paste
        terminal.feed(text: "\u{1b}[?2004$p")
        assertLastResponse(delegate, contains: "2004", ";2")
    }
}
