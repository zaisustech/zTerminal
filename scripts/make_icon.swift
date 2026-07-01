import AppKit
import CoreGraphics
import Foundation

// zTerminal app icon: a dark terminal window (traffic-light dots + glowing `>_`
// prompt) floating on a vibrant Liquid Glass gradient — instantly reads as a
// developer terminal tool, crisp from 16px to 1024px.

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}
func rr(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(_ ctx: CGContext, _ S: CGFloat) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let full = CGRect(x: 0, y: 0, width: S, height: S)
    let bg = rr(full, S * 0.2237)

    ctx.saveGState(); ctx.addPath(bg); ctx.clip()

    // 1) Vibrant diagonal gradient background.
    let grad = CGGradient(colorsSpace: cs,
        colors: [rgba(79, 140, 255), rgba(139, 92, 246), rgba(56, 189, 248)] as CFArray,
        locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
    // Soft top-left sheen.
    let sheen = CGGradient(colorsSpace: cs,
        colors: [rgba(255, 255, 255, 0.28), rgba(255, 255, 255, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(sheen, startCenter: CGPoint(x: S*0.28, y: S*0.8), startRadius: 0,
                           endCenter: CGPoint(x: S*0.28, y: S*0.8), endRadius: S*0.6, options: [])
    ctx.restoreGState()

    // 2) Terminal window card.
    let m = S * 0.155
    let win = CGRect(x: m, y: m, width: S - 2*m, height: S - 2*m)
    let winPath = rr(win, S * 0.085)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S*0.012), blur: S*0.05, color: rgba(0,0,0,0.45))
    ctx.addPath(winPath)
    ctx.setFillColor(rgba(13, 16, 26))       // dark terminal background
    ctx.fillPath()
    ctx.restoreGState()

    // Title strip highlight + thin border.
    ctx.saveGState(); ctx.addPath(winPath); ctx.clip()
    let strip = CGGradient(colorsSpace: cs,
        colors: [rgba(255,255,255,0.10), rgba(255,255,255,0)] as CFArray, locations: [0,1])!
    ctx.drawLinearGradient(strip, start: CGPoint(x: 0, y: win.maxY),
                           end: CGPoint(x: 0, y: win.maxY - S*0.14), options: [])
    ctx.restoreGState()
    ctx.addPath(winPath)
    ctx.setStrokeColor(rgba(255,255,255,0.14)); ctx.setLineWidth(max(1, S*0.004)); ctx.strokePath()

    // 3) Traffic-light dots (top-left of the window).
    let dotR = S * 0.021
    let dotY = win.maxY - S*0.072
    let dotColors = [rgba(255,95,87), rgba(254,188,46), rgba(40,200,64)]
    for (i, c) in dotColors.enumerated() {
        let x = win.minX + S*0.075 + CGFloat(i) * S*0.062
        ctx.setFillColor(c)
        ctx.fillEllipse(in: CGRect(x: x - dotR, y: dotY - dotR, width: dotR*2, height: dotR*2))
    }

    // 4) Glowing prompt  ">"  + cursor block, centered in the window body.
    let cx = win.midX, cy = win.midY - S*0.03
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.setShadow(offset: .zero, blur: S*0.03, color: rgba(52, 211, 153, 0.9))
    ctx.setStrokeColor(rgba(52, 211, 153))    // emerald prompt
    ctx.setLineWidth(S * 0.055)
    let armX = cx - S*0.17, tipX = cx - S*0.02, armY = S*0.11
    ctx.beginPath()
    ctx.move(to: CGPoint(x: armX, y: cy + armY))
    ctx.addLine(to: CGPoint(x: tipX, y: cy))
    ctx.addLine(to: CGPoint(x: armX, y: cy - armY))
    ctx.strokePath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // cursor block to the right of the chevron
    let cur = CGRect(x: cx + S*0.03, y: cy - S*0.11, width: S*0.16, height: S*0.05)
    ctx.addPath(rr(cur, S*0.02))
    ctx.setFillColor(rgba(103, 208, 251))     // cyan cursor
    ctx.fillPath()

    // 5) Outer rim highlight.
    ctx.addPath(bg)
    ctx.setStrokeColor(rgba(255,255,255,0.18)); ctx.setLineWidth(max(1, S*0.006)); ctx.strokePath()
}

func renderPNG(size: Int, to url: URL) {
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
    ctx.interpolationQuality = .high
    drawIcon(ctx, CGFloat(size))
    guard let img = ctx.makeImage(),
          let dst = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { return }
    CGImageDestinationAddImage(dst, img, nil)
    CGImageDestinationFinalize(dst)
}

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "./AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let variants: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"), (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]
for (px, name) in variants { renderPNG(size: px, to: URL(fileURLWithPath: "\(outDir)/\(name).png")) }
renderPNG(size: 1024, to: URL(fileURLWithPath: "\(outDir)/../AppIcon-preview.png"))
print("wrote iconset to \(outDir)")
