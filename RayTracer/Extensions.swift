//
//  Extensions.swift
//  RayTracer
//
//  Created by Nik Willwerth on 7/23/21.
//

import Cocoa

extension NSWindow {
    
    /// Positions the `NSWindow` at the horizontal-vertical center of the `visibleFrame` (takes Status Bar and Dock sizes into account)
    public func positionCenter() {
        if let screenSize = screen?.visibleFrame.size {
            self.setFrameOrigin(NSPoint(x: (screenSize.width-frame.size.width)/2, y: (screenSize.height-frame.size.height)/2))
        }
    }
    /// Centers the window within the `visibleFrame`, and sizes it with the width-by-height dimensions provided.
    public func setCenterFrame(width: Int, height: Int) {
        if let screenSize = screen?.visibleFrame.size {
            let x = (screenSize.width-frame.size.width)/2
            let y = (screenSize.height-frame.size.height)/2
            self.setFrame(NSRect(x: x, y: y, width: CGFloat(width), height: CGFloat(height)), display: true)
        }
    }
    /// Returns the center x-point of the `screen.visibleFrame` (the frame between the Status Bar and Dock).
    /// Falls back on `screen.frame` when `.visibleFrame` is unavailable (includes Status Bar and Dock).
    public func xCenter() -> CGFloat {
        if let screenSize = screen?.visibleFrame.size { return (screenSize.width-frame.size.width)/2 }
        if let screenSize = screen?.frame.size { return (screenSize.width-frame.size.width)/2 }
        return CGFloat(0)
    }
    /// Returns the center y-point of the `screen.visibleFrame` (the frame between the Status Bar and Dock).
    /// Falls back on `screen.frame` when `.visibleFrame` is unavailable (includes Status Bar and Dock).
    public func yCenter() -> CGFloat {
        if let screenSize = screen?.visibleFrame.size { return (screenSize.height-frame.size.height)/2 }
        if let screenSize = screen?.frame.size { return (screenSize.height-frame.size.height)/2 }
        return CGFloat(0)
    }
    
    var titlebarHeight: CGFloat {
        frame.height - contentRect(forFrameRect: frame).height
    }
}
