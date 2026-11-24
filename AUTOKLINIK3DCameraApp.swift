import SwiftUI
import AVFoundation
import Vision

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
                Text(language == "ru" ? "Схема теста: 4 опорные мишени + 4 колеса" : "Testansicht: 4 Referenzmarken + 4 Räder")
                    .font(.subheadline.bold()).foregroundStyle(.white)
                HStack(spacing: 12) {
                    VStack(spacing: 8) {
                        Text("ОПОРЫ 1–4").font(.caption).foregroundStyle(.white)
                        HStack { targetTile(1); targetTile(2) }
                        HStack { targetTile(3); targetTile(4) }
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        Text("КОЛЁСА 5–8").font(.caption).foregroundStyle(.white)
                        HStack { targetTile(5); targetTile(6) }
                        HStack { targetTile(7); targetTile(8) }
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(1...8, id: \.self) { number in
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
                Text(language == "ru" ? "1–4: опорные мишени; 5–8: колёса" : "1–4: Referenzmarken; 5–8: Räder")
                    .font(.caption).foregroundStyle(.white)
                Text(language == "ru" ? "Кандидатов-квадратов: \\(scanner.candidateCount) (не подтверждённые мишени)" : "Quadratische Kandidaten: \\(scanner.candidateCount) (keine bestätigten Marker)")
                    .foregroundStyle(.white)
                Text(language == "ru" ? "Тест контуров камеры. ChArUco ID пока не распознаются. Измерения не реализованы." : "Kamera-Konturtest. ChArUco-IDs noch nicht erkannt. Keine Messung.")
                    .font(.caption).foregroundStyle(.orange)
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
    private func targetTile(_ id: Int) -> some View {
        Text("\(id)")
            .font(.headline.bold())
            .frame(width: 48, height: 36)
            .background(scanner.detected.contains(id) ? Color.green : Color.gray.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 7))
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

final class MarkerScanner: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published var status = "Ожидание разрешения камеры"
    @Published var detected: Set<Int> = []
    @Published var candidateCount = 0
    private let queue = DispatchQueue(label: "autoklinik.camera")
    private let voice = AVSpeechSynthesizer()
    private var target = 1
    private var language = "ru"
    private var configured = false
    private var lastFrameTime: CFTimeInterval = 0

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
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                guard self.session.canAddOutput(output) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.status = "Сканер недоступен" }
                    return
                }
                self.session.addOutput(output)
                output.setSampleBufferDelegate(self, queue: self.queue)
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
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Preliminary visual candidate detection. This does NOT decode ArUco IDs.
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= 0.4 else { return }
        lastFrameTime = now
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 12
        request.minimumConfidence = 0.65
        request.minimumAspectRatio = 0.75
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.035
        do {
            try VNImageRequestHandler(cvPixelBuffer: buffer, options: [:]).perform([request])
            let count = request.results?.count ?? 0
            DispatchQueue.main.async {
                self.candidateCount = count
                self.status = self.localized("Квадратных контуров: \\(count). ID пока не определены",
                                             "Quadratische Konturen: \\(count). IDs noch unbekannt")
            }
        } catch {
            DispatchQueue.main.async {
                self.status = self.localized("Ошибка анализа кадра", "Bildanalyse fehlgeschlagen")
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
