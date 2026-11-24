import SwiftUI
import AVFoundation
import Vision
import SceneKit
import simd

@main
struct AutoKlinik3DCameraApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @StateObject private var scanner = MarkerScanner()
    @State private var language = "ru"
    @State private var selectedWheel = 5
    @State private var adjustment = false
    @State private var before: [Int: String] = [:]
    private let navy = Color(red: 0.04, green: 0.07, blue: 0.12)
    private let panel = Color(red: 0.08, green: 0.13, blue: 0.20)
    private func tr(_ ru: String, _ de: String) -> String { language == "ru" ? ru : de }
    private var names: [String] { [tr("Переднее левое","Vorne links"),tr("Переднее правое","Vorne rechts"),tr("Заднее левое","Hinten links"),tr("Заднее правое","Hinten rechts")] }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AUTOKLINIK").font(.title2.bold()).foregroundStyle(.white)
                    Text("3D  •  "+tr("ГЕОМЕТРИЯ КОЛЁС","ACHSVERMESSUNG")).font(.caption2.bold()).foregroundStyle(.cyan)
                }
                Spacer()
                Menu {
                    Button("Русский") { language = "ru"; scanner.setLanguage("ru") }
                    Button("Deutsch") { language = "de"; scanner.setLanguage("de") }
                } label: { Image(systemName: "globe").font(.title2).foregroundStyle(.white) }
            }.padding(14)
            HStack(spacing: 4) {
                step("1",tr("Калибровка","Kalibrierung"),!scanner.spatialReady)
                step("2",tr("Измерения","Messung"),scanner.spatialReady && !adjustment)
                step("3",tr("Настройка","Einstellung"),scanner.spatialReady && adjustment)
            }.padding(.horizontal,10)
            ScrollView {
                VStack(spacing: 10) {
                    HStack {
                        Label(scanner.spatialReady ? tr("Опоры связаны","Referenzen verbunden") : tr("Привязка опор","Referenzen erfassen"), systemImage: scanner.spatialReady ? "checkmark.circle" : "scope")
                            .foregroundStyle(scanner.spatialReady ? Color.green : Color.orange)
                        Spacer()
                        Text("\(scanner.linkedBoards.count)/4").monospacedDigit().foregroundStyle(.white)
                    }.font(.caption.bold())
                    ProgressView(value: Double(scanner.linkedBoards.count), total: 4).tint(.green)
                    ZStack(alignment: .topLeading) {
                        LiftOverview(detected: scanner.detected, visible: scanner.visible).frame(height: 300)
                        Text(tr("3D • СХЕМА","3D • SCHEMA")).font(.caption2.bold()).foregroundStyle(.cyan).padding(10)
                        VStack {
                            Spacer()
                            HStack {
                                Label(tr("Опоры","Referenzen"), systemImage: "circle.fill").foregroundStyle(.green)
                                Spacer()
                                Text(tr("Модель не в масштабе","Nicht maßstabsgetreu")).foregroundStyle(.gray)
                            }.font(.caption2).padding(10)
                        }
                    }.background(panel).clipShape(RoundedRectangle(cornerRadius: 14))
                    HStack {
                        CameraPreview(session: scanner.session).frame(width: 142,height: 106).clipShape(RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 7) {
                            Label(tr("КАМЕРА LIVE","KAMERA LIVE"),systemImage: "video.fill").foregroundStyle(.cyan).font(.caption.bold())
                            Text(scanner.status).font(.caption).foregroundStyle(.white)
                            Text(tr("Мишени: ","Tafeln: ")+"\(scanner.detected.count)/8").font(.caption2).foregroundStyle(.green)
                        }
                        Spacer(minLength: 0)
                    }.padding(9).background(panel).clipShape(RoundedRectangle(cornerRadius: 12))
                    if !scanner.spatialReady {
                        Text(tr("Покажите ID 0, затем соседние опоры вместе.","ID 0, dann benachbarte Referenzen gemeinsam zeigen.")).font(.caption).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        Text(tr("ИЗМЕРЕНИЯ КОЛЁС","RADMESSUNGEN")).font(.caption.bold()).foregroundStyle(.white)
                        Spacer()
                        Text(tr("ТЕСТ • мм","TEST • mm")).font(.caption2.bold()).foregroundStyle(.orange)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())],spacing: 8) {
                        ForEach(5...8,id: \.self) { id in
                            Button { selectedWheel = id } label: { wheelCard(id) }.buttonStyle(.plain)
                        }
                    }
                    if adjustment && scanner.spatialReady {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(names[selectedWheel-5]).font(.headline).foregroundStyle(.white)
                            Text(tr("До: ","Vorher: ")+(before[selectedWheel] ?? "—")).foregroundStyle(.gray)
                            Text(tr("Сейчас: ","Jetzt: ")+(scanner.relativeTests[selectedWheel] ?? "—")).foregroundStyle(scanner.liveRelativeTests.contains(selectedWheel) ? Color.green : Color.gray)
                            Text(tr("Развал и схождение пока недоступны: требуется проверка калибровки.","Sturz und Spur noch nicht verfügbar: Kalibrierprüfung erforderlich.")).foregroundStyle(.orange)
                        }.font(.caption).frame(maxWidth: .infinity,alignment: .leading).padding(12).background(panel).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text(tr("Экспериментальные координаты мишеней. Не использовать для регулировки автомобиля.","Experimentelle Markerkoordinaten. Nicht zur Fahrzeugeinstellung verwenden.")).font(.caption2).foregroundStyle(.orange)
                }.padding(12)
            }
            HStack(spacing: 8) {
                Button { scanner.start() } label: {
                    Label(tr("Камера","Kamera"),systemImage: "camera").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).tint(.cyan)
                Button {
                    if !adjustment { before = scanner.relativeTests }
                    adjustment.toggle()
                } label: {
                    Label(adjustment ? tr("Измерения","Messung") : tr("Режим настройки","Einstellung"),systemImage: "slider.horizontal.3").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(.cyan).disabled(!scanner.spatialReady)
            }.font(.caption.bold()).padding(12).background(panel)
        }.background(navy.ignoresSafeArea()).preferredColorScheme(.dark)
        .onAppear { scanner.requestAccessAndStart(target: 1) }
        .onDisappear { scanner.stop() }
    }
    private func step(_ number: String,_ title: String,_ active: Bool) -> some View {
        HStack(spacing: 4) {
            Text(number).font(.caption2.bold()).padding(5).background(active ? Color.cyan : Color.gray.opacity(0.3)).clipShape(Circle()).foregroundStyle(active ? Color.black : Color.white)
            Text(title).font(.caption2.bold()).lineLimit(1).minimumScaleFactor(0.7)
        }.foregroundStyle(active ? Color.cyan : Color.gray).frame(maxWidth: .infinity).padding(.vertical,9).background(panel).clipShape(RoundedRectangle(cornerRadius: 8))
    }
    private func wheelCard(_ id: Int) -> some View {
        VStack(alignment: .leading,spacing: 7) {
            HStack {
                Image(systemName: "circle.circle").foregroundStyle(.cyan)
                Text(names[id-5]).font(.caption.bold()).foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            Text(scanner.relativeTests[id] ?? "X —  Y —  Z —").font(.system(size: 11,design: .monospaced)).foregroundStyle(scanner.liveRelativeTests.contains(id) ? Color.green : Color.gray).fixedSize(horizontal: false, vertical: true)
            Text(scanner.liveRelativeTests.contains(id) ? tr("В кадре","Live") : tr("Нет свежих данных","Keine Live-Daten")).font(.caption2).foregroundStyle(scanner.liveRelativeTests.contains(id) ? Color.green : Color.orange)
            Text(tr("Развал —  Схождение —","Sturz —  Spur —")).font(.caption2).foregroundStyle(.gray)
        }.padding(10).frame(maxWidth: .infinity,alignment: .leading).background(panel).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedWheel == id ? Color.cyan : Color.clear,lineWidth: 1))
    }
}

struct LiftOverview: UIViewRepresentable {
    let detected: Set<Int>
    let visible: Set<Int>
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.04, green: 0.07, blue: 0.12, alpha: 1)
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        let scene = SCNScene()
        view.scene = scene
        func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ x: Float, _ y: Float, _ z: Float, _ color: UIColor) {
            let g = SCNBox(width: w, height: h, length: l, chamferRadius: 0.04)
            g.firstMaterial?.diffuse.contents = color
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(x,y,z)
            scene.rootNode.addChildNode(n)
        }
        box(5,0.12,6,0,-0.1,0,.darkGray)
        for x in [Float(-2),Float(2)] {
            box(0.35,2.8,0.4,x,1.4,0,.systemBlue)
            box(1.3,0.14,0.24,x * 0.68,0.18,1,.systemYellow)
            box(1.3,0.14,0.24,x * 0.68,0.18,-1,.systemYellow)
        }
        box(1.7,0.48,3.8,0,0.65,0,.lightGray)
        box(1.42,0.38,1.85,0,1.03,-0.12,UIColor(red: 0.12, green: 0.24, blue: 0.34, alpha: 1))
        box(1.35,0.12,1.72,0,1.26,-0.12,.lightGray)
        for x in [Float(-0.57),Float(0.57)] {
            box(0.35,0.12,0.06,x,0.72,1.91,.white)
            box(0.35,0.12,0.06,x,0.72,-1.91,.systemRed)
        }
        for x in [Float(-0.9),Float(0.9)] {
            for z in [Float(-1.25),Float(1.25)] {
                let wheel = SCNCylinder(radius: 0.36, height: 0.26)
                wheel.firstMaterial?.diffuse.contents = UIColor.black
                let n = SCNNode(geometry: wheel)
                n.eulerAngles.z = Float.pi / 2
                n.position = SCNVector3(x,0.38,z)
                scene.rootNode.addChildNode(n)
            }
        }
        let points: [(Float,Float,Float)] = [(-2,2.4,0.23),(-2,0.9,0.23),(2,2.4,0.23),(2,0.9,0.23),(-1.1,0.42,1.25),(1.1,0.42,1.25),(-1.1,0.42,-1.25),(1.1,0.42,-1.25)]
        for (i,p) in points.enumerated() {
            let g = SCNSphere(radius: 0.15)
            let n = SCNNode(geometry: g)
            n.name = "marker-\(i+1)"
            n.position = SCNVector3(p.0,p.1,p.2)
            scene.rootNode.addChildNode(n)
            let label = SCNText(string: String(i+1), extrusionDepth: 0)
            label.font = UIFont.boldSystemFont(ofSize: 12)
            label.firstMaterial?.diffuse.contents = UIColor.white
            let t = SCNNode(geometry: label)
            t.scale = SCNVector3(0.025,0.025,0.025)
            t.position = SCNVector3(p.0,p.1+0.2,p.2)
            t.constraints = [SCNBillboardConstraint()]
            scene.rootNode.addChildNode(t)
        }
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(5,5,7)
        camera.look(at: SCNVector3(0,0.7,0))
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        for id in 1...8 {
            view.scene?.rootNode.childNode(withName: "marker-\(id)", recursively: true)?.geometry?.firstMaterial?.diffuse.contents = visible.contains(id) ? UIColor.systemGreen : (detected.contains(id) ? UIColor.systemOrange : UIColor.systemGray)
        }
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
    @Published var boardImageMeasurements: [Int: String] = [:]
    @Published var relativeTests: [Int: String] = [:]
    @Published var liveRelativeTests: Set<Int> = []
    @Published var linkedBoards: Set<Int> = []
    @Published var spatialReady = false
    private var worldRefs: [Int: simd_float4x4] = [:]
    private var links: [Int: [Int: simd_float4x4]] = [:]
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
                if let c = output.connection(with: .video), c.isCameraIntrinsicMatrixDeliverySupported {
                    c.isCameraIntrinsicMatrixDeliveryEnabled = true
                }
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
        let observations = ArucoBridge.markerObservations(in: buffer)
        var poses: [Int: simd_float4x4] = [:]
        if let data = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) as? Data,
           data.count >= MemoryLayout<simd_float3x3>.size {
            var k = matrix_identity_float3x3
            _ = withUnsafeMutableBytes(of: &k) { data.copyBytes(to: $0) }
            for item in observations {
                if let id = item["id"]?.intValue, let pose = Self.planarPose(item, k: k) {
                    poses[id] = pose
                }
            }
        }
        let refs = poses.keys.filter { (0..<32).contains($0) }.sorted()
        // Retain same-frame rigid transforms, including connections observed before the origin.
        for a in refs {
            for b in refs where a != b {
                guard let pa = poses[a], let pb = poses[b] else { continue }
                if links[a]?[b] == nil {
                    links[a, default: [:]][b] = simd_inverse(pa) * pb
                }
            }
        }
        // Fixed origin is ArUco ID 0. Never silently change it when the phone moves.
        if poses[0] != nil { worldRefs[0] = matrix_identity_float4x4 }
        var expanded = true
        while expanded {
            expanded = false
            for a in Array(worldRefs.keys).sorted() {
                guard let wa = worldRefs[a], let neighbors = links[a] else { continue }
                for b in neighbors.keys.sorted() where worldRefs[b] == nil {
                    guard let ab = neighbors[b] else { continue }
                    worldRefs[b] = wa * ab
                    expanded = true
                }
            }
        }
        let linked = Set(worldRefs.keys.compactMap { MarkerBoardConfiguration.boardNumber(forArUcoID: $0) })
        let ready = linked.isSuperset(of: Set(1...4))
        var relative: [Int: String] = [:]
        if let ref = refs.first(where: { worldRefs[$0] != nil }),
           let base = poses[ref], let world = worldRefs[ref] {
            let worldFromCamera = world * simd_inverse(base)
            // Fixed square ID per wheel board avoids jumps between different printed squares.
            for id in [32,40,48,56] {
                guard let board = MarkerBoardConfiguration.boardNumber(forArUcoID: id), let pose = poses[id] else { continue }
                let t = (worldFromCamera * pose).columns.3
                relative[board] = String(format: "X %.1f Y %.1f Z %.1f мм", t.x,t.y,t.z)
            }
        }
        let ids = observations.compactMap { $0["id"]?.intValue }
        var measurements: [Int: String] = [:]
        for item in observations {
            guard let markerID = item["id"]?.intValue,
                  let board = MarkerBoardConfiguration.boardNumber(forArUcoID: markerID),
                  let x = item["x"]?.doubleValue, let y = item["y"]?.doubleValue,
                  let edge = item["edgePixels"]?.doubleValue,
                  let angle = item["angleDegrees"]?.doubleValue else { continue }
            if measurements[board] == nil {
                measurements[board] = String(format: "x%.0f y%.0f px | %.0f px | %+.1f°", x, y, edge, angle)
            }
        }
        let boards = Set(ids.compactMap { MarkerBoardConfiguration.boardNumber(forArUcoID: $0) })
        DispatchQueue.main.async {
            self.visible = boards
            self.linkedBoards = linked
            self.spatialReady = ready
            self.liveRelativeTests = Set(relative.keys)
            for (board, value) in relative { self.relativeTests[board] = value }
            for (board, value) in measurements { self.boardImageMeasurements[board] = value }
            self.detected.formUnion(boards)
            self.candidateCount = ids.count
            self.status = self.localized("В кадре ArUco: \(ids.count), мишеней: \(boards.count); сохранено: \(self.detected.count)",
                                         "ArUco sichtbar: \(ids.count), Tafeln: \(boards.count); gespeichert: \(self.detected.count)")
        }
    }
    // Experimental single-square homography pose. Not calibrated wheel geometry.
    private static func planarPose(_ item: [String: NSNumber], k: simd_float3x3) -> simd_float4x4? {
        let half = Float(MarkerBoardConfiguration.markerSizeMillimeters / 2)
        let xy = [SIMD2<Float>(-half,-half), SIMD2<Float>(half,-half), SIMD2<Float>(half,half), SIMD2<Float>(-half,half)]
        guard abs(simd_determinant(k)) > 0.001 else { return nil }
        let inv = simd_inverse(k)
        var a = [[Float]]()
        for i in 0..<4 {
            guard let u = item["u\(i)"]?.floatValue, let v = item["v\(i)"]?.floatValue else { return nil }
            let q = inv * SIMD3<Float>(u,v,1)
            let x = xy[i].x, y = xy[i].y
            a.append([x,y,1,0,0,0,-q.x*x,-q.x*y,q.x])
            a.append([0,0,0,x,y,1,-q.y*x,-q.y*y,q.y])
        }
        for j in 0..<8 {
            guard let pivot = (j..<8).max(by: { abs(a[$0][j]) < abs(a[$1][j]) }), abs(a[pivot][j]) > 0.00000001 else { return nil }
            a.swapAt(j,pivot)
            let d = a[j][j]
            for c in j...8 { a[j][c] /= d }
            for i in 0..<8 where i != j {
                let f = a[i][j]
                for c in j...8 { a[i][c] -= f*a[j][c] }
            }
        }
        let h = a.map { $0[8] }
        let c1 = SIMD3<Float>(h[0],h[3],h[6]), c2 = SIMD3<Float>(h[1],h[4],h[7])
        let scale = 2 / (simd_length(c1)+simd_length(c2))
        guard scale.isFinite, scale > 0 else { return nil }
        let x = simd_normalize(c1)
        let y0 = c2 - simd_dot(c2,x)*x
        guard simd_length(y0) > 0.00000001 else { return nil }
        let y = simd_normalize(y0), z = simd_cross(x,y)
        let t = SIMD3<Float>(h[2],h[5],1)*scale
        return simd_float4x4(columns: (SIMD4<Float>(x,0),SIMD4<Float>(y,0),SIMD4<Float>(z,0),SIMD4<Float>(t,1)))
    }
    private func speak(_ text: String) {
        voice.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language == "de" ? "de-DE" : "ru-RU")
        utterance.rate = 0.48
        voice.speak(utterance)
    }
}
