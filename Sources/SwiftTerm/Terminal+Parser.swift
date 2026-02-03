import Foundation

extension Terminal {
    // Configures the EscapeSequenceParser with fallback handlers and print handling
    func configureParser (_ parser: EscapeSequenceParser)
    {
        parser.csiHandlerFallback = { [unowned self] (pars: [Int], collect: cstring, code: UInt8) -> () in
            let ch = Character(UnicodeScalar(code))
            self.log ("SwiftTerm: Unknown CSI Code (collect=\(collect) code=\(ch) pars=\(pars))")
        }
        parser.escHandlerFallback = { [unowned self] (txt: cstring, flag: UInt8) in
            self.log ("SwiftTerm: Unknown ESC Code: ESC + \(Character(Unicode.Scalar (flag))) txt=\(txt)")
        }
        parser.executeHandlerFallback = { [unowned self] in
            self.log ("SwiftTerm: Unknown EXECUTE code")
        }
        parser.oscHandlerFallback = { [unowned self] code, data in
            self.log ("SwiftTerm: Unknown OSC code: \(code)")
        }
        parser.apcHandlerFallback = { [unowned self] code, data in
            if let scalar = UnicodeScalar(Int(code)) {
                self.log ("SwiftTerm: Unknown APC code: \(Character(scalar))")
            } else {
                self.log ("SwiftTerm: Unknown APC code: \(code)")
            }
        }
        parser.printHandler = { [unowned self] slice in handlePrint (slice) }
        parser.printStateReset = { [unowned self] in printStateReset() }

        parser.errorHandler = { [unowned self] state in
            self.log ("SwiftTerm: Parsing error, state: \(state)")
            return state
        }
    }

    func printStateReset ()
    {
        readingBuffer.reset ()
    }

    func handlePrint (_ data: ArraySlice<UInt8>)
    {
        let buffer = self.buffer
        readingBuffer.prepare(data)

        updateRange(borrowing: buffer, buffer.y)
        while readingBuffer.hasNext() {
            var ch: Character = " "
            var chWidth: Int = 0
            let code = readingBuffer.getNext()

            let n = UnicodeUtil.expectedSizeFromFirstByte(code)

            if n == -1 || n == 1 {
                // n == -1 means an Invalid UTF-8 sequence, client sent us some junk, happens if we run
                // with the wrong locale set for example if LANG=en, still we handle it here

                // get charset replacement character
                // charset are only defined for ASCII, therefore we only
                // search for an replacement char if code < 127
                if code < 127 && charset != nil {

                    // Notice that the charset mapping can contain the dutch unicode sequence for "ij",
                    // so it is not a simple byte, it is a Character
                    if let str = charset! [UInt8 (code)] {
                        ch = str.first!

                        // Every single mapping in the charset only takes one slot
                        chWidth = 1
                        let charData = makeCharData (attribute: curAttr, char: ch, size: Int8 (chWidth))
                        buffer.insertCharacter(charData)
                        continue
                    }
                }

                let rune = UnicodeScalar (code)
                chWidth = UnicodeUtil.columnWidth(rune: rune)
                if chWidth > 0 {
                    let charData = makeCharData (attribute: curAttr, scalar: rune, size: Int8 (chWidth))
                    buffer.insertCharacter(charData)
                }
                continue
            } else if readingBuffer.bytesLeft() >= (n-1) {
                var x : [UInt8] = [code]
                for _ in 1..<n {
                    x.append (readingBuffer.getNext())
                }

                var iterator = x.makeIterator()
                var decoder = UTF8()
                switch decoder.decode(&iterator) {
                case .scalarValue(let scalar):
                    ch = Character(scalar)
                default:
                    // Invalid UTF-8 sequence, fall back to interpreting the first byte
                    let rune = UnicodeScalar(code)
                    chWidth = UnicodeUtil.columnWidth(rune: rune)
                    if chWidth > 0 {
                        let charData = makeCharData (attribute: curAttr, scalar: rune, size: Int8 (chWidth))
                        buffer.insertCharacter(charData)
                    }
                    continue
                }

                // Now the challenge is that we have a character, not a rune, and we want to compute
                // the width of it.
                if ch.unicodeScalars.count == 1 {
                    chWidth = UnicodeUtil.columnWidth(rune: ch.unicodeScalars.first!)
                } else {
                    chWidth = 0
                    for scalar in ch.unicodeScalars {
                        let width = UnicodeUtil.columnWidth(rune: scalar)
                        if width < 0 {
                            chWidth = -1
                            break
                        }
                        chWidth = max (chWidth, width)
                    }
                }
            } else {
                readingBuffer.putback (code)
                return
            }

            if chWidth < 0 {
                continue
            }

            if let firstScalar = ch.unicodeScalars.first {
                // Check if we should try to combine this character with the previous one.
                // This applies to:
                // 1. Unicode combining characters (diacritics, etc.)
                // 2. Emoji skin tone modifiers (e.g., 🖐 + 🏾 = 🖐🏾)
                // 3. Zero Width Joiner (ZWJ) for emoji sequences (e.g., 👩 + ZWJ + 👩 + ZWJ + 👦 = 👩‍👩‍👦)
                // 4. Variation selectors (e.g., U+FE0F for emoji presentation of ❤️)
                // 5. Any character following a ZWJ (to complete the sequence)
                var shouldTryCombine = chWidth == 0 ||
                                       firstScalar.properties.canonicalCombiningClass != .notReordered ||
                                       firstScalar.properties.isEmojiModifier ||
                                       firstScalar.properties.isVariationSelector ||
                                       firstScalar.value == 0x200D  // ZWJ

                // Also check if the previous character ends with ZWJ - if so, we should combine
                if !shouldTryCombine {
                    let last = buffer.lastBufferStorage
                    if last.cols == cols && last.rows == rows {
                        let existingLine = buffer.lines [last.y]
                        let lastx = last.x >= cols ? cols-1 : last.x
                        let lastChar = getCharacter (for: existingLine [lastx])
                        if lastChar.unicodeScalars.last?.value == 0x200D {
                            shouldTryCombine = true
                        }
                    }
                }

                if shouldTryCombine {
                    // Determine if the last time we poked at a character is still valid
                    let last = buffer.lastBufferStorage
                    if last.cols == cols && last.rows == rows {
                        // Fetch the old character, and attempt to combine it:
                        let existingLine = buffer.lines [last.y]
                        let lastx = last.x >= cols ? cols-1 : last.x
                        var cd = existingLine [lastx]

                        // Attempt the combination
                        let newStr = String ([getCharacter (for: cd), ch])

                        // If the resulting string is 1 grapheme cluster, then it combined properly
                        if newStr.count == 1 {
                            if let newCh = newStr.first {
                                let oldSize = cd.width
                                let isVs16 = firstScalar.value == 0xFE0F
                                let isVs15 = firstScalar.value == 0xFE0E
                                let needsEmojiVariationCheck = isVs16 || isVs15
                                if needsEmojiVariationCheck {
                                    let baseScalar = getCharacter(for: cd).unicodeScalars.last
                                    if baseScalar == nil || !UnicodeUtil.isEmojiVs16Base(rune: baseScalar!) {
                                        continue
                                    }
                                }
                                if isVs16 {
                                    if oldSize != 2 && lastx + 1 < cols {
                                        updateCharData(&cd, char: newCh, size: 2)
                                        let nextX = lastx + 1
                                        let empty = makeCharData (attribute: cd.attribute, code: 0, size: 0)
                                        existingLine [nextX] = empty
                                        buffer.x += 1
                                    } else {
                                        updateCharData(&cd, char: newCh, size: Int32(oldSize))
                                    }
                                } else if isVs15 {
                                    updateCharData(&cd, char: newCh, size: 1)
                                    if oldSize == 2 && buffer.x > 0 {
                                        buffer.x -= 1
                                    }
                                } else {
                                    updateCharData(&cd, char: newCh, size: Int32 (cd.width))
                                    if cd.width != oldSize {
                                        buffer.x += 1
                                    }
                                }
                                existingLine [lastx] = cd
                                updateRange(borrowing: buffer, last.y)
                                continue
                            }
                        }
                    }
                }
            }
            if chWidth == 0 {
                continue
            }
            let charData = makeCharData (attribute: curAttr, char: ch, size: Int8 (chWidth))
            buffer.insertCharacter (charData)
        }

        readingBuffer.done()
    }
}

// Because data might not be complete, we need to put back data that we read to process on
// a future read.  To prepare for reading, on every call to parse, the prepare method is
// given the new ArraySlice to read from.
//
// the `hasNext` describes whether there is more data left on the buffer, and `bytesLeft`
// returnes the number of bytes left.   The `getNext` method fetches either the next
// value from the putback buffer, or when it is empty, it returns it from the buffer that
// was passed during prepare.
//
// Additionally, the terminal parser needs to reset the parser state on demand, and
// that is surfaced via reset
struct ReadingBuffer {
    var putbackBuffer: [UInt8] = []
    var rest:ArraySlice<UInt8> = [][...]
    var idx = 0
    var count:Int = 0

    // Invoke this method at the beginning of parse
    mutating func prepare (_ data: ArraySlice<UInt8>)
    {
        assert (rest.count == 0)
        rest = data
        count = putbackBuffer.count + data.count
        idx = 0
    }

    func hasNext () -> Bool {
        idx < count
    }

    func bytesLeft () -> Int
    {
        count-idx
    }

    mutating func getNext () -> UInt8
    {
        if idx < putbackBuffer.count {
            let v = putbackBuffer [idx]
            idx += 1
            return v
        }
        let v = rest [idx-putbackBuffer.count+rest.startIndex]
        idx += 1
        return v
    }

    // Puts back the code, and everything that was pending
    mutating func putback (_ code: UInt8)
    {
        var newPutback: [UInt8] = [code]
        let left = bytesLeft()
        for _ in 0..<left {
            newPutback.append (getNext ())
        }
        putbackBuffer = newPutback
        rest = [][...]
    }

    mutating func done  ()
    {
        if idx < putbackBuffer.count {
            putbackBuffer.removeFirst(idx)
        } else {
            putbackBuffer = []
        }
        rest = [][...]
    }

    mutating func reset ()
    {
        putbackBuffer = []
        idx = 0
    }
}
