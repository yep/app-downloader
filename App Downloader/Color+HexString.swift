//
//  Color+HexString.swift
//  App Downloader
//
//  Created by Jahn Bertsch on 04.03.23.
//

import AppKit

extension NSColor {
    static var labelColorHexString: String {
        get {
            var hexColor = "#000000"
            if let color = NSColor.labelColor.usingColorSpace(.deviceRGB) {
                let red   = Int(round(color.redComponent   * color.alphaComponent * 0xFF))
                let green = Int(round(color.greenComponent * color.alphaComponent * 0xFF))
                let blue  = Int(round(color.blueComponent  * color.alphaComponent * 0xFF))
                hexColor = String(format: "#%02X%02X%02X", red, green, blue)
            }
            return hexColor
        }
    }
}
