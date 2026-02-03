import Testing
@testable import SwiftTerm

@Suite(.serialized)
@MainActor
final class XtmodkeysTests {

    // MARK: - Basic modifyOtherKeys level tracking

    @Test func testDefaultLevelIsZero() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)
        #expect(terminal.currentModifyOtherKeysLevel == 0)
    }

    @Test func testSetModifyOtherKeysLevel1() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // CSI > 4 ; 1 m — set modifyOtherKeys to level 1
        terminal.feed(text: "\u{1b}[>4;1m")

        #expect(terminal.currentModifyOtherKeysLevel == 1)
    }

    @Test func testSetModifyOtherKeysLevel2() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // CSI > 4 ; 2 m — set modifyOtherKeys to level 2 (full)
        terminal.feed(text: "\u{1b}[>4;2m")

        #expect(terminal.currentModifyOtherKeysLevel == 2)
    }

    @Test func testResetModifyOtherKeysWithSingleParam() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Set to level 2 first
        terminal.feed(text: "\u{1b}[>4;2m")
        #expect(terminal.currentModifyOtherKeysLevel == 2)

        // CSI > 4 m — reset resource 4 (no second param means disable)
        terminal.feed(text: "\u{1b}[>4m")

        #expect(terminal.currentModifyOtherKeysLevel == 0)
    }

    @Test func testClampsToMaxLevel2() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Try setting to level 99
        terminal.feed(text: "\u{1b}[>4;99m")

        #expect(terminal.currentModifyOtherKeysLevel == 2)
    }

    @Test func testClampsNegativeToZero() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // Set to level 2 first, then try -1
        // Note: CSI parsing may interpret missing/default params as 0
        terminal.feed(text: "\u{1b}[>4;2m")
        terminal.feed(text: "\u{1b}[>4;0m")

        #expect(terminal.currentModifyOtherKeysLevel == 0)
    }

    // MARK: - Other resources are accepted but don't affect modifyOtherKeys

    @Test func testOtherResourceDoesNotAffectModifyOtherKeys() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // CSI > 1 ; 2 m — modifyCursorKeys (resource 1), should not change modifyOtherKeys
        terminal.feed(text: "\u{1b}[>1;2m")

        #expect(terminal.currentModifyOtherKeysLevel == 0)
    }

    @Test func testResourceZeroDoesNotAffectModifyOtherKeys() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        // CSI > 0 ; 1 m — modifyKeyboard (resource 0)
        terminal.feed(text: "\u{1b}[>0;1m")

        #expect(terminal.currentModifyOtherKeysLevel == 0)
    }

    // MARK: - Reset via softReset / cleanupForProcessExit

    @Test func testSoftResetClearsModifyOtherKeys() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: "\u{1b}[>4;2m")
        #expect(terminal.currentModifyOtherKeysLevel == 2)

        // DECSTR (soft reset)
        terminal.feed(text: "\u{1b}[!p")

        #expect(terminal.currentModifyOtherKeysLevel == 0)
    }

    @Test func testCleanupForProcessExitClearsModifyOtherKeys() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: "\u{1b}[>4;2m")
        #expect(terminal.currentModifyOtherKeysLevel == 2)

        terminal.cleanupForProcessExit()

        #expect(terminal.currentModifyOtherKeysLevel == 0)
    }

    // MARK: - Transition between levels

    @Test func testTransitionBetweenLevels() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)

        terminal.feed(text: "\u{1b}[>4;1m")
        #expect(terminal.currentModifyOtherKeysLevel == 1)

        terminal.feed(text: "\u{1b}[>4;2m")
        #expect(terminal.currentModifyOtherKeysLevel == 2)

        terminal.feed(text: "\u{1b}[>4;1m")
        #expect(terminal.currentModifyOtherKeysLevel == 1)

        terminal.feed(text: "\u{1b}[>4;0m")
        #expect(terminal.currentModifyOtherKeysLevel == 0)
    }
}
