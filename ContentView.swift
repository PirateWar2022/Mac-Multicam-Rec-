import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = RecordingCoordinator()

    // 3 top + 2 bottom grid layout
    private let topRange    = 0..<3
    private let bottomRange = 3..<5

    var body: some View {
        ZStack {
            Color(white: 0.06).ignoresSafeArea()

            VStack(spacing: 0) {
                titleBar
                cameraGrid
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                controlBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { coordinator.refreshDevices() }
    }

    // MARK: - Title bar

    private var titleBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "video.3")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text("MultiCam Recorder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            if coordinator.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(coordinator.formattedDuration)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()

            HStack(spacing: 4) {
                // Refresh cameras
                Button {
                    coordinator.refreshDevices()
                    coordinator.autoAssignCameras()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Refresh cameras")

                // Output folder
                Button {
                    coordinator.chooseOutputDirectory()
                } label: {
                    Image(systemName: "folder")
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Choose output folder")

                // Reveal in Finder
                Button {
                    coordinator.revealOutputDirectory()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
            .font(.system(size: 14))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.09))
    }

    // MARK: - Camera grid

    private var cameraGrid: some View {
        VStack(spacing: 8) {
            // Top row: 3 cameras
            HStack(spacing: 8) {
                ForEach(topRange, id: \.self) { i in
                    CameraTileView(
                        camera: coordinator.cameras[i],
                        availableDevices: coordinator.availableDevices
                    ) { device in
                        coordinator.assign(device: device, to: i)
                    }
                    .aspectRatio(16/9, contentMode: .fit)
                }
            }

            // Bottom row: 2 cameras (centered)
            HStack(spacing: 8) {
                Spacer()
                ForEach(bottomRange, id: \.self) { i in
                    CameraTileView(
                        camera: coordinator.cameras[i],
                        availableDevices: coordinator.availableDevices
                    ) { device in
                        coordinator.assign(device: device, to: i)
                    }
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 20) {
            // Output path
            HStack(spacing: 6) {
                Image(systemName: "internaldrive")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.system(size: 11))
                Text(coordinator.outputDirectory.path)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Camera count
            Label("\(coordinator.availableDevices.count) cameras",
                  systemImage: "camera")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))

            // Record / Stop button
            Button {
                if coordinator.isRecording {
                    coordinator.stopAllRecordings()
                } else {
                    coordinator.startAllRecordings()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: coordinator.isRecording ? "stop.fill" : "record.circle")
                    Text(coordinator.isRecording ? "Stop all" : "Record all")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(coordinator.isRecording ? Color.red : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.09))
    }
}

#Preview {
    ContentView()
        .frame(width: 1200, height: 720)
}
