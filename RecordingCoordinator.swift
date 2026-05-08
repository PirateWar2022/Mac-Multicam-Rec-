import AVFoundation
import Combine
import AppKit

/// Coordinates up to 5 simultaneous camera sessions.
final class RecordingCoordinator: ObservableObject {

    static let cameraCount = 5

    // MARK: - Published
    @Published var cameras: [CameraSession]
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var outputDirectory: URL
    @Published var lastSessionFiles: [URL] = []

    // MARK: - Private
    private var durationTimer: AnyCancellable?
    private var recordingStart: Date?

    // MARK: - Init
    init() {
        cameras = (0..<Self.cameraCount).map { CameraSession(index: $0) }

        // Default to Movies/MultiCamRecorder
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        outputDirectory = movies.appendingPathComponent("MultiCamRecorder", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDirectory,
                                                  withIntermediateDirectories: true)

        refreshDevices()
        autoAssignCameras()
        requestPermissions()
    }

    // MARK: - Device discovery

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        DispatchQueue.main.async {
            self.availableDevices = discovery.devices
        }
    }

    func autoAssignCameras() {
        refreshDevices()
        for (i, cam) in cameras.enumerated() {
            if i < availableDevices.count {
                cam.configure(with: availableDevices[i])
                cam.start()
            }
        }
    }

    func assign(device: AVCaptureDevice, to index: Int) {
        guard index < cameras.count else { return }
        cameras[index].stop()
        cameras[index].configure(with: device)
        cameras[index].start()
    }

    // MARK: - Permissions

    func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    // MARK: - Recording control

    func startAllRecordings() {
        guard !isRecording else { return }
        lastSessionFiles = []
        let dir = outputDirectory

        // Staggered-start is acceptable; all writers sync to first sample PTS
        cameras.forEach { $0.startRecording(to: dir) }

        isRecording     = true
        recordingStart  = Date()
        recordingDuration = 0

        durationTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.recordingStart else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
    }

    func stopAllRecordings() {
        guard isRecording else { return }
        cameras.forEach { $0.stopRecording() }
        durationTimer?.cancel()
        isRecording = false

        // Collect output URLs after a brief delay (writers finish async)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.lastSessionFiles = self.cameras.compactMap { $0.outputURL }
        }
    }

    // MARK: - Output directory

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles      = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select Output Folder"
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
        }
    }

    func revealOutputDirectory() {
        NSWorkspace.shared.open(outputDirectory)
    }

    // MARK: - Helpers

    var formattedDuration: String {
        let total = Int(recordingDuration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
