import SwiftUI
import AVFoundation

@main
struct AutoKlinik3DCameraApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @StateObject private var scanner = MarkerScanner()
    @State private var target = 1
    @State private var language = "ru"

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.07, blue: 0.12).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("AUTOKLINIK 3D CAMERA")
                    .font(.title2.bold()).foregroundStyle(.white)
                Picker("Язык / Sprache", selection: $language) {
                    Text("Русский").tag("ru")
                    Text("Deutsch").tag("de")
                }
                .pickerStyle(.segmented)
                .onChange(of: language) { value in
                    scanner.setLanguage(value)
                }
                Text(language == "ru" ? "Наведите камеру на маркер №\(target)" : "Richten Sie die Kamera auf Marker Nr. \(target)")
                    .font(.headline).foregroundStyle(.cyan)
                CameraPreview(session: scanner.session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(alignment: .topLeading) {
                        Text(scanner.status).padding(12)
                            .background(.black.opacity(0.7))
                            .foregroundStyle(.white)
                    }
                HStack(spacing: 8) {
                    ForEach(1...4, id: \.self) { number in
                        Button("№\(number)") {
                            target = number
                            scanner.setTarget(number)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(number == target ? Color.cyan : Color.gray.opacity(0.35))
                        .foregroundStyle(number == target ? .black : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                Text((language == "ru" ? "Найдено: " : "Erkannt: ") + scanner.detected.sorted().map(String.init).joined(separator: ", "))
                    .foregroundStyle(.white)
                Button(language == "ru" ? "Начать сканирование" : "Scan starten") {
                    scanner.setTarget(target)
                    scanner.start()
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
            .padding()
        }
        .onAppear { scanner.requestAccessAndStart(target: target) }
        .onDisappear { scanner.stop() }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.layerSession.session = session
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) {}
}
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var layerSession: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override init(frame: CGRect) {
        super.init(frame: frame)
        layerSession.videoGravity = .resizeAspectFill
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class MarkerScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    @Published var status = "Ожидание разрешения камеры"
    @Published var detected: Set<Int> = []
    private let queue = DispatchQueue(label: "autoklinik.camera")
    private let voice = AVSpeechSynthesizer()
    private var target = 1
    private var language = "ru"
    private var configured = false
    private var announced: Set<Int> = []

    func requestAccessAndStart(target: Int) {
        self.target = target
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.configureAndStart() }
                    else { self.status = "Разрешите доступ к камере в настройках" }
                }
            }
        default: status = "Разрешите доступ к камере в настройках"
        }
    }
    func setLanguage(_ value: String) {
        language = value
        setTarget(target)
    }
    private func localized(_ russian: String, _ german: String) -> String {
        language == "de" ? german : russian
    }
    func setTarget(_ value: Int) {
        target = value
        speak(localized("Наведите камеру на маркер номер \(value)", "Richten Sie die Kamera auf Marker Nummer \(value)"))
    }
    func start() { requestAccessAndStart(target: target) }
    func stop() { queue.async { if self.session.isRunning { self.session.stopRunning() } } }
    private func configureAndStart() {
        queue.async {
            if !self.configured {
                guard let camera = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: camera),
                      self.session.canAddInput(input) else {
                    DispatchQueue.main.async { self.status = "Камера недоступна" }
                    return
                }
                self.session.beginConfiguration()
                self.session.addInput(input)
                let output = AVCaptureMetadataOutput()
                guard self.session.canAddOutput(output) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.status = "Сканер недоступен" }
                    return
                }
                self.session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.qr]
                self.session.commitConfiguration()
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async {
                self.status = self.localized("Ищем маркер №\(self.target)", "Suche Marker Nr. \(self.target)")
                self.setTarget(self.target)
            }
        }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        let ids = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .compactMap { $0.stringValue }
            .compactMap { raw -> Int? in
                guard raw.hasPrefix("AUTOKLINIK-3D:"),
                      let id = Int(raw.dropFirst("AUTOKLINIK-3D:".count)),
                      (1...4).contains(id) else { return nil }
                return id
            }
        for id in ids {
            detected.insert(id)
            status = localized("Обнаружен маркер №\(id)", "Marker Nr. \(id) erkannt")
            if id == target && !announced.contains(id) {
                announced.insert(id)
                speak(localized("Маркер номер \(id) найден", "Marker Nummer \(id) erkannt"))
                if id < 4 { target = id + 1; speak(localized("Наведите камеру на маркер номер \(target)", "Richten Sie die Kamera auf Marker Nummer \(target)")) }
                else { speak(localized("Все четыре маркера распознаны", "Alle vier Marker wurden erkannt")) }
            }
        }
    }
    private func speak(_ text: String) {
        voice.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language == "de" ? "de-DE" : "ru-RU")
        utterance.rate = 0.48
        voice.speak(utterance)
    }
}
