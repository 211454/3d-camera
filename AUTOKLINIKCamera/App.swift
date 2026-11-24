import SwiftUI
import AVFoundation

@main
struct AUTOKLINIKCameraApp: App {
    var body: some Scene { WindowGroup { ScannerView() } }
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
    @State private var showCalibration = false
    private let markerLabels = ["Левая стойка · верх", "Левая стойка · низ", "Правая стойка · верх", "Правая стойка · низ", "Переднее левое", "Переднее правое", "Заднее левое", "Заднее правое"]

    var body: some View {
        VStack(spacing: 12) {
            Text("AUTOKLINIK 3D CAMERA").font(.headline)
            Text("Шаг 1 — 2 стойки и 4 колеса")
            CameraPreview(session: model.session)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Text("Найдено: \(model.found.count) из 8").font(.title2).bold()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                ForEach(1...8, id: \.self) { n in
                    let detected = model.found.contains("AUTOKLINIK-3D-\(n)")
                    VStack(spacing: 2) {
                        Text("\(n) \(detected ? "✓" : "○")").bold()
                        Text(markerLabels[n - 1]).font(.system(size: 9)).multilineTextAlignment(.center)
                    }
                        .padding(8).frame(maxWidth: .infinity)
                        .background(detected ? Color.green.opacity(0.3) : Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            if model.found.count == 8 {
                Button("Далее — калибровка") { showCalibration = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            } else {
                Text("Маркеры 1–4 — две неподвижные стойки; 5–8 — четыре колеса. Сканируйте каждый QR-код.")
                    .font(.caption)
            }
            Button("Сбросить результаты") {
                model.reset()
                showCalibration = false
            }
            .buttonStyle(.bordered)
            if model.permissionDenied {
                Text("Разреши доступ к камере в настройках iPhone.")
            }
            Text("Тест идентификации 4 опорных и 4 колёсных маркеров. 3D-измерение пока не реализовано.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .sheet(isPresented: $showCalibration) {
            CalibrationView()
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

struct CalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var markerSize = "155"
    @State private var confirmed = false
    @State private var stage = 0

    private var validSize: Bool { (Double(markerSize.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Шаг 2 — подготовка к калибровке") {
                    Label("4 опорных и 4 колёсных QR распознаны", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Номинальная сторона QR-кода: 155 мм (печать 100%)")
                    Text("Перед точными измерениями проверьте фактическую сторону линейкой.")
                    Toggle("Маркеры закреплены и неподвижны", isOn: $confirmed)
                }
                Section("Базовая система") {
                    Text("Маркеры 1–2 закреплены на левой стойке, 3–4 — на правой; 5–8 — на четырёх колёсах. Для 3D-калибровки ещё требуется распознавание углов маркеров и вычисление их положения по нескольким кадрам.")
                        .font(.caption)
                }
                Section("Следующий этап") {
                    Button("Перейти к проверке геометрии") { stage = 1 }
                        .disabled(!confirmed || !validSize)
                    if stage == 1 {
                        Label("Базовые параметры подтверждены", systemImage: "checkmark.circle")
                        Text("Следующая необходимая функция: обнаружение углов маркеров на кадре, оценка положения камеры и проверка репроекционной ошибки. До её реализации измерения заблокированы.")
                        Button("Начать измерение (пока недоступно)") {}
                            .disabled(true)
                    }
                }
                Section("Важно") {
                    Text("Это экран подготовки, а не выполненная калибровка. Для реальных углов колёс нужны геометрические опорные точки, оценка положения камеры и проверка точности. QR-коды сами по себе не дают измерений.")
                }
                Section {
                    if confirmed && validSize {
                        Label("Данные подготовки заполнены. Геометрическая калибровка ещё не реализована.", systemImage: "info.circle")
                    } else {
                        Text("Подтвердите неподвижное крепление маркеров.")
                    }
                }
            }
            .navigationTitle("Калибровка")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
