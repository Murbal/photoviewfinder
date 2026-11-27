import CoreMotion
import SwiftUI

/// Tracks how the phone is physically held using gravity, so it works even with
/// rotation lock on and the UI fixed to portrait.
final class OrientationMonitor: ObservableObject {
    @Published private(set) var orientation: UIDeviceOrientation = .portrait

    private let motion = CMMotionManager()

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.15
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            guard abs(g.z) < 0.85 else { return }  // lying flat: keep last orientation
            let next: UIDeviceOrientation?
            if abs(g.x) > abs(g.y) + 0.25 {
                next = g.x < 0 ? .landscapeLeft : .landscapeRight
            } else if abs(g.y) > abs(g.x) + 0.25 {
                next = g.y < 0 ? .portrait : .portraitUpsideDown
            } else {
                next = nil
            }
            if let next, next != self.orientation {
                withAnimation(.easeInOut(duration: 0.25)) { self.orientation = next }
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    /// Rotation that keeps overlay text upright for the viewer.
    var rotation: Angle {
        switch orientation {
        case .landscapeLeft: return .degrees(90)
        case .landscapeRight: return .degrees(-90)
        case .portraitUpsideDown: return .degrees(180)
        default: return .zero
        }
    }
}
