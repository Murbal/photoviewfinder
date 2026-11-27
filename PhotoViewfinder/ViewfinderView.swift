import SwiftUI

struct ViewfinderView: View {
    @StateObject private var camera = CameraController()
    @StateObject private var motion = OrientationMonitor()
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("formatID") private var formatID = FilmFormat.fullFrame.id
    @AppStorage("focalLength") private var focalLength = 35.0
    @AppStorage("showSurroundings") private var showSurroundings = true
    @AppStorage("rotateFrame") private var rotateFrame = false
    @AppStorage("showGrid") private var showGrid = false
    @AppStorage("burnInCaption") private var burnInCaption = true
    @AppStorage("fovCalibration") private var calibration = 1.0

    @State private var pinchStartFocal: Double?
    @State private var showSettings = false
    @State private var toast: String?
    @State private var flash = false
    @State private var isSaving = false
    @State private var shotCount = 0

    private var format: FilmFormat { FilmFormat.byID(formatID) }

    /// How much of the viewfinder the frame occupies along its limiting side.
    private var fillFraction: Double { showSurroundings ? 0.78 : 1.0 }

    private func math(_ info: CameraInfo) -> ViewfinderMath {
        ViewfinderMath(camera: info, calibration: calibration, format: format, focal: focalLength, rotated: rotateFrame)
    }

    var body: some View {
        VStack(spacing: 0) {
            viewfinder
            controls
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            camera.start()
            motion.start()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                camera.start()
                motion.start()
            case .background:
                camera.stop()
                motion.stop()
            default:
                break
            }
        }
        .onChange(of: formatID) { oldID, newID in
            // Keep the same angle of view when switching formats.
            let old = FilmFormat.byID(oldID)
            let new = FilmFormat.byID(newID)
            focalLength = new.rounded(focalLength * new.diagonal / old.diagonal)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                calibration: $calibration, showGrid: $showGrid, burnInCaption: $burnInCaption,
                info: camera.info, zoom: camera.zoomFactor)
        }
    }

    // MARK: - Viewfinder

    private var viewfinder: some View {
        GeometryReader { geo in
            ZStack {
                CameraPreview(session: camera.session)

                if let info = camera.info {
                    let m = math(info)
                    let rect = m.frameRect(zoom: camera.zoomFactor, in: geo.size)

                    FrameOverlay(rect: rect, maskOpacity: showSurroundings ? 0.6 : 0.95, showGrid: showGrid)

                    frameLabel
                        .rotationEffect(motion.rotation)
                        .position(labelPosition(for: rect, in: geo.size))

                    if m.isWiderThanCamera {
                        Text("Wider than the phone can see")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.red.opacity(0.85), in: Capsule())
                            .rotationEffect(motion.rotation)
                    }

                    Color.clear
                        .allowsHitTesting(false)
                        .onChange(of: m.desiredZoom(in: geo.size, fill: fillFraction), initial: true) { _, zoom in
                            camera.setZoom(zoom)
                        }
                } else {
                    statusView
                }

                Color.white
                    .opacity(flash ? 0.7 : 0)
                    .allowsHitTesting(false)

                if let toast {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 16)
                    }
                    .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .gesture(pinchGesture)
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.2)) { showSurroundings.toggle() }
            }
        }
        .clipped()
    }

    private var frameLabel: some View {
        HStack(spacing: 6) {
            Text("\(FocalText.string(focalLength))mm \(format.shortName)")
                .fontWeight(.semibold)
            if format.id != FilmFormat.fullFrame.id {
                Text("≈\(Int(format.fullFrameEquivalent(focalLength).rounded()))mm FF")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.black.opacity(0.55), in: Capsule())
        .fixedSize()
    }

    /// Puts the label just outside the frame edge that is "up" for the viewer.
    private func labelPosition(for rect: CGRect, in size: CGSize) -> CGPoint {
        let gap: CGFloat = 18
        func cx(_ x: CGFloat) -> CGFloat { min(max(x, gap), size.width - gap) }
        func cy(_ y: CGFloat) -> CGFloat { min(max(y, gap), size.height - gap) }
        switch motion.orientation {
        case .landscapeLeft: return CGPoint(x: cx(rect.maxX + gap), y: size.height / 2)
        case .landscapeRight: return CGPoint(x: cx(rect.minX - gap), y: size.height / 2)
        case .portraitUpsideDown: return CGPoint(x: size.width / 2, y: cy(rect.maxY + gap))
        default: return CGPoint(x: size.width / 2, y: cy(rect.minY - gap))
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch camera.state {
        case .unauthorized:
            VStack(spacing: 12) {
                Text("Camera access is needed to show the viewfinder.")
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        case .unavailable:
            Text("No usable back camera found.")
        default:
            ProgressView()
        }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStartFocal ?? focalLength
                if pinchStartFocal == nil { pinchStartFocal = start }
                focalLength = format.rounded(start * Double(value.magnification))
            }
            .onEnded { _ in pinchStartFocal = nil }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(FocalText.string(focalLength))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("mm")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(equivalentText)
                    Text(angleText)
                }
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Slider(value: sliderBinding, in: 0...1)
                .tint(.orange)

            presetChips

            bottomRow
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(Color.black)
    }

    private var equivalentText: String {
        if format.id == FilmFormat.fullFrame.id { return format.name }
        return String(
            format: "≈ %@mm FF · crop ×%.2f",
            FocalText.string(format.fullFrameEquivalent(focalLength).rounded()), format.cropFactor)
    }

    private var angleText: String {
        let a = format.angleOfView(focalLength)
        return String(format: "H %.1f°  V %.1f°  D %.1f°", a.horizontal, a.vertical, a.diagonal)
    }

    /// Logarithmic slider so wide and long focal lengths get equal travel.
    private var sliderBinding: Binding<Double> {
        let format = self.format
        let range = format.focalRange
        let ratio = range.upperBound / range.lowerBound
        return Binding(
            get: {
                let f = min(max(focalLength, range.lowerBound), range.upperBound)
                return log(f / range.lowerBound) / log(ratio)
            },
            set: { t in
                focalLength = format.rounded(range.lowerBound * pow(ratio, t))
            })
    }

    private var presetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(format.presets, id: \.self) { preset in
                    let selected = abs(preset - focalLength) < 0.01
                    Button {
                        focalLength = preset
                    } label: {
                        Text(FocalText.string(preset))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selected ? Color.orange : Color.white.opacity(0.12), in: Capsule())
                            .foregroundStyle(selected ? Color.black : Color.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bottomRow: some View {
        HStack {
            Menu {
                Picker("Format", selection: $formatID) {
                    ForEach(FilmFormat.all) { format in
                        Text(format.name).tag(format.id)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(format.shortName)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.12), in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            shutterButton

            HStack(spacing: 10) {
                iconButton(showSurroundings ? "eye" : "eye.slash", active: showSurroundings) {
                    withAnimation(.easeInOut(duration: 0.2)) { showSurroundings.toggle() }
                }
                iconButton("rotate.right", active: rotateFrame) {
                    rotateFrame.toggle()
                }
                iconButton("gearshape", active: false) {
                    showSettings = true
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func iconButton(_ symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(active ? Color.orange.opacity(0.9) : Color.white.opacity(0.12), in: Circle())
                .foregroundStyle(active ? Color.black : Color.white)
                .rotationEffect(motion.rotation)
        }
        .buttonStyle(.plain)
    }

    private var shutterButton: some View {
        Button(action: shoot) {
            ZStack {
                Circle().stroke(Color.white, lineWidth: 3).frame(width: 64, height: 64)
                Circle().fill(isSaving ? Color.gray : Color.white).frame(width: 52, height: 52)
            }
        }
        .buttonStyle(.plain)
        .disabled(camera.info == nil || isSaving)
        .sensoryFeedback(.impact(weight: .medium), trigger: shotCount)
    }

    // MARK: - Capture

    private var captionText: String {
        var parts = ["\(FocalText.string(focalLength))mm", format.name]
        if format.id != FilmFormat.fullFrame.id {
            parts.append("≈\(Int(format.fullFrameEquivalent(focalLength).rounded()))mm FF")
        }
        return parts.joined(separator: " · ")
    }

    private func shoot() {
        guard let info = camera.info, !isSaving else { return }
        let fractions = math(info).sensorFractions(zoom: camera.zoomFactor)
        let caption = burnInCaption ? captionText : nil
        let orientation = motion.orientation

        isSaving = true
        shotCount += 1
        withAnimation(.easeOut(duration: 0.05)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeIn(duration: 0.3)) { flash = false }
        }

        camera.capturePhoto { result in
            Task { @MainActor in
                do {
                    let image = try result.get()
                    let jpeg = try await Task.detached(priority: .userInitiated) {
                        try PhotoComposer.compose(
                            image, longFraction: fractions.long, shortFraction: fractions.short,
                            deviceOrientation: orientation, caption: caption)
                    }.value
                    try await PhotoSaver.save(jpeg: jpeg)
                    showToast("Saved to Photos")
                } catch {
                    showToast(error.localizedDescription)
                }
                isSaving = false
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if toast == text { withAnimation { toast = nil } }
        }
    }
}
