import SwiftUI
import UIKit

// MARK: - Knob (endless encoder or absolute pot)

struct KnobView: View {
    let diameter: CGFloat
    /// Visual rotation in degrees (encoders spin freely, pots map value).
    var angle: Double
    var showPointer: Bool = true
    /// Called with integer detent steps (+ clockwise / up).
    var onStep: (Int) -> Void
    var onTap: (() -> Void)? = nil

    @State private var accum: CGFloat = 0
    @State private var lastTranslation: CGSize = .zero
    @State private var lastAngle: Double? = nil

    private var stepDistance: CGFloat { max(6, diameter * 0.16) }

    var body: some View {
        ZStack {
            // drop shadow / skirt
            Circle()
                .fill(Color.black.opacity(0.45))
                .frame(width: diameter * 1.04, height: diameter * 1.04)
                .offset(y: diameter * 0.06)
                .blur(radius: diameter * 0.05)
            // knurled skirt
            Circle()
                .fill(AngularGradient(gradient: Gradient(colors: knurl()), center: .center))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(angle))
            // cap
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x3a3a3a), Color(hex: 0x141414)],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: diameter * 0.5))
                .frame(width: diameter * 0.8, height: diameter * 0.8)
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            if showPointer {
                Capsule()
                    .fill(Color.white)
                    .frame(width: diameter * 0.13, height: diameter * 0.22)
                    .offset(y: -diameter * 0.26)
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: diameter * 1.6, height: diameter * 1.6)
        .contentShape(Circle().scale(1.3))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    // combine vertical drag (up = increase) with horizontal
                    let dy = -(g.translation.height - lastTranslation.height)
                    let dx = (g.translation.width - lastTranslation.width)
                    lastTranslation = g.translation
                    accum += dy + dx * 0.6
                    let steps = Int(accum / stepDistance)
                    if steps != 0 {
                        accum -= CGFloat(steps) * stepDistance
                        onStep(steps)
                    }
                }
                .onEnded { g in
                    if abs(g.translation.width) < 3 && abs(g.translation.height) < 3 { onTap?() }
                    lastTranslation = .zero
                    accum = 0
                }
        )
    }

    private func knurl() -> [Color] {
        var c: [Color] = []
        for i in 0..<48 { c.append(i % 2 == 0 ? Color(hex: 0x1d1d1d) : Color(hex: 0x0b0b0b)) }
        c.append(c[0])
        return c
    }
}

// MARK: - Rubber function button

enum ButtonLight { case off, on, blue, red, green }

struct RubberButton: View {
    let lines: [String]
    let size: CGSize
    let colorway: Colorway
    var light: ButtonLight = .off
    var underline = false
    var action: () -> Void
    var onLongPress: (() -> Void)? = nil
    var onHoldChange: ((Bool) -> Void)? = nil
    @State private var pressed = false
    @State private var longFired = false
    @State private var holdTask: Task<Void, Never>? = nil

    var body: some View {
        let legend: Color = {
            switch light {
            case .off: return colorway.legendOff
            case .on: return colorway.legendOn
            case .blue: return Color(hex: 0x8fd6ff)
            case .red: return Color(hex: 0xff4a3d)
            case .green: return Color(hex: 0x5dff7a)
            }
        }()
        ZStack {
            RoundedRectangle(cornerRadius: size.width * 0.18)
                .fill(Color.black.opacity(0.55))
                .offset(y: pressed ? size.height * 0.02 : size.height * 0.07)
                .blur(radius: 1.5)
            RoundedRectangle(cornerRadius: size.width * 0.18)
                .fill(LinearGradient(colors: [colorway.rubber.lighter(0.07), colorway.rubber.darker(0.05)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: size.width * 0.18)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.14), Color.black.opacity(0.25)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .offset(y: pressed ? size.height * 0.03 : 0)
            VStack(spacing: size.height * 0.02) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, l in
                    Text(l)
                        .font(PanelFont.legend(size.height * (lines.count > 1 ? 0.2 : 0.24)))
                        .foregroundStyle(legend)
                        .shadow(color: light == .off ? .clear : legend.opacity(0.9), radius: size.width * 0.06)
                    if underline && i == 0 && lines.count > 1 {
                        Rectangle().fill(legend).frame(width: size.width * 0.5, height: max(1, size.height * 0.025))
                    }
                }
            }
            .offset(y: pressed ? size.height * 0.03 : 0)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    longFired = false
                    Haptics.tap()
                    onHoldChange?(true)
                    if let onLongPress {
                        holdTask = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.7))
                            guard !Task.isCancelled, pressed else { return }
                            longFired = true
                            Haptics.tap()
                            onLongPress()
                        }
                    }
                }
                .onEnded { _ in
                    pressed = false
                    holdTask?.cancel()
                    onHoldChange?(false)
                    if !longFired { action() }
                }
        )
    }
}

// MARK: - Silicone key pad (stadium)

struct PadKeyView: View {
    let size: CGSize
    let colorway: Colorway
    var label: String? = nil
    var shortStripe = false
    var pressed = false
    var lit: Color? = nil

    var body: some View {
        let r = size.width / 2
        let stripeH = shortStripe ? size.height * 0.26 : size.height * 0.56
        ZStack {
            RoundedRectangle(cornerRadius: r)
                .fill(Color.black.opacity(0.5))
                .offset(y: pressed ? 1 : size.height * 0.035)
                .blur(radius: 2)
            RoundedRectangle(cornerRadius: r)
                .fill(LinearGradient(colors: [colorway.rubber.lighter(pressed ? 0.0 : 0.06), colorway.rubber.darker(0.06)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: r)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.13), Color.black.opacity(0.3)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .scaleEffect(pressed ? 0.97 : 1)
            // LED stripe
            Capsule()
                .fill(lit ?? colorway.stripeOff)
                .frame(width: max(2, size.width * 0.1), height: stripeH)
                .shadow(color: (lit ?? .clear).opacity(0.95), radius: lit == nil ? 0 : size.width * 0.18)
                .offset(y: shortStripe ? -size.height * 0.16 : 0)
            if let label {
                Text(label)
                    .font(.system(size: size.width * 0.21, weight: .bold, design: .rounded))
                    .foregroundStyle(colorway.legendOff.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .offset(y: size.height * 0.24)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Colour helpers

extension Color {
    func lighter(_ amount: Double) -> Color { mix(with: .white, by: amount) }
    func darker(_ amount: Double) -> Color { mix(with: .black, by: amount) }
}

enum Haptics {
    static let generator = UIImpactFeedbackGenerator(style: .light)
    static func tap() { generator.impactOccurred(intensity: 0.6) }
}

// MARK: - Multitouch keyboard surface

/// Transparent UIKit view tracking any number of touches; reports which
/// key index each touch is over (supports glissando).
struct MultiTouchSurface: UIViewRepresentable {
    /// Returns key index for a point in the view's coordinate space, plus velocity 1...127.
    var hitTest: (CGPoint) -> (Int, Int)?
    var onDown: (Int, Int) -> Void
    var onUp: (Int) -> Void

    func makeUIView(context: Context) -> TouchView {
        let v = TouchView()
        v.isMultipleTouchEnabled = true
        v.backgroundColor = .clear
        v.owner = self
        return v
    }
    func updateUIView(_ uiView: TouchView, context: Context) { uiView.owner = self }

    final class TouchView: UIView {
        var owner: MultiTouchSurface?
        private var touchKeys: [ObjectIdentifier: Int] = [:]
        private var keyCounts: [Int: Int] = [:]

        private func press(_ key: Int, vel: Int) {
            keyCounts[key, default: 0] += 1
            if keyCounts[key] == 1 { owner?.onDown(key, vel) }
        }
        private func release(_ key: Int) {
            guard let c = keyCounts[key] else { return }
            if c <= 1 { keyCounts[key] = nil; owner?.onUp(key) } else { keyCounts[key] = c - 1 }
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            for t in touches {
                if let (k, v) = owner?.hitTest(t.location(in: self)) {
                    touchKeys[ObjectIdentifier(t)] = k
                    press(k, vel: v)
                }
            }
        }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            for t in touches {
                let id = ObjectIdentifier(t)
                let new = owner?.hitTest(t.location(in: self))
                let old = touchKeys[id]
                if new?.0 != old {
                    if let old { release(old) }
                    if let (k, v) = new { touchKeys[id] = k; press(k, vel: v) } else { touchKeys[id] = nil }
                }
            }
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            for t in touches {
                if let k = touchKeys.removeValue(forKey: ObjectIdentifier(t)) { release(k) }
            }
        }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with: event) }
    }
}
