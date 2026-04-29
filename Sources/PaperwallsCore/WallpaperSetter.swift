import AppKit
import Foundation

public protocol DesktopWallpaperApplying: Sendable {
    func apply(_ fileURL: URL) throws
}

public struct SystemDesktopWallpaperSetter: DesktopWallpaperApplying {
    public init() {}

    public func apply(_ fileURL: URL) throws {
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen, options: [:])
        }
    }
}

