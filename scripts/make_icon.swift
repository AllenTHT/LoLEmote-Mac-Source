#!/usr/bin/env swift
import AppKit
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size*scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels)/512, y: CGFloat(pixels)/512)
        NSColor(srgbRed: 0.025, green: 0.06, blue: 0.09, alpha: 1).setFill()
        NSBezierPath(roundedRect: CGRect(x: 20, y: 20, width: 472, height: 472), xRadius: 112, yRadius: 112).fill()
        let gold = NSColor(srgbRed: 0.83, green: 0.70, blue: 0.44, alpha: 1)
        gold.setStroke()
        let ring = NSBezierPath(ovalIn: CGRect(x: 85, y: 85, width: 342, height: 342)); ring.lineWidth = 13; ring.stroke()
        for i in 0..<8 {
            let theta = Double(i)*Double.pi/4
            let line = NSBezierPath(); line.move(to: CGPoint(x: 256+sin(theta)*145, y: 256+cos(theta)*145)); line.line(to: CGPoint(x: 256+sin(theta)*172, y: 256+cos(theta)*172)); line.lineWidth = 9; line.stroke()
        }
        for x in [211.0, 301.0] { gold.setFill(); NSBezierPath(ovalIn: CGRect(x: x-12, y: 280, width: 24, height: 32)).fill() }
        let smile = NSBezierPath(); smile.appendArc(withCenter: CGPoint(x: 256, y: 255), radius: 78, startAngle: 215, endAngle: 325); smile.lineWidth = 13; smile.lineCapStyle = .round; smile.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
