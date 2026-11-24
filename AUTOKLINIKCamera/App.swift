import SwiftUI
import AVFoundation

@main
struct AUTOKLINIKCameraApp: App {
    var body: some Scene {
        WindowGroup { ScannerView() }
    }
}

final class ScannerModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var found: Set<String> = []
    @Published var permissionDenied = false
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera.session.queue")
    private let ids = Set((1...8).map { "AUTOKLINIK-3D-\($0)" })

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if !granted {
                DispatchQueue.main.async { self.permissionDenied = true }
                return
            }
            self.queue.async {
                if self.session.inputs.isEmpty {
                    guard let camera = AVCaptureDevice.default(for: .video),
                          let input = try? AVCaptureDeviceInput(device: camera),
                          self.session.canAddInput(input) else { return }
                    self.session.addInput(input)
                    let output = AVCaptureMetadataOutput()
                    guard self.session.canAddOutput(output) else { return }
                    self.session.addOutput(output)
                    output.metadataObjectTypes = [.qr]
                    output.setMetadataObjectsDelegate(self, queue: .main)
                }
                if !self.session.isRunning { self.session.startRunning() }
            }
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    func reset() { found.removeAll() }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        for item in metadataObjects {
            guard let qr = item as? AVMetadataMachineReadableCodeObject,
                  let value = qr.stringValue, ids.contains(value) else { continue }
            found.insert(value)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> Preview {
        let view = Preview()
        view.layerVideo.videoGravity = .resizeAspectFill
        view.layerVideo.session = session
        return view
    }
    func updateUIView(_ uiView: Preview, context: Context) {}
    final class Preview: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var layerVideo: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

struct ScannerView: View {
    @StateObject private var model = ScannerModel()
    var body: some View {
        VStack(spacing: 12) {
            Text("AUTOKLINIK 3D CAMERA").font(.headline)
            Text("Тест распознавания 8 QR-маркеров")
            CameraPreview(session: model.session)
                .frame(maxHeight: .infinity).clipShape(RoundedRectangle(cornerRadius: 14))
            Text("Найдено: \(model.found.count) из 8").font(.title2).bold()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                ForEach(1...8, id: \.self) { n in
                    let detected = model.found.contains("AUTOKLINIK-3D-\(n)")
                    Text("\(n) \(detected ? "✓" : "○")")
                        .padding(8).frame(maxWidth: .infinity)
                        .background(detected ? Color.green.opacity(0.3) : Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            Button("Сбросить результаты") { model.reset() }
                .buttonStyle(.borderedProminent)
            if model.permissionDenied { Text("Разреши доступ к камере в настройках iPhone.") }
            Text("Это тест QR, не измеритель развала-схождения.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
