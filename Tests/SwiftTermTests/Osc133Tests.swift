import Testing
@testable import SwiftTerm

@Suite(.serialized)
@MainActor
final class Osc133Tests {

    // Helper: build the OSC 133 escape sequence with ST terminator
    private func osc133(_ sub: String) -> String {
        "\u{1b}]133;\(sub)\u{1b}\\"
    }

    // MARK: - Basic sub-command dispatch

    @Test func testPromptStartSetsState() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A"))

        #expect(terminal.currentSemanticPromptState == .prompt)
    }

    @Test func testInputStartSetsState() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A"))
        terminal.feed(text: osc133("B"))

        #expect(terminal.currentSemanticPromptState == .input)
    }

    @Test func testOutputStartSetsState() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A"))
        terminal.feed(text: osc133("B"))
        terminal.feed(text: osc133("C"))

        #expect(terminal.currentSemanticPromptState == .output)
    }

    @Test func testOutputEndResetsState() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A"))
        terminal.feed(text: osc133("B"))
        terminal.feed(text: osc133("C"))
        terminal.feed(text: osc133("D;0"))

        #expect(terminal.currentSemanticPromptState == .unknown)
    }

    // MARK: - BufferLine semantic type tagging

    @Test func testBufferLineTaggedOnPromptStart() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A"))

        #expect(terminal.semanticTypeForLine(0) == .promptStart)
    }

    @Test func testBufferLineTaggedThroughCycle() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Row 0: prompt start
        terminal.feed(text: osc133("A"))
        // Move to row 1: input start
        terminal.feed(text: "\n")
        terminal.feed(text: osc133("B"))
        // Move to row 2: output start
        terminal.feed(text: "\n")
        terminal.feed(text: osc133("C"))
        // Move to row 3: output end
        terminal.feed(text: "\n")
        terminal.feed(text: osc133("D;0"))

        #expect(terminal.semanticTypeForLine(0) == .promptStart)
        #expect(terminal.semanticTypeForLine(1) == .input)
        #expect(terminal.semanticTypeForLine(2) == .output)
        #expect(terminal.semanticTypeForLine(3) == .outputEnd)
    }

    // MARK: - PromptMark accumulation

    @Test func testPromptMarksAccumulateThroughCycle() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 10)

        terminal.feed(text: osc133("A"))
        terminal.feed(text: "$ ls\n")
        terminal.feed(text: osc133("B"))
        terminal.feed(text: osc133("C"))
        terminal.feed(text: "file1 file2\n")
        terminal.feed(text: osc133("D;0"))

        #expect(terminal.promptMarks.count == 4)
        #expect(terminal.promptMarks[0].type == .promptStart)
        #expect(terminal.promptMarks[1].type == .inputStart)
        #expect(terminal.promptMarks[2].type == .outputStart)
        #expect(terminal.promptMarks[3].type == .outputEnd)
    }

    @Test func testOutputEndCapturesExitCode() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("C"))
        terminal.feed(text: osc133("D;127"))

        let mark = terminal.promptMarks.last
        #expect(mark?.type == .outputEnd)
        #expect(mark?.exitCode == 127)
    }

    @Test func testOutputEndNoExitCode() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("D"))

        let mark = terminal.promptMarks.last
        #expect(mark?.type == .outputEnd)
        #expect(mark?.exitCode == nil)
    }

    // MARK: - Prompt kind parsing

    @Test func testPromptKindParsing() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A;kind=secondary"))

        let mark = terminal.promptMarks.first
        #expect(mark?.kind == .secondary)
    }

    @Test func testPromptKindRight() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A;kind=right"))

        let mark = terminal.promptMarks.first
        #expect(mark?.kind == .right)
    }

    @Test func testPromptKindDefaultsToPrimaryWhenUnknown() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A;kind=custom"))

        let mark = terminal.promptMarks.first
        #expect(mark?.kind == .primary)
    }

    @Test func testPromptKindNilWithoutParam() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A"))

        let mark = terminal.promptMarks.first
        #expect(mark?.kind == nil)
    }

    // MARK: - Alternate screen ignoring

    @Test func testOsc133IgnoredOnAlternateScreen() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Switch to alt screen
        terminal.feed(text: "\u{1b}[?1049h")
        #expect(terminal.isCurrentBufferAlternate == true)

        terminal.feed(text: osc133("A"))

        // State should remain unknown and no marks added
        #expect(terminal.currentSemanticPromptState == .unknown)
        #expect(terminal.promptMarks.isEmpty)
    }

    // MARK: - Navigation (previousPromptLine / nextPromptLine)

    @Test func testNavigatePreviousPrompt() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 10)

        // First prompt at row 0
        terminal.feed(text: osc133("A"))
        terminal.feed(text: "$ cmd1\n")
        terminal.feed(text: osc133("B"))
        terminal.feed(text: osc133("C"))
        terminal.feed(text: "output1\n")
        terminal.feed(text: osc133("D;0"))

        // Second prompt at current row
        terminal.feed(text: osc133("A"))
        terminal.feed(text: "$ cmd2\n")
        terminal.feed(text: osc133("B"))
        terminal.feed(text: osc133("C"))
        terminal.feed(text: "output2\n")

        // From the last output line, navigate to previous prompt
        let cursorRow = terminal.buffer.y
        let prevPrompt = terminal.previousPromptLine(from: cursorRow)

        // Should find the second prompt (which is before the current cursor)
        #expect(prevPrompt != nil)
    }

    @Test func testNavigateNextPrompt() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 10)

        // First prompt at row 0
        terminal.feed(text: osc133("A"))
        terminal.feed(text: "$ cmd1\n")
        terminal.feed(text: osc133("B"))
        terminal.feed(text: osc133("C"))
        terminal.feed(text: "output1\n")
        terminal.feed(text: osc133("D;0"))

        // Second prompt
        terminal.feed(text: osc133("A"))

        // Navigate from row 0 forward
        let nextPrompt = terminal.nextPromptLine(from: 0)

        // Should find the second prompt
        #expect(nextPrompt != nil)
    }

    @Test func testNavigatePreviousReturnsNilAtStart() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A"))

        // From row 0, there is no previous prompt
        let prev = terminal.previousPromptLine(from: 0)
        #expect(prev == nil)
    }

    @Test func testNavigateNextReturnsNilAtEnd() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A"))

        // From row 0 with only one prompt, there is no next
        let next = terminal.nextPromptLine(from: 0)
        #expect(next == nil)
    }

    // MARK: - cleanupForProcessExit resets semantic state

    @Test func testCleanupResetsSemanticState() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: osc133("A"))
        terminal.feed(text: osc133("B"))
        #expect(terminal.currentSemanticPromptState == .input)

        terminal.cleanupForProcessExit()

        #expect(terminal.currentSemanticPromptState == .unknown)
    }

    // MARK: - BEL terminator (alternative to ST)

    @Test func testOsc133WithBelTerminator() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Use BEL (\x07) as terminator instead of ST (\x1b\\)
        terminal.feed(text: "\u{1b}]133;A\u{07}")

        #expect(terminal.currentSemanticPromptState == .prompt)
        #expect(terminal.promptMarks.count == 1)
        #expect(terminal.promptMarks[0].type == .promptStart)
    }

    // MARK: - Multiple full cycles

    @Test func testMultiplePromptCycles() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 20)

        for i in 0..<3 {
            terminal.feed(text: osc133("A"))
            terminal.feed(text: "$ cmd\(i)\n")
            terminal.feed(text: osc133("B"))
            terminal.feed(text: osc133("C"))
            terminal.feed(text: "output\(i)\n")
            terminal.feed(text: osc133("D;\(i)"))
        }

        // 3 full cycles × 4 marks each = 12 total
        #expect(terminal.promptMarks.count == 12)

        // Verify each cycle's exit codes
        let outputEndMarks = terminal.promptMarks.filter { $0.type == .outputEnd }
        #expect(outputEndMarks.count == 3)
        #expect(outputEndMarks[0].exitCode == 0)
        #expect(outputEndMarks[1].exitCode == 1)
        #expect(outputEndMarks[2].exitCode == 2)
    }
}
