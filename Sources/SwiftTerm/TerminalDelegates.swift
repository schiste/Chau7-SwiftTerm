import Foundation

// MARK: - Delegate Protocols (Split for Clarity and Composability)

public protocol TerminalOutputDelegate: AnyObject {
    /// Sends the byte data to the client connected to the terminal (the "host" in terminal emulation).
    func send(source: Terminal, data: ArraySlice<UInt8>)
}

public protocol TerminalDisplayDelegate: AnyObject {
    func showCursor(source: Terminal)
    func hideCursor(source: Terminal)
    func sizeChanged(source: Terminal)
    func scrolled(source: Terminal, yDisp: Int)
    func linefeed(source: Terminal)
    func bufferActivated(source: Terminal)
    func synchronizedOutputChanged(source: Terminal, active: Bool)
    func bell(source: Terminal)
    func selectionChanged(source: Terminal)
    func mouseModeChanged(source: Terminal)
    func cursorStyleChanged(source: Terminal, newStyle: CursorStyle)
}

public protocol TerminalWindowDelegate: AnyObject {
    func setTerminalTitle(source: Terminal, title: String)
    func setTerminalIconTitle(source: Terminal, title: String)
    @discardableResult
    func windowCommand(source: Terminal, command: Terminal.WindowManipulationCommand) -> [UInt8]?
    func cellSizeInPixels(source: Terminal) -> (width: Int, height: Int)?
}

public protocol TerminalTrustDelegate: AnyObject {
    func isProcessTrusted(source: Terminal) -> Bool
}

public protocol TerminalHostInfoDelegate: AnyObject {
    func hostCurrentDirectoryUpdated(source: Terminal)
    func hostCurrentDocumentUpdated(source: Terminal)
}

public protocol TerminalColorDelegate: AnyObject {
    func colorChanged(source: Terminal, idx: Int?)
    func setForegroundColor(source: Terminal, color: Color)
    func setBackgroundColor(source: Terminal, color: Color)
    func setCursorColor(source: Terminal, color: Color?)
    func getColors(source: Terminal) -> (foreground: Color, background: Color)
}

public protocol TerminalClipboardDelegate: AnyObject {
    func clipboardCopy(source: Terminal, content: Data)
}

public protocol TerminalNotificationDelegate: AnyObject {
    func notify(source: Terminal, title: String, body: String)
}

public protocol TerminalProgressDelegate: AnyObject {
    func progressReport(source: Terminal, report: Terminal.ProgressReport)
}

public protocol TerminalITermDelegate: AnyObject {
    func iTermContent(source: Terminal, content: ArraySlice<UInt8>)
}

public protocol TerminalImageDelegate: AnyObject {
    func createImageFromBitmap(source: Terminal, bytes: inout [UInt8], width: Int, height: Int)
    func createImage(source: Terminal, data: Data, width: ImageSizeRequest, height: ImageSizeRequest, preserveAspectRatio: Bool)
}

public protocol TerminalSemanticPromptDelegate: AnyObject {
    /// Called when a semantic prompt event is received via OSC 133.
    func semanticPromptChanged(source: Terminal, state: SemanticPromptState)
    /// Called when a command completes (OSC 133 ; D), with the exit code if available.
    func commandCompleted(source: Terminal, exitCode: Int?)
}

// MARK: - Default Implementations

public extension TerminalDisplayDelegate {
    func showCursor(source: Terminal) {}
    func hideCursor(source: Terminal) {}
    func sizeChanged(source: Terminal) {}
    func scrolled(source: Terminal, yDisp: Int) {}
    func linefeed(source: Terminal) {}
    func bufferActivated(source: Terminal) {}
    func synchronizedOutputChanged(source: Terminal, active: Bool) {}
    func bell(source: Terminal) {}
    func selectionChanged(source: Terminal) {}
    func mouseModeChanged(source: Terminal) {}
    func cursorStyleChanged(source: Terminal, newStyle: CursorStyle) {}
}

public extension TerminalWindowDelegate {
    func setTerminalTitle(source: Terminal, title: String) {}
    func setTerminalIconTitle(source: Terminal, title: String) {}
    func windowCommand(source: Terminal, command: Terminal.WindowManipulationCommand) -> [UInt8]? { nil }
    func cellSizeInPixels(source: Terminal) -> (width: Int, height: Int)? { nil }
}

public extension TerminalTrustDelegate {
    func isProcessTrusted(source: Terminal) -> Bool { true }
}

public extension TerminalHostInfoDelegate {
    func hostCurrentDirectoryUpdated(source: Terminal) {}
    func hostCurrentDocumentUpdated(source: Terminal) {}
}

public extension TerminalColorDelegate {
    func colorChanged(source: Terminal, idx: Int?) {}
    func getColors(source: Terminal) -> (foreground: Color, background: Color) {
        (source.foregroundColor, source.backgroundColor)
    }
    func setForegroundColor(source: Terminal, color: Color) {
        source.foregroundColor = color
    }
    func setBackgroundColor(source: Terminal, color: Color) {
        source.backgroundColor = color
    }
    func setCursorColor(source: Terminal, color: Color?) {
        source.cursorColor = color
    }
}

public extension TerminalClipboardDelegate {
    func clipboardCopy(source: Terminal, content: Data) {}
}

public extension TerminalNotificationDelegate {
    func notify(source: Terminal, title: String, body: String) {}
}

public extension TerminalProgressDelegate {
    func progressReport(source: Terminal, report: Terminal.ProgressReport) {}
}

public extension TerminalITermDelegate {
    func iTermContent(source: Terminal, content: ArraySlice<UInt8>) {}
}

public extension TerminalImageDelegate {
    func createImageFromBitmap(source: Terminal, bytes: inout [UInt8], width: Int, height: Int) {}
    func createImage(source: Terminal, data: Data, width: ImageSizeRequest, height: ImageSizeRequest, preserveAspectRatio: Bool) {}
}

public extension TerminalSemanticPromptDelegate {
    func semanticPromptChanged(source: Terminal, state: SemanticPromptState) {}
    func commandCompleted(source: Terminal, exitCode: Int?) {}
}

// MARK: - Backwards-Compatible Composite Protocol

public protocol TerminalDelegate: AnyObject,
    TerminalOutputDelegate,
    TerminalDisplayDelegate,
    TerminalWindowDelegate,
    TerminalTrustDelegate,
    TerminalHostInfoDelegate,
    TerminalColorDelegate,
    TerminalClipboardDelegate,
    TerminalNotificationDelegate,
    TerminalProgressDelegate,
    TerminalITermDelegate,
    TerminalImageDelegate,
    TerminalSemanticPromptDelegate {}

// MARK: - Delegate Container

/// Explicit container for delegates to avoid "god interface" implementations.
/// Each field is optional so consumers can implement only what they need.
public final class TerminalDelegates {
    public weak var output: TerminalOutputDelegate?
    public weak var display: TerminalDisplayDelegate?
    public weak var window: TerminalWindowDelegate?
    public weak var trust: TerminalTrustDelegate?
    public weak var hostInfo: TerminalHostInfoDelegate?
    public weak var color: TerminalColorDelegate?
    public weak var clipboard: TerminalClipboardDelegate?
    public weak var notification: TerminalNotificationDelegate?
    public weak var progress: TerminalProgressDelegate?
    public weak var iterm: TerminalITermDelegate?
    public weak var image: TerminalImageDelegate?
    public weak var semanticPrompt: TerminalSemanticPromptDelegate?

    public init() {}

    /// Convenience initializer for unified delegate implementations.
    public convenience init(unified delegate: TerminalDelegate) {
        self.init()
        output = delegate
        display = delegate
        window = delegate
        trust = delegate
        hostInfo = delegate
        color = delegate
        clipboard = delegate
        notification = delegate
        progress = delegate
        iterm = delegate
        image = delegate
        semanticPrompt = delegate
    }
}
