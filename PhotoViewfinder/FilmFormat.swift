import Foundation

/// A capture format (sensor or film gate) described by its physical size in millimetres.
struct FilmFormat: Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String
    /// Long side of the gate in mm.
    let width: Double
    /// Short side of the gate in mm.
    let height: Double
    /// Common focal lengths for this format, ascending.
    let presets: [Double]

    var diagonal: Double { hypot(width, height) }

    /// Diagonal crop factor relative to 36×24 full frame.
    var cropFactor: Double { FilmFormat.fullFrame.diagonal / diagonal }

    func fullFrameEquivalent(_ focal: Double) -> Double { focal * cropFactor }

    /// Angles of view in degrees for a rectilinear lens focused at infinity.
    func angleOfView(_ focal: Double) -> (horizontal: Double, vertical: Double, diagonal: Double) {
        func aov(_ size: Double) -> Double { 2 * atan(size / (2 * focal)) * 180 / .pi }
        return (aov(width), aov(height), aov(diagonal))
    }

    var focalRange: ClosedRange<Double> {
        let lo = max(2, (presets.first ?? 10) * 0.6)
        let hi = (presets.last ?? 300) * 1.5
        return lo...hi
    }

    /// Rounds a continuously-adjusted focal length to a sensible step.
    func rounded(_ focal: Double) -> Double {
        let clamped = min(max(focal, focalRange.lowerBound), focalRange.upperBound)
        if clamped < 20 { return (clamped * 2).rounded() / 2 }
        return clamped.rounded()
    }
}

extension FilmFormat {
    static let fullFrame = FilmFormat(
        id: "ff", name: "Full Frame (36×24)", shortName: "FF", width: 36, height: 24,
        presets: [14, 16, 20, 24, 28, 35, 40, 50, 58, 75, 85, 105, 135, 200, 300, 400, 600])

    static let all: [FilmFormat] = [
        fullFrame,
        FilmFormat(
            id: "apsc", name: "APS-C (23.5×15.6)", shortName: "APS-C", width: 23.5, height: 15.6,
            presets: [10, 12, 16, 18, 23, 27, 33, 35, 50, 56, 70, 90, 135, 200]),
        FilmFormat(
            id: "apsc-canon", name: "APS-C Canon (22.3×14.9)", shortName: "APS-C 1.6×", width: 22.3, height: 14.9,
            presets: [10, 11, 15, 18, 22, 24, 32, 35, 50, 55, 85, 135, 250]),
        FilmFormat(
            id: "mft", name: "Micro Four Thirds (17.3×13)", shortName: "MFT", width: 17.3, height: 13,
            presets: [7, 9, 12, 15, 17, 20, 25, 42.5, 45, 60, 75, 100, 150, 300]),
        FilmFormat(
            id: "gfx", name: "Medium Format (44×33)", shortName: "44×33", width: 43.8, height: 32.9,
            presets: [20, 23, 30, 35, 45, 50, 55, 63, 80, 110, 120, 250]),
        FilmFormat(
            id: "645", name: "Film 6×4.5 (56×41.5)", shortName: "6×4.5", width: 56, height: 41.5,
            presets: [35, 45, 55, 75, 80, 105, 150, 210, 300]),
        FilmFormat(
            id: "66", name: "Film 6×6 (56×56)", shortName: "6×6", width: 56, height: 56,
            presets: [40, 50, 60, 80, 100, 120, 150, 180, 250]),
        FilmFormat(
            id: "67", name: "Film 6×7 (70×56)", shortName: "6×7", width: 70, height: 56,
            presets: [43, 50, 55, 65, 75, 90, 110, 127, 150, 180, 250, 360]),
        FilmFormat(
            id: "xpan", name: "Panoramic XPan (65×24)", shortName: "XPan", width: 65, height: 24,
            presets: [30, 45, 90]),
        FilmFormat(
            id: "4x5", name: "Large Format 4×5 (121×97)", shortName: "4×5", width: 121, height: 97,
            presets: [65, 75, 90, 120, 135, 150, 180, 210, 240, 300, 450]),
    ]

    static func byID(_ id: String) -> FilmFormat {
        all.first { $0.id == id } ?? fullFrame
    }
}

enum FocalText {
    static func string(_ focal: Double) -> String {
        if abs(focal - focal.rounded()) < 0.05 { return String(Int(focal.rounded())) }
        return String(format: "%.1f", focal)
    }
}
