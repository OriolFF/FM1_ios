import SwiftUI

/// One display-list frame drawn by a package script on the 240×240 TFT.
struct PackageFrame: Equatable {
    enum Cmd {
        case clear(Color)
        case rect(CGRect, Color, CGFloat)
        case frame(CGRect, Color, CGFloat, CGFloat)
        case line(CGPoint, CGPoint, Color, CGFloat)
        case circle(CGPoint, CGFloat, Color)
        case ring(CGPoint, CGFloat, Color, CGFloat)
        case arc(CGPoint, CGFloat, Double, Double, Color, CGFloat)
        case text(CGPoint, String, CGFloat, Color, Int, Bool, String)   // align -1/0/1, bold, font
        case scope(CGRect, Color, CGFloat)
    }
    var cmds: [Cmd] = []
    var serial = 0
    /// Text drawn this frame, for accessibility / UI tests.
    var label = ""
    static func == (a: PackageFrame, b: PackageFrame) -> Bool { a.serial == b.serial }

    // MARK: parse from the script's command arrays

    static func color(_ v: Any?) -> Color {
        guard var s = v as? String else { return .white }
        if s.hasPrefix("#") { s.removeFirst() }
        guard let n = UInt64(s, radix: 16) else { return .white }
        if s.count == 8 {
            return Color(.sRGB, red: Double((n >> 24) & 0xff) / 255, green: Double((n >> 16) & 0xff) / 255,
                         blue: Double((n >> 8) & 0xff) / 255, opacity: Double(n & 0xff) / 255)
        }
        return Color(.sRGB, red: Double((n >> 16) & 0xff) / 255, green: Double((n >> 8) & 0xff) / 255, blue: Double(n & 0xff) / 255, opacity: 1)
    }

    static func parse(_ list: [Any], serial: Int) -> PackageFrame {
        var f = PackageFrame(serial: serial)
        var texts: [String] = []
        func d(_ a: [Any], _ i: Int) -> CGFloat { i < a.count ? CGFloat((a[i] as? NSNumber)?.doubleValue ?? 0) : 0 }
        for item in list.prefix(4000) {
            guard let a = item as? [Any], let op = a.first as? String else { continue }
            switch op {
            case "clear": f.cmds.append(.clear(color(a.count > 1 ? a[1] : nil)))
            case "rect": f.cmds.append(.rect(CGRect(x: d(a, 1), y: d(a, 2), width: d(a, 3), height: d(a, 4)), color(a.count > 5 ? a[5] : nil), d(a, 6)))
            case "frame": f.cmds.append(.frame(CGRect(x: d(a, 1), y: d(a, 2), width: d(a, 3), height: d(a, 4)), color(a.count > 5 ? a[5] : nil), max(0.5, d(a, 6)), d(a, 7)))
            case "line": f.cmds.append(.line(CGPoint(x: d(a, 1), y: d(a, 2)), CGPoint(x: d(a, 3), y: d(a, 4)), color(a.count > 5 ? a[5] : nil), max(0.5, d(a, 6))))
            case "circle": f.cmds.append(.circle(CGPoint(x: d(a, 1), y: d(a, 2)), d(a, 3), color(a.count > 4 ? a[4] : nil)))
            case "ring": f.cmds.append(.ring(CGPoint(x: d(a, 1), y: d(a, 2)), d(a, 3), color(a.count > 4 ? a[4] : nil), max(0.5, d(a, 5))))
            case "arc": f.cmds.append(.arc(CGPoint(x: d(a, 1), y: d(a, 2)), d(a, 3), Double(d(a, 4)), Double(d(a, 5)), color(a.count > 6 ? a[6] : nil), max(0.5, d(a, 7))))
            case "text":
                let s = a.count > 3 ? "\(a[3])" : ""
                let align = (a.count > 6 ? a[6] as? String : nil).map { $0 == "center" ? 0 : ($0 == "right" ? 1 : -1) } ?? -1
                let bold = (a.count > 7 ? a[7] as? String : nil) == "bold"
                let font = (a.count > 8 ? a[8] as? String : nil) ?? "sans"
                f.cmds.append(.text(CGPoint(x: d(a, 1), y: d(a, 2)), s, max(4, d(a, 4)), color(a.count > 5 ? a[5] : nil), align, bold, font))
                texts.append(s)
            case "scope": f.cmds.append(.scope(CGRect(x: d(a, 1), y: d(a, 2), width: d(a, 3), height: d(a, 4)), color(a.count > 5 ? a[5] : nil), max(0.5, d(a, 6))))
            default: break
            }
        }
        f.label = texts.joined(separator: " ")
        return f
    }
}

/// Draws a PackageFrame at any size (the TFT's logical 240×240 scaled by `s`).
struct PackageScreenView: View {
    let frame: PackageFrame
    let s: CGFloat
    let scope: () -> [Float]

    private func font(_ name: String, _ size: CGFloat, bold: Bool) -> Font {
        switch name {
        case "mono", "tech": return .custom("ShareTech-Regular", size: size)
        case "display": return PanelFont.legend(size)
        case "square": return PanelFont.silkscreen(size)
        default: return PanelFont.screen(size, weight: bold ? .bold : .medium)
        }
    }

    var body: some View {
        Canvas { ctx, _ in
            ctx.scaleBy(x: s, y: s)
            for c in frame.cmds {
                switch c {
                case .clear(let col):
                    ctx.fill(Path(CGRect(x: 0, y: 0, width: 240, height: 240)), with: .color(col))
                case let .rect(r, col, rad):
                    ctx.fill(rad > 0 ? Path(roundedRect: r, cornerRadius: rad) : Path(r), with: .color(col))
                case let .frame(r, col, lw, rad):
                    ctx.stroke(rad > 0 ? Path(roundedRect: r, cornerRadius: rad) : Path(r), with: .color(col), lineWidth: lw)
                case let .line(a, b, col, lw):
                    var p = Path(); p.move(to: a); p.addLine(to: b)
                    ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                case let .circle(cnt, r, col):
                    ctx.fill(Path(ellipseIn: CGRect(x: cnt.x - r, y: cnt.y - r, width: r * 2, height: r * 2)), with: .color(col))
                case let .ring(cnt, r, col, lw):
                    ctx.stroke(Path(ellipseIn: CGRect(x: cnt.x - r, y: cnt.y - r, width: r * 2, height: r * 2)), with: .color(col), lineWidth: lw)
                case let .arc(cnt, r, a0, a1, col, lw):
                    var p = Path()
                    p.addArc(center: cnt, radius: r, startAngle: .degrees(a0 - 90), endAngle: .degrees(a1 - 90), clockwise: false)
                    ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                case let .text(pt, str, size, col, align, bold, fnt):
                    let t = ctx.resolve(Text(str).font(font(fnt, size, bold: bold)).foregroundColor(col))
                    let anchor: UnitPoint = align == 0 ? .top : (align > 0 ? .topTrailing : .topLeading)
                    ctx.draw(t, at: pt, anchor: anchor)
                case let .scope(r, col, lw):
                    let data = scope()
                    guard data.count > 1 else { break }
                    // trigger on a rising zero crossing for a steady trace
                    var start = 0
                    for i in 1..<(data.count / 2) where data[i - 1] <= 0 && data[i] > 0 { start = i; break }
                    let n = min(data.count - start, 256)
                    var p = Path()
                    for i in 0..<n {
                        let x = r.minX + r.width * CGFloat(i) / CGFloat(max(1, n - 1))
                        let y = r.midY - CGFloat(max(-1, min(1, data[start + i] * 2.2))) * r.height / 2
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: lw, lineJoin: .round))
                }
            }
        }
        .accessibilityElement()
        .accessibilityIdentifier("PackageScreen")
        .accessibilityLabel(frame.label)
    }
}
