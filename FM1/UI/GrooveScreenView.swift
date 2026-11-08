import SwiftUI

/// Groove-mode step grid on the 240×240 TFT: track chip + page tabs,
/// a 4×4 grid of the 16 visible steps, and the K1–K4 values.
struct GrooveGridView: View {
    let g: GrooveScreen
    let s: CGFloat

    private var accent: Color { g.trackColor == 0 ? ScreenPalette.tile : Color(hex: 0xffb86b) }
    private var accentDark: Color { g.trackColor == 0 ? ScreenPalette.tileOutline : Color(hex: 0xb5651d) }

    var body: some View {
        VStack(spacing: 5 * s) {
            header
            grid
            knobs
        }
        .padding(.horizontal, 8 * s)
        .padding(.vertical, 5 * s)
    }

    private var header: some View {
        HStack(spacing: 5 * s) {
            Text(g.track)
                .font(PanelFont.screen(12 * s, weight: .bold))
                .foregroundStyle(ScreenPalette.text)
                .lineLimit(1)
                .padding(.horizontal, 6 * s)
                .frame(height: 17 * s)
                .background(Capsule().fill(accent))
                .overlay(Capsule().stroke(accentDark, lineWidth: 1 * s))
            Text("P\(g.pattern)")
                .font(PanelFont.screen(12 * s, weight: .bold))
                .foregroundStyle(ScreenPalette.text)
            if g.rec {
                Circle().fill(ScreenPalette.red).frame(width: 7 * s, height: 7 * s)
            }
            Spacer(minLength: 0)
            HStack(spacing: 2 * s) {
                ForEach(0..<4, id: \.self) { i in
                    Text("\(i + 1)")
                        .font(PanelFont.screen(10 * s, weight: .bold))
                        .foregroundStyle(i < g.pages ? ScreenPalette.text : ScreenPalette.text.opacity(0.3))
                        .frame(width: 15 * s, height: 14 * s)
                        .background(RoundedRectangle(cornerRadius: 3 * s).fill(i == g.page ? accent : Color.white.opacity(0.25)))
                        .overlay(RoundedRectangle(cornerRadius: 3 * s).stroke(ScreenPalette.tileOutline.opacity(i == g.page ? 1 : 0.4), lineWidth: 0.8 * s))
                }
            }
        }
    }

    private var grid: some View {
        VStack(spacing: 4 * s) {
            ForEach(0..<4, id: \.self) { r in
                HStack(spacing: 4 * s) {
                    ForEach(0..<4, id: \.self) { c in
                        cell(r * 4 + c)
                    }
                }
            }
        }
    }

    private func cell(_ i: Int) -> some View {
        let c = g.cells[i]
        let stepNo = g.page * 16 + i + 1
        return ZStack {
            RoundedRectangle(cornerRadius: 4 * s)
                .fill(c.on ? AnyShapeStyle(LinearGradient(colors: [accent.lighter(0.35), accent], startPoint: .top, endPoint: .bottom))
                           : AnyShapeStyle(Color.white.opacity(c.inRange ? 0.32 : 0.08)))
                .overlay(RoundedRectangle(cornerRadius: 4 * s)
                    .stroke(c.cursor ? ScreenPalette.red : (c.on ? accentDark : ScreenPalette.tileOutline.opacity(c.inRange ? 0.55 : 0.2)),
                            lineWidth: (c.cursor ? 2 : 1) * s))
            if c.inRange {
                Text(c.label)
                    .font(PanelFont.screen(11 * s, weight: c.on ? .bold : .regular))
                    .foregroundStyle(ScreenPalette.text.opacity(c.on ? 1 : 0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .offset(y: 2 * s)
                Text("\(stepNo)")
                    .font(PanelFont.screen(7 * s, weight: .semibold))
                    .foregroundStyle(ScreenPalette.text.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 3 * s).padding(.top, 1 * s)
                // markers
                HStack(spacing: 1.5 * s) {
                    if c.cond { Text("?").font(PanelFont.screen(8 * s, weight: .bold)).foregroundStyle(ScreenPalette.text) }
                    if c.lock { Circle().fill(Color.white).overlay(Circle().stroke(ScreenPalette.text, lineWidth: 0.6 * s)).frame(width: 4.5 * s, height: 4.5 * s) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 3 * s).padding(.top, 2 * s)
                if c.ratchet > 1 {
                    HStack(spacing: 1.2 * s) {
                        ForEach(0..<c.ratchet, id: \.self) { _ in
                            Circle().fill(ScreenPalette.text).frame(width: 2.6 * s, height: 2.6 * s)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 3 * s).padding(.bottom, 2 * s)
                }
                if c.tie {
                    Rectangle().fill(accentDark).frame(width: 3 * s)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(x: 3.5 * s)
                }
            }
            if c.playhead {
                RoundedRectangle(cornerRadius: 1.5 * s).fill(Color(hex: 0x2fd35a))
                    .frame(height: 3 * s)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 3 * s)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 22 * s)
    }

    private var knobs: some View {
        HStack(spacing: 4 * s) {
            ForEach(Array(g.knobs.enumerated()), id: \.offset) { _, k in
                VStack(spacing: 0) {
                    Text(k.name).font(PanelFont.screen(8 * s, weight: .semibold)).foregroundStyle(ScreenPalette.text.opacity(0.65))
                    Text(k.value).font(PanelFont.screen(12 * s, weight: .bold)).foregroundStyle(ScreenPalette.text)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 24 * s)
                .background(RoundedRectangle(cornerRadius: 4 * s).fill(ScreenPalette.tileHighlight.opacity(0.7)))
                .overlay(RoundedRectangle(cornerRadius: 4 * s).stroke(ScreenPalette.tileOutline.opacity(0.6), lineWidth: 0.8 * s))
            }
        }
    }
}
