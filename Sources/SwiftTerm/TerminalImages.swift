import Foundation

/// Enumeration passed to the image delegate to configure desired width/height values.
public enum ImageSizeRequest {
    /// Make the best decision based on the image data.
    case auto
    /// Occupy exactly the number of cells.
    case cells(Int)
    /// Occupy exactly the pixels listed.
    case pixels(Int)
    /// Occupy a percentange size relative to the dimension of the visible region.
    case percent(Int)
}

public protocol TerminalImage {
    /// The width of the image in pixels.
    var pixelWidth: Int { get }
    /// The height of the image in pixels.
    var pixelHeight: Int { get }

    /// Column where the image was attached.
    var col: Int { get set }
}
