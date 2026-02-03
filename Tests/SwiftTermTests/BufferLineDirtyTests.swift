//
//  BufferLineDirtyTests.swift
//  SwiftTermTests
//
//  Tests for the isDirty flag on BufferLine in SwiftTerm.
//  The isDirty flag tracks whether a line has been modified and needs re-rendering.
//

import Testing
@testable import SwiftTerm

@Suite(.serialized)
@MainActor
final class BufferLineDirtyTests {

    // MARK: - New Line Creation

    /// Test that a newly created BufferLine starts with isDirty = true
    @Test
    func testNewBufferLineIsDirty() {
        let line = BufferLine(cols: 10)
        #expect(line.isDirty == true)
    }

    /// Test that copying a BufferLine preserves the isDirty flag
    @Test
    func testCopyConstructorPreservesDirty() {
        // Create and set up initial line
        let originalLine = BufferLine(cols: 10)
        originalLine.isDirty = false

        // Copy the line
        let copiedLine = BufferLine(from: originalLine)

        // The copied line should have isDirty = false (copied from original)
        #expect(copiedLine.isDirty == false)
    }

    // MARK: - isDirty Flag Reset

    /// Test that isDirty flag can be manually reset to false
    @Test
    func testClearDirtyFlagCanBeReset() {
        let line = BufferLine(cols: 10)

        // Initially true
        #expect(line.isDirty == true)

        // Reset to false
        line.isDirty = false
        #expect(line.isDirty == false)

        // Can be set back to true
        line.isDirty = true
        #expect(line.isDirty == true)
    }

    // MARK: - Mutation Operations That Set isDirty

    /// Test that subscript setter marks line as dirty
    @Test
    func testSubscriptSetMakesDirty() {
        let line = BufferLine(cols: 10)
        line.isDirty = false

        // Set a cell using subscript
        line[0] = CharData.Null

        #expect(line.isDirty == true)
    }

    /// Test that clear(with:) marks line as dirty
    @Test
    func testClearMakesDirty() {
        let line = BufferLine(cols: 10)
        line.isDirty = false

        // Clear the line with default attribute
        let attr = CharData.defaultAttr
        line.clear(with: attr)

        #expect(line.isDirty == true)
    }

    /// Test that fill(with:) marks line as dirty
    @Test
    func testFillMakesDirty() {
        let line = BufferLine(cols: 10)
        line.isDirty = false

        // Fill the entire line
        line.fill(with: CharData.Null)

        #expect(line.isDirty == true)
    }

    /// Test that fill(with:atCol:len:) marks line as dirty
    @Test
    func testFillPartialMakesDirty() {
        let line = BufferLine(cols: 10)
        line.isDirty = false

        // Fill part of the line
        line.fill(with: CharData.Null, atCol: 2, len: 5)

        #expect(line.isDirty == true)
    }

    /// Test that replaceCells marks line as dirty
    @Test
    func testReplaceCellsMakesDirty() {
        let line = BufferLine(cols: 10)
        line.isDirty = false

        // Replace cells in range
        line.replaceCells(start: 2, end: 5, fillData: CharData.Null)

        #expect(line.isDirty == true)
    }

    /// Test that insertCells marks line as dirty
    @Test
    func testInsertCellsMakesDirty() {
        let line = BufferLine(cols: 10)
        line.isDirty = false

        // Insert cells
        line.insertCells(pos: 2, n: 3, rightMargin: 9, fillData: CharData.Null)

        #expect(line.isDirty == true)
    }

    /// Test that deleteCells marks line as dirty
    @Test
    func testDeleteCellsMakesDirty() {
        let line = BufferLine(cols: 10)
        line.isDirty = false

        // Delete cells
        line.deleteCells(pos: 2, n: 3, rightMargin: 9, fillData: CharData.Null)

        #expect(line.isDirty == true)
    }

    /// Test that resize marks line as dirty when size changes
    @Test
    func testResizeMakesDirty() {
        let line = BufferLine(cols: 10)
        line.isDirty = false

        // Resize to a different size
        line.resize(cols: 15, fillData: CharData.Null)

        #expect(line.isDirty == true)
    }

    /// Test that resize does NOT mark line as dirty when size stays the same
    @Test
    func testResizeSameSizeDoesNotMarkDirty() {
        let line = BufferLine(cols: 10)
        line.isDirty = false

        // Resize to the same size - should be no-op
        line.resize(cols: 10, fillData: CharData.Null)

        // Should still be clean (not marked dirty by the no-op resize)
        #expect(line.isDirty == false)
    }

    /// Test that copyFrom (full) marks line as dirty
    @Test
    func testCopyFromFullMakesDirty() {
        let sourceLineData = BufferLine(cols: 10)
        sourceLineData[0] = CharData(attribute: CharData.defaultAttr, code: 65) // 'A'

        let destLine = BufferLine(cols: 10)
        destLine.isDirty = false

        // Copy entire line from another line
        destLine.copyFrom(line: sourceLineData)

        #expect(destLine.isDirty == true)
    }

    /// Test that copyFrom (partial) marks line as dirty
    @Test
    func testCopyFromPartialMakesDirty() {
        let sourceLine = BufferLine(cols: 10)
        sourceLine[0] = CharData(attribute: CharData.defaultAttr, code: 65) // 'A'
        sourceLine[1] = CharData(attribute: CharData.defaultAttr, code: 66) // 'B'

        let destLine = BufferLine(cols: 10)
        destLine.isDirty = false

        // Copy partial range from another line
        destLine.copyFrom(sourceLine, srcCol: 0, dstCol: 3, len: 2)

        #expect(destLine.isDirty == true)
    }

    // MARK: - Integration Tests with Terminal

    /// Test isDirty flag behavior with a terminal buffer
    @Test
    func testBufferLineIsDirtyWithTerminal() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 80, rows: 24)

        // Get a buffer line from the terminal
        let line = terminal.buffer.lines[0]

        // New lines in terminal start dirty
        #expect(line.isDirty == true)
    }

    /// Test that writing to terminal marks lines as dirty
    @Test
    func testTerminalWriteMarksDirty() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 80, rows: 24)

        // Get initial line
        let line = terminal.buffer.lines[0]

        // Line starts dirty
        #expect(line.isDirty == true)

        // Manually mark clean
        line.isDirty = false
        #expect(line.isDirty == false)

        // Write content to terminal
        terminal.feed(text: "Hello")

        // Line should be marked dirty from the write
        #expect(line.isDirty == true)
    }

    /// Test isDirty flag across multiple operations
    @Test
    func testMultipleOperationsKeepDirty() {
        let line = BufferLine(cols: 10)
        line.isDirty = false

        // First operation marks dirty
        line.fill(with: CharData.Null)
        #expect(line.isDirty == true)

        // Keep it dirty and do another operation
        line.fill(with: CharData(attribute: CharData.defaultAttr, code: 32))
        #expect(line.isDirty == true)

        // Reset and do a different operation
        line.isDirty = false
        line[5] = CharData(attribute: CharData.defaultAttr, code: 88) // 'X'
        #expect(line.isDirty == true)
    }

    // MARK: - Digit rendering / width verification

    /// Verify that all ASCII digits have width 1 in columnWidth
    @Test
    func testDigitsHaveWidth1() {
        for codepoint: UInt32 in 0x30...0x39 { // '0' through '9'
            let scalar = UnicodeScalar(codepoint)!
            let width = UnicodeUtil.columnWidth(rune: scalar)
            #expect(width == 1, "Digit U+\(String(format: "%04X", codepoint)) should be width 1, got \(width)")
        }
    }

    /// Verify that "10" written to the terminal buffer produces adjacent cells with no gap
    @Test
    func testDigitSequenceNoGap() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)
        terminal.feed(text: "10")

        let buffer = terminal.buffer
        // '1' should be at col 0 with width 1
        let cell0 = TerminalTestHarness.charData(buffer: buffer, row: 0, col: 0)!
        #expect(cell0.code == 0x31, "Cell 0 should be '1'")
        #expect(cell0.width == 1, "Cell 0 width should be 1")

        // '0' should be at col 1 with width 1 — no gap, no placeholder
        let cell1 = TerminalTestHarness.charData(buffer: buffer, row: 0, col: 1)!
        #expect(cell1.code == 0x30, "Cell 1 should be '0'")
        #expect(cell1.width == 1, "Cell 1 width should be 1")

        // Cell 2 should be empty (not a displaced '0')
        let cell2 = TerminalTestHarness.charData(buffer: buffer, row: 0, col: 2)!
        #expect(cell2.code == 0, "Cell 2 should be empty")

        // Line text extraction should show "10" with no space
        let text = TerminalTestHarness.lineText(buffer: buffer, terminal: terminal, row: 0)!
        #expect(text == "10")
    }

    /// Verify a longer number string has no gaps
    @Test
    func testMultiDigitSequence() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)
        terminal.feed(text: "1234567890")

        let buffer = terminal.buffer
        let text = TerminalTestHarness.lineText(buffer: buffer, terminal: terminal, row: 0)!
        #expect(text == "1234567890")

        // Verify every digit is width 1
        for col in 0..<10 {
            let cell = TerminalTestHarness.charData(buffer: buffer, row: 0, col: col)!
            #expect(cell.width == 1, "Digit at col \(col) should be width 1, got \(cell.width)")
        }
    }

    /// Verify mixed text and digits have no spacing issues
    @Test
    func testMixedTextAndDigits() {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: 40, rows: 5)
        terminal.feed(text: "Step 10: done")

        let buffer = terminal.buffer
        let text = TerminalTestHarness.lineText(buffer: buffer, terminal: terminal, row: 0)!
        #expect(text == "Step 10: done")
    }
}
