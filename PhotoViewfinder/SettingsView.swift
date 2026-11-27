import SwiftUI

struct SettingsView: View {
    @Binding var calibration: Double
    @Binding var showGrid: Bool
    @Binding var burnInCaption: Bool
    let info: CameraInfo?
    let zoom: Double

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Overlay") {
                    Toggle("Rule-of-thirds grid", isOn: $showGrid)
                    Toggle("Caption on saved photos", isOn: $burnInCaption)
                }

                Section {
                    HStack {
                        Text("Correction")
                        Spacer()
                        Text(String(format: "%+.1f%%", (calibration - 1) * 100))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $calibration, in: 0.9...1.1, step: 0.005)
                    Button("Reset") { calibration = 1 }
                        .disabled(calibration == 1)
                } header: {
                    Text("Field-of-view calibration")
                } footer: {
                    Text("The frame uses the field of view iOS reports for the camera. If it looks tighter than the same lens on a real camera, increase the correction; if it looks looser, decrease it. To check: frame the same scene with a real 50mm lens and line up the edges.")
                }

                if let info {
                    Section("Phone camera") {
                        LabeledContent("Device", value: info.deviceName)
                        LabeledContent("Widest view", value: String(format: "≈ %.0f mm FF", info.fullFrameEquivalent(zoom: info.minZoom, calibration: calibration)))
                        LabeledContent("Current view", value: String(format: "≈ %.0f mm FF", info.fullFrameEquivalent(zoom: zoom, calibration: calibration)))
                        LabeledContent("Zoom", value: String(format: "%.2f× (%.0f–%.0f×)", zoom, info.minZoom, info.maxZoom))
                        LabeledContent("Reported FOV", value: String(format: "%.1f°", info.longFOVDegrees))
                        LabeledContent("Sensor aspect", value: String(format: "%.3f", info.sensorAspect))
                        if !info.switchOverZooms.isEmpty {
                            LabeledContent("Lens switch at", value: info.switchOverZooms.map { String(format: "%.1f×", $0) }.joined(separator: ", "))
                        }
                    }
                }

                Section("Gestures") {
                    Label("Pinch the viewfinder to change focal length", systemImage: "hand.pinch")
                    Label("Double-tap to switch between surroundings and fill", systemImage: "hand.tap")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
