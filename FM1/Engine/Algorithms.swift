import Foundation

/// One of the 32 classic 6-operator FM algorithms.
/// Operators are numbered 1...6 (index 0...5). Modulation always flows
/// from a higher-numbered operator to a lower-numbered one, so rendering
/// operators 6 → 1 guarantees modulators are computed before their targets.
struct FMAlgorithm {
    /// modulators[i] = operator numbers (1-based) that modulate operator i+1
    let modulators: [[Int]]
    /// carriers (1-based) mixed to the output
    let carriers: [Int]
    /// operator receiving feedback (1-based)
    let feedbackOp: Int
    /// operator whose previous output feeds back (== feedbackOp for self feedback)
    let feedbackFrom: Int

    init(_ edges: [(Int, Int)], carriers: [Int], fb: Int, fbFrom: Int? = nil) {
        var m = Array(repeating: [Int](), count: 6)
        for (src, dst) in edges { m[dst - 1].append(src) }
        self.modulators = m
        self.carriers = carriers
        self.feedbackOp = fb
        self.feedbackFrom = fbFrom ?? fb
    }

    func isCarrier(_ op: Int) -> Bool { carriers.contains(op) }

    static let all: [FMAlgorithm] = [
        /* 1 */ FMAlgorithm([(2,1),(4,3),(5,4),(6,5)], carriers: [1,3], fb: 6),
        /* 2 */ FMAlgorithm([(2,1),(4,3),(5,4),(6,5)], carriers: [1,3], fb: 2),
        /* 3 */ FMAlgorithm([(2,1),(3,2),(5,4),(6,5)], carriers: [1,4], fb: 6),
        /* 4 */ FMAlgorithm([(2,1),(3,2),(5,4),(6,5)], carriers: [1,4], fb: 6, fbFrom: 4),
        /* 5 */ FMAlgorithm([(2,1),(4,3),(6,5)], carriers: [1,3,5], fb: 6),
        /* 6 */ FMAlgorithm([(2,1),(4,3),(6,5)], carriers: [1,3,5], fb: 6, fbFrom: 5),
        /* 7 */ FMAlgorithm([(2,1),(4,3),(5,3),(6,5)], carriers: [1,3], fb: 6),
        /* 8 */ FMAlgorithm([(2,1),(4,3),(5,3),(6,5)], carriers: [1,3], fb: 4),
        /* 9 */ FMAlgorithm([(2,1),(4,3),(5,3),(6,5)], carriers: [1,3], fb: 2),
        /* 10 */ FMAlgorithm([(2,1),(3,2),(5,4),(6,4)], carriers: [1,4], fb: 3),
        /* 11 */ FMAlgorithm([(2,1),(3,2),(5,4),(6,4)], carriers: [1,4], fb: 6),
        /* 12 */ FMAlgorithm([(2,1),(4,3),(5,3),(6,3)], carriers: [1,3], fb: 2),
        /* 13 */ FMAlgorithm([(2,1),(4,3),(5,3),(6,3)], carriers: [1,3], fb: 6),
        /* 14 */ FMAlgorithm([(2,1),(4,3),(5,4),(6,4)], carriers: [1,3], fb: 6),
        /* 15 */ FMAlgorithm([(2,1),(4,3),(5,4),(6,4)], carriers: [1,3], fb: 2),
        /* 16 */ FMAlgorithm([(2,1),(3,1),(4,3),(5,1),(6,5)], carriers: [1], fb: 6),
        /* 17 */ FMAlgorithm([(2,1),(3,1),(4,3),(5,1),(6,5)], carriers: [1], fb: 2),
        /* 18 */ FMAlgorithm([(2,1),(3,1),(4,1),(5,4),(6,5)], carriers: [1], fb: 3),
        /* 19 */ FMAlgorithm([(2,1),(3,2),(6,4),(6,5)], carriers: [1,4,5], fb: 6),
        /* 20 */ FMAlgorithm([(3,1),(3,2),(5,4),(6,4)], carriers: [1,2,4], fb: 3),
        /* 21 */ FMAlgorithm([(3,1),(3,2),(6,4),(6,5)], carriers: [1,2,4,5], fb: 3),
        /* 22 */ FMAlgorithm([(2,1),(6,3),(6,4),(6,5)], carriers: [1,3,4,5], fb: 6),
        /* 23 */ FMAlgorithm([(3,2),(6,4),(6,5)], carriers: [1,2,4,5], fb: 6),
        /* 24 */ FMAlgorithm([(6,3),(6,4),(6,5)], carriers: [1,2,3,4,5], fb: 6),
        /* 25 */ FMAlgorithm([(6,4),(6,5)], carriers: [1,2,3,4,5], fb: 6),
        /* 26 */ FMAlgorithm([(3,2),(5,4),(6,4)], carriers: [1,2,4], fb: 6),
        /* 27 */ FMAlgorithm([(3,2),(5,4),(6,4)], carriers: [1,2,4], fb: 3),
        /* 28 */ FMAlgorithm([(2,1),(4,3),(5,4)], carriers: [1,3,6], fb: 5),
        /* 29 */ FMAlgorithm([(4,3),(6,5)], carriers: [1,2,3,5], fb: 6),
        /* 30 */ FMAlgorithm([(4,3),(5,4)], carriers: [1,2,3,6], fb: 5),
        /* 31 */ FMAlgorithm([(6,5)], carriers: [1,2,3,4,5], fb: 6),
        /* 32 */ FMAlgorithm([], carriers: [1,2,3,4,5,6], fb: 6),
    ]
}
