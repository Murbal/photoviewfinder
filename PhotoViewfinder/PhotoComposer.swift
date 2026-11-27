import Photos
import UIKit

enum PhotoComposer {
    enum ComposeError: LocalizedError {
        case crop
        var errorDescription: String? { "Couldn't crop the photo." }
    }

    /// Crops a sensor-oriented capture to the framed area, orients it the way the phone
    /// was held, optionally burns in a caption, and returns JPEG data.
    static func compose(
        _ image: CGImage,
        longFraction: Double,
        shortFraction: Double,
        deviceOrientation: UIDeviceOrientation,
        caption: String?
    ) throws -> Data {
        let w = Double(image.width)
        let h = Double(image.height)
        let landscape = w >= h
        let fx = min(1, landscape ? longFraction : shortFraction)
        let fy = min(1, landscape ? shortFraction : longFraction)
        let cw = (w * fx).rounded()
        let ch = (h * fy).rounded()
        let rect = CGRect(x: ((w - cw) / 2).rounded(), y: ((h - ch) / 2).rounded(), width: cw, height: ch)
        guard let cropped = image.cropping(to: rect) else { throw ComposeError.crop }

        let orientation = landscape ? imageOrientation(for: deviceOrientation) : .up
        let oriented = UIImage(cgImage: cropped, scale: 1, orientation: orientation)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: oriented.size, format: format)
        return renderer.jpegData(withCompressionQuality: 0.92) { _ in
            oriented.draw(in: CGRect(origin: .zero, size: oriented.size))
            if let caption { draw(caption: caption, in: oriented.size) }
        }
    }

    /// Back camera sensor is natively landscape with the home side on the right.
    private static func imageOrientation(for device: UIDeviceOrientation) -> UIImage.Orientation {
        switch device {
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right
        }
    }

    private static func draw(caption: String, in size: CGSize) {
        let side = min(size.width, size.height)
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.7)
        shadow.shadowBlurRadius = side * 0.008
        shadow.shadowOffset = .zero
        let text = NSAttributedString(string: caption, attributes: [
            .font: UIFont.monospacedDigitSystemFont(ofSize: side * 0.03, weight: .semibold),
            .foregroundColor: UIColor.white,
            .shadow: shadow,
        ])
        let pad = side * 0.03
        text.draw(at: CGPoint(x: pad, y: size.height - pad - text.size().height))
    }
}

enum PhotoSaver {
    enum SaveError: LocalizedError {
        case denied
        var errorDescription: String? { "Allow photo library access in Settings to save shots." }
    }

    static func save(jpeg: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.denied }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: jpeg, options: nil)
        }
    }
}
