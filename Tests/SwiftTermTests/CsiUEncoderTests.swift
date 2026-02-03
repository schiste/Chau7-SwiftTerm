import Testing
@testable import SwiftTerm

@Suite(.serialized)
@MainActor
struct CsiUEncoderTests {

    // MARK: - CSI u Encoding Tests

    @Test func testCsiUNoModifiers() {
        let result = EscapeSequences.csiU(keycode: 97)
        let expected = [UInt8]("\u{1b}[97u".utf8)
        #expect(result == expected)
    }

    @Test func testCsiUWithShift() {
        let result = EscapeSequences.csiU(keycode: 97, modifiers: .shift)
        let expected = [UInt8]("\u{1b}[97;2u".utf8)
        #expect(result == expected)
    }

    @Test func testCsiUWithCtrl() {
        let result = EscapeSequences.csiU(keycode: 97, modifiers: .ctrl)
        let expected = [UInt8]("\u{1b}[97;5u".utf8)
        #expect(result == expected)
    }

    @Test func testCsiUWithAlt() {
        let result = EscapeSequences.csiU(keycode: 97, modifiers: .alt)
        let expected = [UInt8]("\u{1b}[97;3u".utf8)
        #expect(result == expected)
    }

    @Test func testCsiUWithShiftCtrl() {
        let result = EscapeSequences.csiU(keycode: 97, modifiers: [.shift, .ctrl])
        let expected = [UInt8]("\u{1b}[97;6u".utf8)
        #expect(result == expected)
    }

    @Test func testCsiUWithAllModifiers() {
        let result = EscapeSequences.csiU(keycode: 97, modifiers: [.shift, .alt, .ctrl, .meta])
        let expected = [UInt8]("\u{1b}[97;16u".utf8)
        #expect(result == expected)
    }

    @Test func testCsiUEnter() {
        let result = EscapeSequences.csiU(keycode: 13)
        let expected = [UInt8]("\u{1b}[13u".utf8)
        #expect(result == expected)
    }

    // MARK: - Functional Key Encoding Tests

    @Test func testCsiFunctionalNoModifiers() {
        let result = EscapeSequences.csiFunctional(number: 15)
        let expected = [UInt8]("\u{1b}[15~".utf8)
        #expect(result == expected)
    }

    @Test func testCsiFunctionalWithShift() {
        let result = EscapeSequences.csiFunctional(number: 15, modifiers: .shift)
        let expected = [UInt8]("\u{1b}[15;2~".utf8)
        #expect(result == expected)
    }

    @Test func testCsiFunctionalDelete() {
        let result = EscapeSequences.csiFunctional(number: 3, modifiers: .ctrl)
        let expected = [UInt8]("\u{1b}[3;5~".utf8)
        #expect(result == expected)
    }

    // MARK: - Arrow Key Encoding Tests

    @Test func testCsiArrowUpNoModifiers() {
        let result = EscapeSequences.csiArrow(suffix: 0x41)
        let expected = [UInt8]([0x1b, 0x5b, 0x41])
        #expect(result == expected)
    }

    @Test func testCsiArrowUpWithCtrl() {
        let result = EscapeSequences.csiArrow(suffix: 0x41, modifiers: .ctrl)
        let expected = [UInt8]("\u{1b}[1;5A".utf8)
        #expect(result == expected)
    }

    @Test func testCsiArrowDownWithShift() {
        let result = EscapeSequences.csiArrow(suffix: 0x42, modifiers: .shift)
        let expected = [UInt8]("\u{1b}[1;2B".utf8)
        #expect(result == expected)
    }

    // MARK: - Terminal Keyboard Protocol Accessor Tests

    @Test func testKittyFlagsDefaultZero() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 5, rows: 1)
        #expect(terminal.currentKittyKeyboardProtocolFlags == 0)
    }

    @Test func testKittyFlagsAfterPush() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 5, rows: 1)
        terminal.feed(text: "\u{1b}[>3u")
        #expect(terminal.currentKittyKeyboardProtocolFlags == 3)
    }

    @Test func testEnhancedKeyReportingWithKitty() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 5, rows: 1)
        #expect(terminal.isEnhancedKeyReportingActive == false)
        terminal.feed(text: "\u{1b}[>1u")
        #expect(terminal.isEnhancedKeyReportingActive == true)
    }

    @Test func testEnhancedKeyReportingWithModifyOtherKeys() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 5, rows: 1)
        #expect(terminal.isEnhancedKeyReportingActive == false)
        terminal.feed(text: "\u{1b}[>4;2m")
        #expect(terminal.isEnhancedKeyReportingActive == true)
    }

    @Test func testEnhancedKeyReportingOffByDefault() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 5, rows: 1)
        #expect(terminal.isEnhancedKeyReportingActive == false)
    }
}
