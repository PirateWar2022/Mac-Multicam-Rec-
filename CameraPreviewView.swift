import SwiftUI
import AVFoundation
import AppKit

/// Wraps AVCaptureVideoPreviewLayer for SwiftUI.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.session = session
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        nsView.session = session
    }
}

final class PreviewNSView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    var session: AVCaptureSession? {
        didSet {
            guard session !== oldValue else { return }
            previewLayer?.removeFromSuperlayer()
            previewLayer = nil

            if let session {
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                layer.frame = bounds
                wantsLayer = true
                self.layer?.addSublayer(layer)
                previewLayer = layer
            }
        }
    }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}
