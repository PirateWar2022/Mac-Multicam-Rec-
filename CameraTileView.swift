import SwiftUI
import AVFoundation

struct CameraTileView: View {
    @ObservedObject var camera: CameraSession
    let availableDevices: [AVCaptureDevice]
    let onAssign: (AVCaptureDevice) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Preview
            if camera.isRunning {
                CameraPreviewView(session: camera.session)
            } else {
                offlineView
            }

            // Overlay bar
            overlayBar
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: camera.isRecording ? 2.5 : 1)
        )
        .background(Color.black)
    }

    // MARK: - Sub-views

    private var offlineView: some View {
        ZStack {
            Color(white: 0.08)
            VStack(spacing: 8) {
                Image(systemName: "video.slash")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.3))
                Text("No signal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }

    private var overlayBar: some View {
        HStack(spacing: 6) {
            // Camera index badge
            Text("CAM \(camera.index + 1)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(badgeColor)
                .clipShape(Capsule())

            // Device name (truncated)
            Text(camera.deviceName)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // REC indicator
            if camera.isRecording {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle().stroke(Color.red.opacity(0.4), lineWidth: 3)
                        )
                    Text("REC")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                }
            }

            // Device picker menu
            Menu {
                ForEach(availableDevices, id: \.uniqueID) { device in
                    Button(device.localizedName) {
                        onAssign(device)
                    }
                }
                if availableDevices.isEmpty {
                    Text("No cameras found").foregroundColor(.secondary)
                }
            } label: {
                Image(systemName: "camera.badge.ellipsis")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - Helpers

    private var borderColor: Color {
        if let err = camera.error, !err.isEmpty { return .red.opacity(0.7) }
        if camera.isRecording { return .red }
        if camera.isRunning   { return .white.opacity(0.15) }
        return .white.opacity(0.07)
    }

    private var badgeColor: Color {
        if camera.isRecording { return .red }
        if camera.isRunning   { return .white.opacity(0.2) }
        return .white.opacity(0.1)
    }
}
