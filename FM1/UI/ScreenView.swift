import SwiftUI

struct ScreenTile: Equatable {
    var name: String
    var value: String?
    var bar: Double? = nil
    var marked = false
    var dim = false
}

enum ScreenContent: Equatable {
    case osc
    case algorithm(Int, feedback: Int)
    case tiles([ScreenTile])
    case fx(selected: Int, active: [Bool])
    case save(bankName: String, selected: Int)
    case message(String, String?)
    case presetList(Int, [String])
}

struct ScreenState: Equatable {
    var presetNumber: Int = 1
    var presetName: String = "PIANO 1"
    var trailing: String = "3"
    var footer: String = "OSC"
    var content: ScreenContent = .osc
    var transientValue: String? = nil  // pop-up when a knob is turned
    var fxNames: [String] = ["Filter", "Reverb", "Delay", "Distortion", "Chorus", "Phaser"]
    var fxGrabbed = false
}

/// 240×240 logical TFT, scaled to the given side.
struct TFTScreen: View {
    let state: ScreenState
    let side: CGFloat
    let scope: () -> [Float]

    var body: some View {
        let s = side / 240
        ZStack(alignment: .top) {
            background
            VStack(spacing: 0) {
                header(s)
                Rectangle().fill(dividerColor).frame(height: max(1, s))
                ZStack {
                    content(s)
                    if let t = state.transientValue { transient(t, s) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Rectangle().fill(dividerColor).frame(height: max(1, s))
                footer(s)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 3 * s))
    }

    private var isDark: Bool { if case .osc = state.content { return true }; return false }
    private var dividerColor: Color { isDark ? Color.white.opacity(0.15) : ScreenPalette.divider }

    @ViewBuilder private var background: some View {
        if isDark {
            LinearGradient(colors: [ScreenPalette.oscBackground, ScreenPalette.oscBackground2], startPoint: .top, endPoint: .bottom)
        } else {
            LinearGradient(colors: [ScreenPalette.background, ScreenPalette.backgroundBottom], startPoint: .top, endPoint: .bottom)
        }
    }

    private func header(_ s: CGFloat) -> some View {
        HStack(spacing: 6 * s) {
            Text(String(format: "%03d %@", state.presetNumber, state.presetName))
                .font(PanelFont.screen(19 * s, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(state.trailing)
                .font(PanelFont.screen(19 * s, weight: .medium))
            Spacer(minLength: 0)
            battery(s)
        }
        .foregroundStyle(isDark ? Color.white.opacity(0.92) : ScreenPalette.header)
        .padding(.horizontal, 8 * s)
        .frame(height: 34 * s)
    }

    private func battery(_ s: CGFloat) -> some View {
        let c: Color = isDark ? .white.opacity(0.9) : ScreenPalette.header
        return HStack(spacing: 1 * s) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3 * s).stroke(c, lineWidth: 1.6 * s)
                HStack(spacing: 2 * s) {
                    RoundedRectangle(cornerRadius: 1 * s).fill(c).frame(width: 5 * s)
                    RoundedRectangle(cornerRadius: 1 * s).fill(c).frame(width: 5 * s)
                }.padding(3 * s)
            }
            .frame(width: 26 * s, height: 16 * s)
            RoundedRectangle(cornerRadius: 1 * s).fill(c).frame(width: 2 * s, height: 6 * s)
        }
    }

    private func footer(_ s: CGFloat) -> some View {
        Text(state.footer)
            .font(PanelFont.screen(17 * s, weight: .medium))
            .foregroundStyle(ScreenPalette.text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .frame(height: 24 * s)
            .background(
                RoundedRectangle(cornerRadius: 6 * s)
                    .fill(LinearGradient(colors: [ScreenPalette.tileHighlight, ScreenPalette.tile], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 6 * s).stroke(ScreenPalette.tileOutline, lineWidth: 1 * s))
            )
            .padding(.horizontal, 14 * s)
            .padding(.vertical, 5 * s)
    }

    @ViewBuilder private func content(_ s: CGFloat) -> some View {
        switch state.content {
        case .osc:
            OscilloscopeView(scope: scope, scale: s)
        case let .algorithm(n, fb):
            AlgorithmDiagram(algorithm: n, feedback: fb, scale: s)
        case let .tiles(tiles):
            tileGrid(tiles, columns: 2, s: s)
        case let .fx(sel, active):
            let names = state.fxNames.map { $0 == "Distortion" ? "Distort-\nion" : $0 }
            let tiles = names.enumerated().map { ScreenTile(name: $0.element, value: nil, marked: $0.offset == sel, dim: !active[$0.offset]) }
            tileGrid(tiles, columns: 3, s: s, selected: state.fxGrabbed ? sel : nil)
        case let .save(bank, sel):
            saveDialog(bank, sel, s)
        case let .message(title, sub):
            VStack(spacing: 6 * s) {
                Text(title).font(PanelFont.screen(22 * s, weight: .semibold))
                if let sub { Text(sub).font(PanelFont.screen(16 * s)) }
            }
            .foregroundStyle(ScreenPalette.text)
            .multilineTextAlignment(.center)
            .padding(10 * s)
        case let .presetList(sel, names):
            presetList(sel, names, s)
        }
    }

    private func tileGrid(_ tiles: [ScreenTile], columns: Int, s: CGFloat, selected: Int? = nil) -> some View {
        let rows = Int(ceil(Double(tiles.count) / Double(columns)))
        return VStack(spacing: 8 * s) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 8 * s) {
                    ForEach(0..<columns, id: \.self) { c in
                        let i = r * columns + c
                        if i < tiles.count {
                            tileView(tiles[i], s: s, compact: columns > 2, selected: selected == i)
                        } else {
                            Color.clear
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10 * s)
        .padding(.vertical, columns > 2 ? 22 * s : 9 * s)
    }

    private func tileView(_ t: ScreenTile, s: CGFloat, compact: Bool, selected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6 * s)
                .fill(LinearGradient(colors: t.dim ? [Color(hex: 0xa9c9d6), Color(hex: 0x8fb4c4)] : [selected ? Color(hex: 0xe6fbff) : ScreenPalette.tileHighlight.opacity(0.9), selected ? ScreenPalette.tileHighlight : ScreenPalette.tile], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 6 * s).stroke(ScreenPalette.tileOutline, lineWidth: (selected ? 2 : 1) * s))
                .shadow(color: .black.opacity(0.18), radius: 0, x: 1 * s, y: 1.5 * s)
            VStack(spacing: 1 * s) {
                Text(t.name)
                    .font(PanelFont.screen((compact ? 15 : 19) * s, weight: .medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
                if let v = t.value {
                    Text(v)
                        .font(PanelFont.screen(15 * s, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                if let b = t.bar {
                    // block bar graph (ENV)
                    HStack(spacing: 1.5 * s) {
                        ForEach(0..<10, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1 * s)
                                .fill(Double(i) < b * 10 - 0.001 ? ScreenPalette.text.opacity(0.75) : ScreenPalette.text.opacity(0.12))
                                .frame(width: 5 * s, height: 7 * s)
                        }
                    }
                    .padding(.top, 3 * s)
                }
            }
            .foregroundStyle(ScreenPalette.text.opacity(t.dim ? 0.65 : 1))
            .padding(.horizontal, 3 * s)
            if compact && t.marked {
                Circle().fill(ScreenPalette.red).frame(width: 6 * s, height: 6 * s)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(y: 9 * s)
            }
        }
    }

    private func saveDialog(_ bank: String, _ sel: Int, _ s: CGFloat) -> some View {
        VStack(spacing: 12 * s) {
            Text("32 Voice Save To ...")
                .font(PanelFont.screen(17 * s, weight: .medium))
                .foregroundStyle(.white)
            HStack(spacing: 10 * s) {
                ForEach(0..<4, id: \.self) { i in
                    let letter = ["A", "B", "C", "D"][i]
                    Text(letter)
                        .font(PanelFont.screen(17 * s, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34 * s, height: 34 * s)
                        .background(Circle().fill(i == sel ? Color(hex: 0x3a8fb8) : Color(hex: 0x1a2228)))
                        .overlay(Circle().stroke(Color.white.opacity(i == sel ? 1 : 0.6), lineWidth: 1.5 * s))
                }
            }
            Text("K1–K4 bank · SELECT ok · HOME cancel")
                .font(PanelFont.screen(11 * s))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(14 * s)
        .background(RoundedRectangle(cornerRadius: 10 * s).fill(ScreenPalette.dialog))
        .overlay(RoundedRectangle(cornerRadius: 10 * s).stroke(Color.white.opacity(0.25), lineWidth: 1 * s))
        .padding(8 * s)
    }

    private func presetList(_ sel: Int, _ names: [String], _ s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2 * s) {
            ForEach(Array(names.enumerated()), id: \.offset) { i, n in
                Text(n)
                    .font(PanelFont.screen(16 * s, weight: i == sel ? .bold : .regular))
                    .foregroundStyle(ScreenPalette.text)
                    .padding(.horizontal, 6 * s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 22 * s)
                    .background(RoundedRectangle(cornerRadius: 4 * s).fill(i == sel ? ScreenPalette.tile : .clear))
            }
        }
        .padding(8 * s)
    }

    private func transient(_ text: String, _ s: CGFloat) -> some View {
        Text(text)
            .font(PanelFont.screen(18 * s, weight: .semibold))
            .foregroundStyle(ScreenPalette.text)
            .padding(.horizontal, 12 * s)
            .padding(.vertical, 8 * s)
            .background(RoundedRectangle(cornerRadius: 8 * s).fill(ScreenPalette.tileHighlight))
            .overlay(RoundedRectangle(cornerRadius: 8 * s).stroke(ScreenPalette.tileOutline, lineWidth: 1.5 * s))
            .shadow(color: .black.opacity(0.25), radius: 3 * s, y: 2 * s)
    }
}

// MARK: - Oscilloscope

struct OscilloscopeView: View {
    let scope: () -> [Float]
    let scale: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { _ in
            Canvas { ctx, size in
                let data = scope()
                guard data.count > 1 else { return }
                // trigger on rising zero crossing for a stable trace
                var start = 0
                for i in 1..<(data.count / 2) where data[i - 1] < 0 && data[i] >= 0 { start = i; break }
                let n = min(data.count - start, 400)
                var path = Path()
                let mid = size.height / 2
                for i in 0..<n {
                    let x = size.width * CGFloat(i) / CGFloat(n - 1)
                    let y = mid - CGFloat(data[start + i]) * size.height * 0.45
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(path, with: .color(ScreenPalette.oscTrace), lineWidth: 1.4 * scale)
            }
        }
    }
}

// MARK: - Algorithm diagram

struct AlgorithmDiagram: View {
    let algorithm: Int   // 1...32
    let feedback: Int
    let scale: CGFloat

    struct Node { var col: CGFloat; var row: Int }

    /// Tree layout: carriers on the bottom row, modulators stacked above
    /// their targets, shared modulators placed once.
    static func layout(_ alg: FMAlgorithm) -> [Int: Node] {
        var nodes: [Int: Node] = [:]
        var nextCol: CGFloat = 0
        func place(_ op: Int, row: Int) -> CGFloat {
            if let n = nodes[op] { return n.col }
            let mods = alg.modulators[op - 1].sorted()
            let unplaced = mods.filter { nodes[$0] == nil }
            var col: CGFloat
            if unplaced.isEmpty {
                if mods.isEmpty { col = nextCol; nextCol += 1 }
                else {
                    // only shared modulators: sit beside them
                    col = nextCol; nextCol += 1
                }
                nodes[op] = Node(col: col, row: row)
                for m in mods where nodes[m] == nil { _ = place(m, row: row + 1) }
            } else {
                nodes[op] = Node(col: -1, row: row)
                var cols: [CGFloat] = []
                for m in mods { cols.append(place(m, row: row + 1)) }
                col = cols.reduce(0, +) / CGFloat(cols.count)
                nodes[op]!.col = col
            }
            return col
        }
        for c in alg.carriers.sorted() { _ = place(c, row: 0) }
        return nodes
    }

    var body: some View {
        let alg = FMAlgorithm.all[max(0, min(31, algorithm - 1))]
        let nodes = AlgorithmDiagram.layout(alg)
        let cols = (nodes.values.map(\.col).max() ?? 0) + 1
        let rows = (nodes.values.map(\.row).max() ?? 0) + 1
        GeometryReader { geo in
            let s = scale
            let box = 19 * s
            let gapX = min(28 * s, (geo.size.width - 40 * s) / max(cols, 1))
            let gapY = min(28 * s, (geo.size.height - 82 * s) / CGFloat(max(rows - 1, 1)))
            let totalW = gapX * (cols - 1)
            let ox = (geo.size.width - totalW) / 2 + 10 * s
            let baseY = geo.size.height - 46 * s
            let pos: (Int) -> CGPoint = { op in
                let n = nodes[op]!
                return CGPoint(x: ox + n.col * gapX, y: baseY - CGFloat(n.row) * gapY)
            }
            ZStack {
                // guide line
                Rectangle().fill(ScreenPalette.divider.opacity(0.5)).frame(height: 1 * s)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.36)
                Canvas { ctx, _ in
                    var p = Path()
                    for op in 1...6 {
                        for m in alg.modulators[op - 1] {
                            let a = pos(m), b = pos(op)
                            p.move(to: CGPoint(x: a.x, y: a.y + box / 2))
                            let midY = b.y - box / 2 - (gapY - box) / 2
                            p.addLine(to: CGPoint(x: a.x, y: midY))
                            p.addLine(to: CGPoint(x: b.x, y: midY))
                            p.addLine(to: CGPoint(x: b.x, y: b.y - box / 2))
                        }
                    }
                    // carriers to OUT bus
                    let outY = baseY + 16 * s
                    for c in alg.carriers {
                        let a = pos(c)
                        p.move(to: CGPoint(x: a.x, y: a.y + box / 2))
                        p.addLine(to: CGPoint(x: a.x, y: outY))
                    }
                    // feedback bracket
                    let f = pos(alg.feedbackOp), src = pos(alg.feedbackFrom)
                    let bx = max(f.x, src.x) + box / 2 + 5 * s
                    p.move(to: CGPoint(x: src.x + box / 2, y: src.y + box / 2 - 3 * s))
                    p.addLine(to: CGPoint(x: bx, y: src.y + box / 2 - 3 * s))
                    p.addLine(to: CGPoint(x: bx, y: f.y - box / 2 - 4 * s))
                    p.addLine(to: CGPoint(x: f.x, y: f.y - box / 2 - 4 * s))
                    p.addLine(to: CGPoint(x: f.x, y: f.y - box / 2))
                    ctx.stroke(p, with: .color(ScreenPalette.text), lineWidth: 1.3 * s)
                }
                ForEach(1...6, id: \.self) { op in
                    Text("\(op)")
                        .font(PanelFont.screen(14 * s, weight: .bold))
                        .foregroundStyle(ScreenPalette.text)
                        .frame(width: box, height: box)
                        .background(RoundedRectangle(cornerRadius: 4 * s).fill(ScreenPalette.opBox))
                        .overlay(RoundedRectangle(cornerRadius: 4 * s).stroke(ScreenPalette.text, lineWidth: 1 * s))
                        .position(pos(op))
                }
                // OUT pill
                let carriersX = alg.carriers.map { pos($0).x }
                let minX = carriersX.min()!, maxX = carriersX.max()!
                Text("OUT")
                    .font(PanelFont.screen(13 * s, weight: .bold))
                    .foregroundStyle(ScreenPalette.text)
                    .frame(width: max(maxX - minX + box, 44 * s), height: 17 * s)
                    .background(Capsule().fill(ScreenPalette.opBox))
                    .overlay(Capsule().stroke(ScreenPalette.text, lineWidth: 1 * s))
                    .position(x: (minX + maxX) / 2, y: baseY + 24 * s)
                // number badge
                Text(String(format: "%02d", algorithm))
                    .font(PanelFont.screen(16 * s, weight: .bold))
                    .foregroundStyle(ScreenPalette.text)
                    .padding(.horizontal, 7 * s)
                    .frame(height: 22 * s)
                    .background(RoundedRectangle(cornerRadius: 7 * s).fill(ScreenPalette.opBox))
                    .overlay(RoundedRectangle(cornerRadius: 7 * s).stroke(ScreenPalette.text, lineWidth: 1 * s))
                    .position(x: 26 * s, y: 18 * s)
                Text("FB \(feedback)")
                    .font(PanelFont.screen(12 * s, weight: .semibold))
                    .foregroundStyle(ScreenPalette.text.opacity(0.7))
                    .position(x: geo.size.width - 26 * s, y: 18 * s)
            }
        }
    }
}
