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
    @State private var target = 1
    @State private var language = "ru"

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.07, blue: 0.12).ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        Text(scanner.spatialReady ? (language == "ru" ? "AUTOKLINIK • ТЕСТ ИЗМЕРЕНИЙ" : "AUTOKLINIK • MESSTEST") : (language == "ru" ? "AUTOKLINIK • КАЛИБРОВКА" : "AUTOKLINIK • KALIBRIERUNG"))
                            .font(.headline.bold()).foregroundStyle(.white)
                        Picker("Язык / Sprache", selection: $language) {
                            Text("Русский").tag("ru")
                            Text("Deutsch").tag("de")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: language) { scanner.setLanguage($0) }

                        CameraPreview(session: scanner.session)
                            .frame(height: scanner.spatialReady ? 160 : 300)
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

                        LiftOverview(detected: scanner.detected, visible: scanner.visible)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        Text(language == "ru" ? "Схема подъёмника • не масштабная" : "Hebebühne • schematisch")
                            .font(.caption2).foregroundStyle(.white.opacity(0.7))
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
                        Text(scanner.spatialReady ? (language == "ru" ? "Четыре опоры связаны • тест пространственных координат" : "Vier Referenzen verbunden • Raumkoordinatentest") : (language == "ru" ? "Связано опор: \(scanner.linkedBoards.count)/4. Покажите ID 0, затем соседние опоры вместе." : "Referenzen verbunden: \(scanner.linkedBoards.count)/4. ID 0, dann benachbarte Referenzen gemeinsam zeigen."))
                            .font(.caption).foregroundStyle(scanner.spatialReady ? Color.green : Color.yellow)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption2).foregroundStyle(.white)
                Text(scanner.relativeTests[id] ?? "—").font(.system(size: 10, design: .monospaced)).foregroundStyle(scanner.liveRelativeTests.contains(id) ? Color.cyan : Color.gray)
                Text(language == "ru" ? "Тест маркеров • не развал" : "Markertest • kein Sturz").font(.caption2).foregroundStyle(.orange)
            }
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
        for x: Float in [-2,2] {
            box(0.35,2.8,0.4,x,1.4,0,.systemBlue)
            box(1.3,0.14,0.24,x * 0.68,0.18,1,.systemYellow)
            box(1.3,0.14,0.24,x * 0.68,0.18,-1,.systemYellow)
        }
        box(1.7,0.65,3.8,0,0.65,0,.lightGray)
        box(1.45,0.55,1.9,0,1.2,-0.15,.darkGray)
        for x: Float in [-0.9,0.9] {
            for z: Float in [-1.25,1.25] {
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
