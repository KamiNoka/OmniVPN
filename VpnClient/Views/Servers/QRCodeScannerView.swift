import SwiftUI
import AVFoundation

public struct QRCodeScannerView: UIViewControllerRepresentable {
    public let onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(onScanned: @escaping (String) -> Void) {
        self.onScanned = onScanned
    }

    public func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    public func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let parent: QRCodeScannerView

        init(_ parent: QRCodeScannerView) {
            self.parent = parent
        }

        public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first,
               let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
               let stringValue = readableObject.stringValue {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                parent.onScanned(stringValue)
                parent.dismiss()
            }
        }
    }
}

public class ScannerViewController: UIViewController {
    var captureSession: AVCaptureSession?
    weak var delegate: AVCaptureMetadataOutputObjectsDelegate?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            showFailLabel()
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            showFailLabel()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            showFailLabel()
            return
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        self.captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func showFailLabel() {
        let label = UILabel()
        label.text = "Камера недоступна (симулятор или нет прав)"
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.frame = view.bounds
        view.addSubview(label)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
}
