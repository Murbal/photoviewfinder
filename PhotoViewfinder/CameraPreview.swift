import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.applyPortraitRotation()
    }
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    private var observer: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // The preview connection only exists once the session is configured.
        observer = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.didStartRunningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.applyPortraitRotation()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyPortraitRotation()
    }

    /// The UI is locked to portrait, so the back camera's preview is always rotated 90°.
    func applyPortraitRotation() {
        guard let connection = previewLayer.connection,
              connection.isVideoRotationAngleSupported(90),
              connection.videoRotationAngle != 90
        else { return }
        connection.videoRotationAngle = 90
    }
}
