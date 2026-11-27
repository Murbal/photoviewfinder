import AVFoundation
import UIKit

/// Owns the capture session. All AVFoundation work happens on `queue`;
/// published properties are only mutated on the main thread.
final class CameraController: NSObject, ObservableObject {
    enum State: Equatable {
        case idle, unauthorized, unavailable, running
    }

    enum CaptureError: LocalizedError {
        case notReady, noImage
        var errorDescription: String? {
            switch self {
            case .notReady: return "Camera isn't ready."
            case .noImage: return "Couldn't read the captured photo."
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var info: CameraInfo?
    @Published private(set) var zoomFactor: Double = 1

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "PhotoViewfinder.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var configured = false
    private var inFlight: [Int64: PhotoCaptureDelegate] = [:]

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            queue.async {
                self.configureIfNeeded()
                guard self.configured else { return }
                if !self.session.isRunning { self.session.startRunning() }
                self.publish(state: .running)
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.start() } else { self.publish(state: .unauthorized) }
            }
        default:
            publish(state: .unauthorized)
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func setZoom(_ zoom: Double) {
        queue.async {
            guard let device = self.device else { return }
            let lo = Double(device.minAvailableVideoZoomFactor)
            let hi = Double(device.maxAvailableVideoZoomFactor)
            let clamped = min(max(zoom, lo), hi)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = CGFloat(clamped)
                device.unlockForConfiguration()
            } catch {
                return
            }
            let actual = Double(device.videoZoomFactor)
            DispatchQueue.main.async { self.zoomFactor = actual }
        }
    }

    /// Captures a full-sensor photo. The returned CGImage is in the sensor's native
    /// (landscape) orientation; the caller crops and orients it.
    func capturePhoto(completion: @escaping (Result<CGImage, Error>) -> Void) {
        queue.async {
            guard self.device != nil, self.session.isRunning else {
                DispatchQueue.main.async { completion(.failure(CaptureError.notReady)) }
                return
            }
            if let connection = self.photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(0) {
                connection.videoRotationAngle = 0
            }
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .balanced
            let id = settings.uniqueID
            let delegate = PhotoCaptureDelegate { [weak self] result in
                self?.queue.async { self?.inFlight[id] = nil }
                DispatchQueue.main.async { completion(result) }
            }
            self.inFlight[id] = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    // MARK: - Private

    private func publish(state: State) {
        DispatchQueue.main.async { self.state = state }
    }

    private func configureIfNeeded() {
        guard !configured else { return }

        // Prefer virtual multi-lens devices: zoom factor 1 is the widest lens and iOS
        // switches to the wide/tele lenses automatically as we zoom in.
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera,
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: .video, position: .back)
        let candidate = types.lazy.compactMap { type in
            discovery.devices.first { $0.deviceType == type }
        }.first

        guard let device = candidate, let input = try? AVCaptureDeviceInput(device: device) else {
            publish(state: .unavailable)
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo  // full 4:3 sensor, same FOV as the photo output
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            publish(state: .unavailable)
            return
        }
        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .balanced
        session.commitConfiguration()

        self.device = device
        configured = true

        let format = device.activeFormat
        var fov = Double(format.videoFieldOfView)
        if device.isGeometricDistortionCorrectionSupported, device.isGeometricDistortionCorrectionEnabled {
            let corrected = Double(format.geometricDistortionCorrectedVideoFieldOfView)
            if corrected > 0 { fov = corrected }
        }
        let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let long = Double(max(dims.width, dims.height))
        let short = Double(max(1, min(dims.width, dims.height)))

        let info = CameraInfo(
            deviceName: device.localizedName,
            tanHalfLong: tan(fov / 2 * .pi / 180),
            sensorAspect: long / short,
            minZoom: Double(device.minAvailableVideoZoomFactor),
            maxZoom: Double(device.maxAvailableVideoZoomFactor),
            switchOverZooms: device.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue))
        let zoom = Double(device.videoZoomFactor)
        DispatchQueue.main.async {
            self.info = info
            self.zoomFactor = zoom
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<CGImage, Error>) -> Void
    private var finished = false

    init(completion: @escaping (Result<CGImage, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            finish(.failure(error))
        } else if let image = photo.cgImageRepresentation() {
            finish(.success(image))
        } else {
            finish(.failure(CameraController.CaptureError.noImage))
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        finish(.failure(error ?? CameraController.CaptureError.noImage))
    }

    private func finish(_ result: Result<CGImage, Error>) {
        guard !finished else { return }
        finished = true
        completion(result)
    }
}
