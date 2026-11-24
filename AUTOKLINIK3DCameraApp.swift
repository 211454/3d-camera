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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        Text("AUTOKLINIK 3D CAMERA")
                            .font(.headline.bold()).foregroundStyle(.white)
                        Picker("Язык / Sprache", selection: $language) {
                            Text("Русский").tag("ru")
                            Text("Deutsch").tag("de")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: language) { scanner.setLanguage($0) }

                        CameraPreview(session: scanner.session)
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(alignment: .topLeading) {
                                Text(scanner.status)
                                    .font(.caption)
                                    .lineLimit(3)
                                    .padding(8)
                                    .background(.black.opacity(0.75))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(8)
                            }

                        Text(language == "ru" ? "ДВЕ СТОЙКИ · 4 ОПОРНЫЕ МИШЕНИ" : "ZWEI SÄULEN · 4 REFERENZMARKEN")
                            .font(.caption.bold()).foregroundStyle(.white)
                        HStack(spacing: 10) {
                            postCard(title: language == "ru" ? "Стойка 1" : "Säule 1", ids: [1, 2])
                            postCard(title: language == "ru" ? "Стойка 2" : "Säule 2", ids: [3, 4])
                        }
                        Text(language == "ru" ? "ЧЕТЫРЕ КОЛЕСА" : "VIER RÄDER")
                            .font(.caption.bold()).foregroundStyle(.white)
                        VStack(spacing: 8) {
                            Text(language == "ru" ? "ПЕРЕД АВТОМОБИЛЯ ↑" : "FAHRZEUGFRONT ↑").font(.caption2).foregroundStyle(.cyan)
                            HStack(spacing: 8) {
                                wheelCard(5, title: language == "ru" ? "Переднее левое" : "Vorne links")
                                wheelCard(6, title: language == "ru" ? "Переднее правое" : "Vorne rechts")
                            }
                            HStack(spacing: 8) {
                                wheelCard(7, title: language == "ru" ? "Заднее левое" : "Hinten links")
                                wheelCard(8, title: language == "ru" ? "Заднее правое" : "Hinten rechts")
                            }
                        }
                        Text(language == "ru" ? "Сохранено мишеней: \(scanner.detected.count) из 8" : "Gespeicherte Tafeln: \(scanner.detected.count) von 8")
                            .font(.caption).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(scanner.detected.isSuperset(of: Set(1...4)) ? (language == "ru" ? "4 опоры найдены. Геометрическая калибровка ещё не выполнена — измерения заблокированы." : "4 Referenzen erkannt. Geometrische Kalibrierung fehlt — Messung gesperrt.") : (language == "ru" ? "Сначала найдите четыре опорные мишени на стойках" : "Zuerst vier Referenztafeln erfassen"))
                            .font(.caption).foregroundStyle(.yellow)
                        Text(language == "ru" ? "Тест камеры, не измерение развала-схождения" : "Kameratest, keine Achsvermessung")
                            .font(.caption2).foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(14)
                }
                Button(language == "ru" ? "Начать сканирование" : "Scan starten") {
                    scanner.setTarget(target)
                    scanner.start()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.cyan)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(red: 0.04, green: 0.07, blue: 0.12))
            }
        }
        .onAppear { scanner.requestAccessAndStart(target: target) }
        .onDisappear { scanner.stop() }
    }

    private func postCard(title: String, ids: [Int]) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.subheadline.bold()).foregroundStyle(.white)
            HStack(spacing: 8) {
                ForEach(ids, id: \.self) { id in markerTile(id) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func wheelCard(_ id: Int, title: String) -> some View {
        HStack(spacing: 6) {
            markerTile(id)
            Text(title).font(.caption2).foregroundStyle(.white)
                .lineLimit(2).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(7)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func markerTile(_ id: Int) -> some View {
        Text("\(id)")
            .font(.subheadline.bold())
            .frame(width: 32, height: 32)
            .background(scanner.detected.contains(id) ? Color.green : Color.gray.opacity(0.55))
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
    @Published var visible: Set<Int> = []
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
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
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
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= 0.25 else { return }
        lastFrameTime = now
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ids = ArucoBridge.markerIDs(in: buffer).map { $0.intValue }
        let boards = Set(ids.compactMap { MarkerBoardConfiguration.boardNumber(forArUcoID: $0) })
        DispatchQueue.main.async {
            self.visible = boards
            self.detected.formUnion(boards)
            self.candidateCount = ids.count
            self.status = self.localized("В кадре ArUco: \(ids.count), мишеней: \(boards.count); сохранено: \(self.detected.count)",
                                         "ArUco sichtbar: \(ids.count), Tafeln: \(boards.count); gespeichert: \(self.detected.count)")
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
