import AVFoundation
import AppKit
import Combine

/// Manages a single camera's capture session and file recording.
final class CameraSession: NSObject, ObservableObject {

    // MARK: - Published state
    @Published var isRunning   = false
    @Published var isRecording = false
    @Published var error: String?
    @Published var deviceName  = "No camera"
    @Published var outputURL: URL?

    // MARK: - Private
    let index: Int
    let session          = AVCaptureSession()
    private var device:  AVCaptureDevice?
    private var assetWriter: AVAssetWriter?
    private var videoInput:  AVAssetWriterInput?
    private var audioInput:  AVAssetWriterInput?
    private var audioDeviceInput: AVCaptureDeviceInput?

    private let sessionQueue = DispatchQueue(label: "cam.session.\(UUID().uuidString)",
                                             qos: .userInteractive)

    // MARK: - Init
    init(index: Int) {
        self.index = index
        super.init()
    }

    // MARK: - Setup

    /// Assign a video device and configure the session.
    func configure(with device: AVCaptureDevice) {
        self.device = device
        DispatchQueue.main.async { self.deviceName = device.localizedName }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            // Remove existing inputs
            self.session.inputs.forEach { self.session.removeInput($0) }

            // Video
            do {
                let videoIn = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(videoIn) {
                    self.session.addInput(videoIn)
                }
            } catch {
                DispatchQueue.main.async { self.error = error.localizedDescription }
            }

            // Audio (default mic) — one mic, all cameras share their own track
            if let mic = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioIn = try AVCaptureDeviceInput(device: mic)
                    if self.session.canAddInput(audioIn) {
                        self.session.addInput(audioIn)
                        self.audioDeviceInput = audioIn
                    }
                } catch { /* no audio — not fatal */ }
            }

            // Video data output (for writing)
            let videoOut = AVCaptureVideoDataOutput()
            videoOut.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ]
            videoOut.setSampleBufferDelegate(self, queue: self.sessionQueue)
            videoOut.alwaysDiscardsLateVideoFrames = true
            if self.session.canAddOutput(videoOut) { self.session.addOutput(videoOut) }

            // Audio data output
            let audioOut = AVCaptureAudioDataOutput()
            audioOut.setSampleBufferDelegate(self, queue: self.sessionQueue)
            if self.session.canAddOutput(audioOut) { self.session.addOutput(audioOut) }

            self.session.commitConfiguration()
        }
    }

    // MARK: - Session lifecycle

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.isRecording { self.stopRecording() }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    // MARK: - Recording

    func startRecording(to directory: URL) {
        guard !isRecording else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "Camera\(index + 1)_\(timestamp).mov"
        let fileURL  = directory.appendingPathComponent(fileName)

        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mov)

                // Video settings
                guard let formatDesc = self.device?.activeFormat.formatDescription else { return }
                let dims = CMVideoFormatDescriptionGetDimensions(formatDesc)
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey:             AVVideoCodecType.h264,
                    AVVideoWidthKey:             dims.width,
                    AVVideoHeightKey:            dims.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 8_000_000,
                        AVVideoProfileLevelKey:  AVVideoProfileLevelH264HighAutoLevel
                    ]
                ]
                let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                vInput.expectsMediaDataInRealTime = true
                if writer.canAdd(vInput) { writer.add(vInput) }

                // Audio settings
                let audioSettings: [String: Any] = [
                    AVFormatIDKey:         kAudioFormatMPEG4AAC,
                    AVSampleRateKey:       44100,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey:   128_000
                ]
                let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                aInput.expectsMediaDataInRealTime = true
                if writer.canAdd(aInput) { writer.add(aInput) }

                self.assetWriter  = writer
                self.videoInput   = vInput
                self.audioInput   = aInput

                DispatchQueue.main.async {
                    self.outputURL   = fileURL
                    self.isRecording = true
                }
            } catch {
                DispatchQueue.main.async { self.error = error.localizedDescription }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        sessionQueue.async { [weak self] in
            guard let self, let writer = self.assetWriter else { return }
            self.videoInput?.markAsFinished()
            self.audioInput?.markAsFinished()
            writer.finishWriting {
                DispatchQueue.main.async { self.isRecording = false }
            }
            self.assetWriter = nil
            self.videoInput  = nil
            self.audioInput  = nil
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate,
                         AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard isRecording,
              let writer = assetWriter else { return }

        let isVideo = output is AVCaptureVideoDataOutput

        // Start writing on first video sample
        if writer.status == .unknown && isVideo {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startWriting()
            writer.startSession(atSourceTime: pts)
        }

        guard writer.status == .writing else { return }

        if isVideo, videoInput?.isReadyForMoreMediaData == true {
            videoInput?.append(sampleBuffer)
        } else if !isVideo, audioInput?.isReadyForMoreMediaData == true {
            audioInput?.append(sampleBuffer)
        }
    }
}
