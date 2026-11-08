import SwiftUI

/// The device front panel. All positions are fractions of the body size,
/// measured from top-down product shots (body aspect 161.5 × 96.5 mm).
struct PanelView: View {
    @ObservedObject var model: SynthModel
    let width: CGFloat
    /// nil = hardware proportions; otherwise stretch to this height (full-screen mode)
    var height: CGFloat? = nil
    /// false = no case / rounded body: the iPad itself is the device
    var framed = true

    static let aspect: CGFloat = 161.5 / 96.5

    @State private var knobAngles: [Double] = Array(repeating: 0, count: 7)

    private var W: CGFloat { width }
    private var H: CGFloat { height ?? width / PanelView.aspect }
    private func x(_ p: CGFloat) -> CGFloat { W * p / 100 }
    private func y(_ p: CGFloat) -> CGFloat { H * p / 100 }

    // Keyboard geometry
    static let whiteFirst: CGFloat = 8.6
    static let whitePitch: CGFloat = (91.6 - 8.6) / 15
    static func whiteX(_ i: Int) -> CGFloat { whiteFirst + CGFloat(i) * whitePitch }
    /// x% for key index 0...26
    static func keyX(_ k: Int) -> CGFloat {
        if let wi = SynthModel.whiteKeys.firstIndex(of: k) { return whiteX(wi) }
        // black: midway between neighbour whites
        let left = SynthModel.whiteKeys.lastIndex { $0 < k }!
        return (whiteX(left) + whiteX(left + 1)) / 2
    }
    static func isBlack(_ k: Int) -> Bool { SynthModel.blackKeys.contains(k) }

    var body: some View {
        let cw = model.colorway
        ZStack(alignment: .topLeading) {
            bodyShape(cw)
            silkscreen(cw)
            knobs(cw)
            octaveTray(cw)
            screen
            buttonTray(cw)
            keyboard(cw)
        }
        .frame(width: W, height: H)
    }

    // MARK: Body

    @ViewBuilder private func bodyShape(_ cw: Colorway) -> some View {
        if framed { framedBody(cw) } else {
            ZStack {
                Rectangle().fill(LinearGradient(colors: [cw.bodyHighlight, cw.body, cw.body.darker(0.04)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                Rectangle()
                    .fill(ImagePaint(image: Image(uiImage: Noise.texture), scale: 0.5))
                    .opacity(0.05)
                    .blendMode(.overlay)
            }
            .frame(width: W, height: H)
        }
    }

    private func framedBody(_ cw: Colorway) -> some View {
        let r = W * 0.05
        return ZStack {
            // side / depth
            RoundedRectangle(cornerRadius: r)
                .fill(cw.body.darker(0.35))
                .offset(y: H * 0.018)
                .shadow(color: .black.opacity(0.55), radius: W * 0.02, y: W * 0.012)
            RoundedRectangle(cornerRadius: r)
                .fill(LinearGradient(colors: [cw.bodyHighlight, cw.body, cw.body.darker(0.04)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: r)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.18), Color.black.opacity(0.25)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: max(1, W * 0.0018))
            // fine matte grain
            RoundedRectangle(cornerRadius: r)
                .fill(ImagePaint(image: Image(uiImage: Noise.texture), scale: 0.5))
                .opacity(0.05)
                .blendMode(.overlay)
        }
        .frame(width: W, height: H)
    }

    private func label(_ t: String, _ cx: CGFloat, _ cy: CGFloat, _ cw: Colorway) -> some View {
        Text(t)
            .font(PanelFont.silkscreen(W * 0.0145))
            .tracking(W * 0.0006)
            .foregroundStyle(cw.silkscreen)
            .fixedSize()
            .position(x: x(cx), y: y(cy))
    }

    private func silkscreen(_ cw: Colorway) -> some View {
        ZStack {
            label("MASTER", 9.0, 9.0, cw)
            label("SELECT", 19.4, 9.0, cw)
            label("PRESETS", 9.0, 25.8, cw)
            label("ALGORITHM", 19.4, 25.8, cw)
            label("KNOB1", 56.3, 9.0, cw)
            label("KNOB2", 67.3, 9.0, cw)
            label("KNOB3", 78.3, 9.0, cw)
            label("KNOB4", 89.4, 9.0, cw)
            // dot between button rows
            Circle().fill(cw.silkscreen.opacity(0.8)).frame(width: W * 0.004).position(x: x(73.0), y: y(39.6))
            // dots between key rows at B–C / E–F gaps
            ForEach([3, 6, 10, 13], id: \.self) { i in
                Circle().fill(cw.silkscreen.opacity(0.7)).frame(width: W * 0.0042)
                    .position(x: x((PanelView.whiteX(i) + PanelView.whiteX(i + 1)) / 2), y: y(74.6))
            }
        }
        .frame(width: W, height: H)
        .allowsHitTesting(false)
    }

    // MARK: Knobs

    private func knobs(_ cw: Colorway) -> some View {
        let d = W * 0.044
        let masterAngle = -150 + 300 * model.globals.master
        return ZStack {
            KnobView(diameter: d, angle: masterAngle, onStep: { model.turnMaster($0) })
                .position(x: x(9.0), y: y(16.5))
            encoder(0, d) { model.turnSelect($0) }.position(x: x(19.4), y: y(16.5))
            encoder(1, d) { model.turnPresets($0) }.position(x: x(9.0), y: y(33.6))
            encoder(2, d) { model.turnAlgorithm($0) }.position(x: x(19.4), y: y(33.6))
            ForEach(0..<4, id: \.self) { k in
                encoder(3 + k, d) { model.turnKnob(k, $0) }
                    .position(x: x([56.3, 67.3, 78.3, 89.4][k]), y: y(16.5))
            }
        }
        .frame(width: W, height: H)
    }

    private func encoder(_ i: Int, _ d: CGFloat, _ onStep: @escaping (Int) -> Void) -> some View {
        KnobView(diameter: d, angle: knobAngles[i], showPointer: false, onStep: { s in
            knobAngles[i] += Double(s) * 18
            onStep(s)
        })
    }

    // MARK: Octave tray

    private func octaveTray(_ cw: Colorway) -> some View {
        let bs = CGSize(width: W * 0.064, height: H * 0.058)
        return ZStack {
            tray(cw, rect: CGRect(x: x(6.4), y: y(43.1), width: x(15.4), height: y(7.8)), radius: W * 0.008)
            octButton(-1, "OCT-", bs, cw).position(x: x(10.4), y: y(47.0))
            octButton(1, "OCT+", bs, cw).position(x: x(17.8), y: y(47.0))
        }
        .frame(width: W, height: H)
    }

    private func octButton(_ dir: Int, _ text: String, _ size: CGSize, _ cw: Colorway) -> some View {
        OctaveButton(text: text, size: size, colorway: cw, light: model.buttonLight(dir < 0 ? .octDown : .octUp),
                     onDown: { model.octDown(dir) }, onUp: { model.octUp(dir) })
    }

    private func tray(_ cw: Colorway, rect: CGRect, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(cw.well.darker(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(LinearGradient(colors: [Color.black.opacity(0.5), Color.white.opacity(0.12)], startPoint: .top, endPoint: .bottom), lineWidth: max(1, W * 0.0015))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .fill(LinearGradient(colors: [Color.black.opacity(0.25), .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.25)))
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    // MARK: Screen

    private var screen: some View {
        // full-screen mode uses the extra height for a bigger display
        let bezelW = framed ? x(23.1) : min(x(26.0), y(40.0))
        let side = bezelW * 0.76
        return ZStack {
            RoundedRectangle(cornerRadius: bezelW * 0.13)
                .fill(LinearGradient(colors: [Color(hex: 0x15191a), Color(hex: 0x050707)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: bezelW * 0.13).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                .frame(width: bezelW, height: bezelW)
            TFTScreen(state: model.screen, side: side, scope: { scopeData() })
                .offset(y: -bezelW * 0.015)
            // glass reflection
            RoundedRectangle(cornerRadius: bezelW * 0.13)
                .fill(LinearGradient(colors: [Color.white.opacity(0.06), .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: bezelW, height: bezelW)
                .allowsHitTesting(false)
        }
        .position(x: x(37.95), y: y(27.75))
    }

    private func scopeData() -> [Float] {
        let e = model.engine
        let n = FMEngine.scopeSize
        var out = [Float](repeating: 0, count: n)
        let w = e.scopeWrite
        for i in 0..<n { out[i] = e.scope[(w + i) & (n - 1)] }
        return out
    }

    // MARK: Buttons

    private func buttonTray(_ cw: Colorway) -> some View {
        let cols: [CGFloat] = [57.5, 63.7, 69.8, 76.1, 82.3, 88.5]
        let size = CGSize(width: W * 0.051, height: W * 0.051)
        let row1: [(String, PanelButton)] = [("FX", .fx), ("SEL", .sel), ("ENV", .env), ("LFO", .lfo), ("EDIT", .edit), ("GLO", .glo)]
        let row2: [(String, PanelButton)] = [("HOME", .home), ("SAVE", .save), ("ARP", .arp), ("SEQ", .seq), ("PLAY", .play), ("REC", .rec)]
        return ZStack {
            tray(cw, rect: CGRect(x: x(53.3), y: y(28.2), width: x(39.4), height: y(22.7)), radius: W * 0.012)
            ForEach(0..<6, id: \.self) { i in
                button(row1[i].0, row1[i].1, size, cw).position(x: x(cols[i]), y: y(34.6))
                button(row2[i].0, row2[i].1, size, cw).position(x: x(cols[i]), y: y(44.7))
            }
            Circle().fill(cw.silkscreen.opacity(0.6)).frame(width: W * 0.004).position(x: x(73.0), y: y(39.7))
        }
        .frame(width: W, height: H)
    }

    private func button(_ text: String, _ b: PanelButton, _ size: CGSize, _ cw: Colorway) -> some View {
        let lines = b == .play ? ["PLAY", "STOP"] : [text]
        return RubberButton(lines: lines, size: size, colorway: cw, light: model.buttonLight(b), underline: b == .play,
                            action: { model.press(b) },
                            onLongPress: { model.longPress(b) },
                            onHoldChange: b == .rec ? { model.recHeld = $0 } : (b == .glo ? { model.gloHeld = $0; if !$0 { model.audio.groove.fill = false } } : nil))
    }

    // MARK: Keyboard

    private func keyboard(_ cw: Colorway) -> some View {
        let wellRect = CGRect(x: x(4.3), y: y(56.6), width: x(91.4), height: y(37.0))
        let whiteSize = CGSize(width: x(4.45), height: y(15.0))
        let blackSize = CGSize(width: x(4.25), height: y(14.4))
        let editing = model.mode == .edit
        return ZStack(alignment: .topLeading) {
            tray(cw, rect: wellRect, radius: W * 0.018)
            ForEach(0..<27, id: \.self) { k in
                let black = PanelView.isBlack(k)
                let size = black ? blackSize : whiteSize
                let label = SynthModel.editLabels[k]
                PadKeyView(size: size, colorway: cw, label: label, shortStripe: label != nil,
                           pressed: model.pressedKeys.contains(k), lit: model.keyLED(k))
                    .opacity(editing && black && label != nil ? 1 : 1)
                    .position(x: x(PanelView.keyX(k)), y: y(black ? 66.6 : 82.6))
                    .allowsHitTesting(false)
            }
            MultiTouchSurface(
                hitTest: { p in keyAt(p) },
                onDown: { k, _ in model.keyDown(k, velocity: model.globals.velocity) },
                onUp: { k in model.keyUp(k) })
                .frame(width: wellRect.width, height: wellRect.height)
                .offset(x: wellRect.minX, y: wellRect.minY)
        }
        .frame(width: W, height: H, alignment: .topLeading)
    }

    /// Point in the well's coordinate space → key index.
    private func keyAt(_ p: CGPoint) -> (Int, Int)? {
        let px = p.x + x(4.3)
        let py = p.y + y(56.6)
        let yPct = py / H * 100
        let xPct = px / W * 100
        // upper row: black pads (with generous hit zones), lower row: white pads
        if yPct < 74.6 {
            var best: Int? = nil
            var bestD = CGFloat.greatestFiniteMagnitude
            for k in SynthModel.blackKeys {
                let d = abs(PanelView.keyX(k) - xPct)
                if d < bestD { bestD = d; best = k }
            }
            if bestD < PanelView.whitePitch * 0.5 { return best.map { ($0, 100) } }
            return nil
        }
        let idx = Int(((xPct - PanelView.whiteFirst) / PanelView.whitePitch).rounded())
        guard idx >= 0 && idx < 16 else { return nil }
        return (SynthModel.whiteKeys[idx], 100)
    }
}

/// OCT buttons need press + release (combos with ALGORITHM / each other).
struct OctaveButton: View {
    let text: String
    let size: CGSize
    let colorway: Colorway
    let light: ButtonLight
    var onDown: () -> Void
    var onUp: () -> Void
    @State private var down = false

    var body: some View {
        RubberButton(lines: [text], size: size, colorway: colorway, light: light, action: {}, onHoldChange: { h in
            if h && !down { down = true; onDown() }
            if !h && down { down = false; onUp() }
        })
    }
}

enum Noise {
    static let texture: UIImage = {
        let size = 128
        let r = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return r.image { ctx in
            var g = SystemRandomNumberGenerator()
            for yy in 0..<size {
                for xx in 0..<size {
                    let v = CGFloat(UInt8.random(in: 0...255, using: &g)) / 255
                    UIColor(white: v, alpha: 1).setFill()
                    ctx.fill(CGRect(x: xx, y: yy, width: 1, height: 1))
                }
            }
        }
    }()
}
