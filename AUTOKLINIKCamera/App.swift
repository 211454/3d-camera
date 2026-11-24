import SwiftUI
import AVFoundation

@main
struct AUTOKLINIKCameraApp: App {
    var body: some Scene { WindowGroup { ScannerView() } }
}

final class ScannerModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var found: Set<String> = []
    @Published var permissionDenied = false
    @Published var cameraStatus = "Запуск камеры…"
    @Published var liveAngles: [String: Double] = [:]
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera.session.queue")
    private let ids = Set((1...8).map { "AUTOKLINIK-3D-\($0)" })

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if !granted {
                DispatchQueue.main.async { self.permissionDenied = true; self.cameraStatus = "Нет доступа к камере" }
                return
            }
            self.queue.async {
                if self.session.inputs.isEmpty {
                    guard let camera = AVCaptureDevice.default(for: .video),
                          let input = try? AVCaptureDeviceInput(device: camera),
                          self.session.canAddInput(input) else {
                        DispatchQueue.main.async { self.cameraStatus = "Не удалось подключить камеру" }
                        return
                    }
                    self.session.addInput(input)
                    let output = AVCaptureMetadataOutput()
                    guard self.session.canAddOutput(output) else {
                        DispatchQueue.main.async { self.cameraStatus = "Не удалось настроить QR-сканер" }
                        return
                    }
                    self.session.addOutput(output)
                    output.metadataObjectTypes = [.qr]
                    output.setMetadataObjectsDelegate(self, queue: .main)
                }
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async { self.cameraStatus = self.session.isRunning ? "Камера запущена" : "Камера не запустилась" }
            }
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }
    func reset() { found.removeAll(); liveAngles.removeAll() }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        var angles: [String: Double] = [:]
        for item in metadataObjects {
            guard let qr = item as? AVMetadataMachineReadableCodeObject,
                  let value = qr.stringValue, ids.contains(value) else { continue }
            found.insert(value)
            let corners = qr.corners
            if corners.count >= 2 {
                let first = corners[0]
                let second = corners[1]
                let dx = Double(second.x - first.x)
                let dy = Double(second.y - first.y)
                if hypot(dx, dy) > 0.0001 {
                    angles[value] = atan2(dy, dx) * 180.0 / .pi
                }
            }
        }
        liveAngles = angles
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
    @State private var showWorkflow = false
    @State private var showAngleTest = false
    private let markerLabels = ["Левая стойка · верх", "Левая стойка · низ", "Правая стойка · верх", "Правая стойка · низ", "Переднее левое", "Переднее правое", "Заднее левое", "Заднее правое"]

    var body: some View {
        ScrollView {
        VStack(spacing: 12) {
            Text("AUTOKLINIK 3D CAMERA").font(.headline)
            Text("Шаг 1 — 2 стойки и 4 колеса")
            CameraPreview(session: model.session)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Text(model.cameraStatus).font(.caption).foregroundStyle(.secondary)
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
            Button("Тест углов QR") { showAngleTest = true }
                .buttonStyle(.bordered)
            Button("Пошаговая проверка автомобиля") { showWorkflow = true }
                .buttonStyle(.borderedProminent)
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
        }
        .sheet(isPresented: $showCalibration) {
            CalibrationView()
        }
        .sheet(isPresented: $showAngleTest) {
            QRAngleTestView(model: model)
        }
        .sheet(isPresented: $showWorkflow) {
            GuidedMeasurementView(model: model)
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

 
// Guided capture protocol. Each checkpoint records QR identities only;
// it does NOT claim to measure marker poses, runout, toe, camber or caster.
struct GuidedMeasurementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: ScannerModel
    @State private var step = 0
    @State private var snapshots: [Set<String>] = []
    @State private var started = false

    private let instructions = [
        "Автомобиль на земле, руль прямо. Сканируйте маркеры в исходном положении.",
        "Прокатите автомобиль назад и остановите. Затем обойдите автомобиль с iPhone и сканируйте.",
        "Верните автомобиль в исходное положение. Затем снова обойдите и сканируйте.",
        "Поверните руль влево, остановите автомобиль и обойдите его с камерой.",
        "Поверните руль вправо, остановите автомобиль и обойдите его с камерой."
    ]
    private let titles = ["Исходное положение", "После прокатки назад", "Возврат на место", "Руль влево", "Руль вправо"]
    private var required: Set<String> { Set((1...8).map { "AUTOKLINIK-3D-\($0)" }) }
    private var complete: Bool { required.isSubset(of: model.found) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Один мастер · один iPhone") {
                    Text("Четыре неподвижных маркера 1–4 на двух стойках; четыре съёмных маркера 5–8 на колёсах. Номинальный размер QR — 155 мм.")
                    Text("Во время прокатки телефон не снимает: сначала переместите машину, затем сканируйте.")
                }
                if step < instructions.count {
                    Section("Шаг \(step + 1) из \(instructions.count): \(titles[step])") {
                        Text(instructions[step])
                        Text("Распознано на этом шаге: \(model.found.intersection(required).count) из 8")
                        if !started {
                            Button("Начать сканирование шага") {
                                model.reset()
                                started = true
                            }
                        } else {
                            if complete {
                                Label("Все 8 идентификаторов обнаружены", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Text("Обойдите машину и покажите камере оставшиеся маркеры.")
                            }
                            Button(step == instructions.count - 1 ? "Сохранить последний этап" : "Сохранить этап и продолжить") {
                                snapshots.append(model.found.intersection(required))
                                step += 1
                                started = false
                                model.reset()
                            }
                            .disabled(!complete)
                        }
                    }
                } else {
                    Section("Протокол съёмки завершён") {
                        Label("Сохранены 5 этапов распознавания QR", systemImage: "checkmark.circle")
                        Text("Это проверка пошагового сценария, а не измерение углов. Координаты углов QR, пространственная калибровка, компенсация биения и вычисление развала/схождения/кастера ещё не реализованы.")
                        Button("Начать заново") {
                            snapshots.removeAll()
                            step = 0
                            started = false
                            model.reset()
                        }
                    }
                }
                Section("Безопасность") {
                    Text("Перемещайте автомобиль только на ровной безопасной площадке, без человека перед или за колёсами. Не используйте полученные данные для регулировки углов: измерительная точность не подтверждена.")
                        .font(.caption)
                }
            }
            .navigationTitle("Проверка автомобиля")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

 
// Experimental 2D orientation only; NOT a 3D inclination or wheel alignment.
struct QRAngleTestView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: ScannerModel

    private var referenceAngle: Double? {
        for number in 1...4 {
            if let angle = model.liveAngles["AUTOKLINIK-3D-\(number)"] {
                return angle
            }
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Покажите в одном кадре опорный QR 1–4 и проверяемый QR 5–8.")
                    .font(.caption)
                CameraPreview(session: model.session)
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                List {
                    ForEach(5...8, id: \.self) { number in
                        HStack {
                            Text("Маркер \(number)")
                            Spacer()
                            if let base = referenceAngle,
                               let current = model.liveAngles["AUTOKLINIK-3D-\(number)"] {
                                let delta = current - base
                                let wrapped = (delta + 540).truncatingRemainder(dividingBy: 360) - 180
                                Text(String(format: "%.1f°", wrapped))
                                    .monospacedDigit()
                            } else {
                                Text("Нет пары в кадре").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Text("Только разница направлений QR на 2D-изображении. Перспектива и движение камеры влияют на результат. Это НЕ 3D-наклон, развал или схождение.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Тест углов QR")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
