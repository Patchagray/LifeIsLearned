// Run from the repository root: swift Brand/render-icon.swift
// Original vector construction for reviewer-selected Direction A, Idea Fold.
// Produces editable SVG sources and opaque sRGB 1024px AppIcon PNGs.
import AppKit

let output = URL(fileURLWithPath: "LifeIsLearned/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let variants = [
    ("Any", "174E4B", "F7F3E8", "C7A76B"),
    ("Dark", "102C2C", "E9E5D7", "BE9E65"),
    ("Tinted", "171717", "EEEEEE", "999999")
]
func color(_ hex: String) -> CGColor {
    let v = UInt32(hex, radix: 16)!
    return CGColor(srgbRed: CGFloat((v >> 16) & 255) / 255,
                   green: CGFloat((v >> 8) & 255) / 255,
                   blue: CGFloat(v & 255) / 255, alpha: 1)
}
for (name, background, paper, fold) in variants {
    // Generous safe margins and one bold path survive home-screen reduction.
    // The system, rather than the artwork, applies the outer rounded mask.
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
      <rect width="1024" height="1024" fill="#\(background)"/>
      <path d="M280 216 H580 L744 380 V792 H280 Z" fill="#\(paper)"/>
      <path d="M580 216 V380 H744 Z" fill="#\(fold)"/>
      <path d="M398 380 V674 H632" fill="none" stroke="#\(background)" stroke-width="72"/>
    </svg>
    """
    try svg.write(toFile: "Brand/IdeaFold-\(name).svg", atomically: true, encoding: .utf8)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                            bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.translateBy(x: 0, y: 1024); context.scaleBy(x: 1, y: -1)
    context.setFillColor(color(background)); context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    func polygon(_ points: [CGPoint], fill: String) {
        context.beginPath(); context.move(to: points[0])
        for point in points.dropFirst() { context.addLine(to: point) }
        context.closePath(); context.setFillColor(color(fill)); context.fillPath()
    }
    polygon([CGPoint(x: 280, y: 216), CGPoint(x: 580, y: 216), CGPoint(x: 744, y: 380),
             CGPoint(x: 744, y: 792), CGPoint(x: 280, y: 792)], fill: paper)
    polygon([CGPoint(x: 580, y: 216), CGPoint(x: 580, y: 380), CGPoint(x: 744, y: 380)], fill: fold)
    context.beginPath(); context.move(to: CGPoint(x: 398, y: 380))
    context.addLine(to: CGPoint(x: 398, y: 674)); context.addLine(to: CGPoint(x: 632, y: 674))
    context.setStrokeColor(color(background)); context.setLineWidth(72)
    context.setLineCap(.butt); context.setLineJoin(.miter); context.strokePath()
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("IdeaFold-\(name).png"))
}
let images: [[String: Any]] = variants.map { name, _, _, _ in
    var value: [String: Any] = ["filename": "IdeaFold-\(name).png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]
    if name != "Any" { value["appearances"] = [["appearance": "luminosity", "value": name.lowercased()]] }
    return value
}
let manifest: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
