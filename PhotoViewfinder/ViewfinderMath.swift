import CoreGraphics
import Foundation

/// Static optical properties of the phone camera, measured at zoom factor 1.
struct CameraInfo: Equatable {
    var deviceName: String
    /// tan(half the field of view) along the sensor's long axis at zoom 1.
    var tanHalfLong: Double
    /// Long side / short side of the active capture format (e.g. 4/3).
    var sensorAspect: Double
    var minZoom: Double
    var maxZoom: Double
    var switchOverZooms: [Double]

    var longFOVDegrees: Double { 2 * atan(tanHalfLong) * 180 / .pi }

    /// Full-frame focal length whose long-side angle of view matches the phone at `zoom`.
    func fullFrameEquivalent(zoom: Double, calibration: Double) -> Double {
        18 / (tanHalfLong * calibration / zoom)
    }
}

/// Geometry that maps a chosen format + focal length onto the phone preview.
///
/// The UI is locked to portrait, so the sensor's long axis runs vertically on screen.
/// The frame's long side follows the device's long axis: hold the phone upright for a
/// portrait frame, turn it sideways for a landscape one. `rotated` swaps that.
struct ViewfinderMath {
    var camera: CameraInfo
    var calibration: Double
    var format: FilmFormat
    var focal: Double
    var rotated: Bool

    private var frameAlongLong: Double { rotated ? format.height : format.width }
    private var frameAlongShort: Double { rotated ? format.width : format.height }

    /// Portion of the phone sensor (0...1+) covered by the target frame along each axis.
    func sensorFractions(zoom: Double) -> (long: Double, short: Double) {
        let tanLong = camera.tanHalfLong * calibration / zoom
        let tanShort = tanLong / camera.sensorAspect
        return (
            (frameAlongLong / (2 * focal)) / tanLong,
            (frameAlongShort / (2 * focal)) / tanShort
        )
    }

    /// The size of the full sensor image when drawn aspect-fill into `container` (portrait).
    func displayedSensorSize(in container: CGSize) -> CGSize {
        let width = max(container.width, container.height / camera.sensorAspect)
        return CGSize(width: width, height: width * camera.sensorAspect)
    }

    func frameRect(zoom: Double, in container: CGSize) -> CGRect {
        let f = sensorFractions(zoom: zoom)
        let sensor = displayedSensorSize(in: container)
        let size = CGSize(width: f.short * sensor.width, height: f.long * sensor.height)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width, height: size.height)
    }

    /// Zoom factor that makes the frame fill `fill` (0...1) of the container's limiting side.
    /// The frame's on-screen size scales linearly with zoom, so measuring at zoom 1 is enough.
    func desiredZoom(in container: CGSize, fill: Double) -> Double {
        let r = frameRect(zoom: 1, in: container)
        guard r.width > 0, r.height > 0, container.width > 0, container.height > 0 else { return 1 }
        let z = fill * min(container.width / r.width, container.height / r.height)
        return min(max(z, camera.minZoom), camera.maxZoom)
    }

    /// True when the target is wider than the phone can see even at its widest lens.
    var isWiderThanCamera: Bool {
        let f = sensorFractions(zoom: camera.minZoom)
        return f.long > 1.001 || f.short > 1.001
    }
}
