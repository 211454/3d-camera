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
    @State private var cameraFull = false
    @State private var calibrationMode = true
    @State private var before: [Int: String] = [:]
    private let navy = Color(red: 0.04, green: 0.07, blue: 0.12)
    private let panel = Color(red: 0.08, green: 0.13, blue: 0.20)
    private func tr(_ ru: String, _ de: String) -> String { language == "ru" ? ru : de }
    private var names: [String] { [tr("Переднее левое","Vorne links"),tr("Переднее правое","Vorne rechts"),tr("Заднее левое","Hinten links"),tr("Заднее правое","Hinten rechts")] }

    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        GeometryReader { geo in
            ZStack {
                navy.ignoresSafeArea()
                CameraPreview(session: scanner.session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(calibrationMode || cameraFull ? 1 : 0)
                    .allowsHitTesting(false)
                if calibrationMode || cameraFull {
                    VStack {
                        Spacer()
                        Text(scanner.status).font(.subheadline.weight(.semibold))
                        Text(tr("Опоры","Referenzen") + "  \(scanner.linkedBoards.count)/4")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        ProgressView(value: Double(scanner.linkedBoards.count), total: 4).tint(.cyan)
                        Text(tr("Покажите соседние опоры вместе","Benachbarte Referenzen gemeinsam zeigen"))
                            .font(.caption)
                        Button { scanner.start() } label: {
                            Label(tr("Запустить камеру","Kamera starten"), systemImage: "video.fill")
                                .frame(maxWidth: .infinity).padding(10)
                        }.buttonStyle(.borderedProminent).tint(.blue)
                    }.padding(16).background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
                        .padding(12).padding(.bottom, 68)
                } else {
                    VStack(spacing: 10) {
                        LiftOverview(detected: scanner.detected, visible: scanner.visible)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        HStack {
                            Label(tr("Опоры","Referenzen") + " \(scanner.linkedBoards.count)/4", systemImage: "scope")
                            Spacer()
                            Label("\(scanner.detected.count)/8", systemImage: "qrcode.viewfinder")
                        }.font(.subheadline.bold()).foregroundStyle(.cyan)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(5...8, id: \.self) { id in
                                Button { selectedWheel = id; scanner.setTarget(id) } label: { wheelCard(id) }
                                    .buttonStyle(.plain)
                            }
                        }
                        if adjustment {
                            Text(tr("До: ","Vorher: ") + (before[selectedWheel] ?? "—"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text(tr("Тест координат • не для регулировки","Koordinatentest • keine Fahrzeugeinstellung"))
                            .font(.caption2).foregroundStyle(.orange)
                    }.padding(12).padding(.top, 70).padding(.bottom, 62)
                }
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AUTOKLINIK 3D").font(.title2.bold())
                            Text(tr("ГЕОМЕТРИЯ КОЛЁС","ACHSVERMESSUNG")).font(.caption2.bold()).foregroundStyle(.cyan)
                        }
                        Spacer()
                        Menu {
                            Button("Русский") { language = "ru"; scanner.setLanguage("ru") }
                            Button("Deutsch") { language = "de"; scanner.setLanguage("de") }
                        } label: { Image(systemName: "globe").font(.title2).padding(8) }
                    }.padding(12).background(navy.opacity(0.94))
                    Spacer()
                    HStack(spacing: 8) {
                        Button { calibrationMode = true; cameraFull = false; adjustment = false; scanner.start() } label: {
                            step("1",tr("Калибровка","Kalibrierung"),calibrationMode)
                        }.buttonStyle(.plain)
                        Button { if scanner.spatialReady { calibrationMode = false; adjustment = false; cameraFull = false } else { calibrationMode = true; scanner.start() } } label: {
                            step("2",tr("Измерения","Messung"),!calibrationMode && !adjustment)
                        }.buttonStyle(.plain)
                        Button { cameraFull.toggle(); scanner.start() } label: {
                            step("3",tr("Камера","Kamera"),cameraFull)
                        }.buttonStyle(.plain)
                    }.padding(12).background(navy.opacity(0.96))
                }
            }.frame(width: geo.size.width, height: geo.size.height)
        }
        .foregroundStyle(.white).preferredColorScheme(.dark)
        .background(navy.ignoresSafeArea())
        .onAppear { calibrationMode = !scanner.spatialReady; scanner.requestAccessAndStart(target: 1) }
        .onChange(of: scanner.spatialReady) { ready in
            if ready { calibrationMode = false; cameraFull = false }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { scanner.start() }
            else if phase == .background { scanner.stop() }
        }
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
        // Sculpted loft surfaces rather than stacked rectangular body blocks.
        let paint = UIColor(red: 0.67, green: 0.72, blue: 0.78, alpha: 1)
        let glass = UIColor(red: 0.065, green: 0.12, blue: 0.17, alpha: 1)
        func material(_ color: UIColor, metal: CGFloat = 0, rough: CGFloat = 0.35) -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = color
            m.metalness.contents = NSNumber(value: Double(metal))
            m.roughness.contents = NSNumber(value: Double(rough))
            m.isDoubleSided = true
            return m
        }
        func loft(_ rings: [[SCNVector3]], _ m: SCNMaterial) {
            guard let first = rings.first, first.count >= 3 else { return }
            let n = first.count
            let vertices = rings.flatMap { $0 }
            var indices: [Int32] = []
            for r in 0..<(rings.count - 1) {
                for j in 0..<n {
                    let k = (j + 1) % n
                    let a = Int32(r*n+j), b = Int32(r*n+k)
                    let c = Int32((r+1)*n+j), d = Int32((r+1)*n+k)
                    indices.append(contentsOf: [a,b,c,b,d,c])
                }
            }
            for j in 1..<(n-1) {
                indices.append(contentsOf: [0,Int32(j+1),Int32(j)])
                let q = Int32((rings.count-1)*n)
                indices.append(contentsOf: [q,q+Int32(j),q+Int32(j+1)])
            }
            let data = indices.withUnsafeBufferPointer { Data(buffer: $0) }
            let element = SCNGeometryElement(data: data, primitiveType: .triangles, primitiveCount: indices.count/3, bytesPerIndex: 4)
            let g = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)], elements: [element])
            g.materials = [m]
            scene.rootNode.addChildNode(SCNNode(geometry: g))
        }
        func section(_ z: Float, _ w: Float, _ low: Float, _ top: Float) -> [SCNVector3] {
            let h = top-low
            return [SCNVector3(-w*0.82,low,z),SCNVector3(-w,low+h*0.27,z),SCNVector3(-w*0.99,top-h*0.22,z),SCNVector3(-w*0.79,top,z),SCNVector3(w*0.79,top,z),SCNVector3(w*0.99,top-h*0.22,z),SCNVector3(w,low+h*0.27,z),SCNVector3(w*0.82,low,z)]
        }
        loft([section(-2.13,0.73,0.49,0.79),section(-1.94,0.88,0.36,0.90),section(-1.35,0.91,0.37,0.94),section(-0.65,0.91,0.39,0.92),section(0.55,0.91,0.39,0.91),section(1.31,0.91,0.36,0.86),section(1.85,0.86,0.36,0.76),section(2.08,0.75,0.46,0.67)], material(paint, metal: 0.38))
        func cabin(_ z: Float, _ base: Float, _ roof: Float, _ y: Float) -> [SCNVector3] {
            [SCNVector3(-base,0.89,z),SCNVector3(-roof,y,z),SCNVector3(roof,y,z),SCNVector3(base,0.89,z)]
        }
        loft([cabin(-1.37,0.76,0.68,0.94),cabin(-0.64,0.78,0.59,1.36),cabin(0.25,0.78,0.59,1.39),cabin(1.03,0.76,0.69,0.94)],material(glass, metal: 0.12, rough: 0.14))
        loft([section(-0.66,0.59,1.34,1.39),section(-0.42,0.61,1.36,1.43),section(0.22,0.61,1.37,1.43),section(0.38,0.59,1.34,1.39)],material(paint, metal: 0.38))
        func part(_ g: SCNGeometry, _ m: SCNMaterial, _ x: Float, _ y: Float, _ z: Float) -> SCNNode {
            g.materials = [m]
            let node = SCNNode(geometry: g)
            node.position = SCNVector3(x,y,z)
            scene.rootNode.addChildNode(node)
            return node
        }
        for x in [Float(-0.60),Float(0.60)] {
            let lamp = SCNBox(width: 0.47,height: 0.105,length: 0.10,chamferRadius: 0.045)
            _ = part(lamp,material(UIColor(red: 0.82,green: 0.94,blue: 1,alpha: 1)),x,0.70,1.94)
            _ = part(SCNBox(width: 0.46,height: 0.11,length: 0.10,chamferRadius: 0.035),material(.systemRed),x,0.78,-2.01)
        }
        _ = part(SCNBox(width: 0.67,height: 0.16,length: 0.055,chamferRadius: 0.025),material(.black),0,0.59,2.06)
        for x in [Float(-0.91),Float(0.91)] {
            let sign: Float = x < 0 ? -1 : 1
            _ = part(SCNSphere(radius: 0.12),material(paint,metal: 0.3),x*1.05,1.04,0.67)
            for z in [Float(-1.25),Float(1.25)] {
                let tire = part(SCNTorus(ringRadius: 0.275,pipeRadius: 0.085),material(.black,rough: 0.85),x,0.40,z)
                tire.eulerAngles.z = .pi/2
                let rim = part(SCNCylinder(radius: 0.225,height: 0.16),material(.darkGray,metal: 0.45),x,0.40,z)
                rim.eulerAngles.z = .pi/2
                let faceX = x + sign*0.095
                let hub = part(SCNCylinder(radius: 0.065,height: 0.035),material(.lightGray,metal: 0.55),faceX,0.40,z)
                hub.eulerAngles.z = .pi/2
                for j in 0..<10 {
                    let angle = Float(j)*2*Float.pi/10
                    let spoke = part(SCNBox(width: 0.023,height: 0.17,length: 0.033,chamferRadius: 0.005),material(.lightGray,metal: 0.6),faceX,0.40+cos(angle)*0.135,z+sin(angle)*0.135)
                    spoke.eulerAngles.x = angle
                }
            }
        }
        let points: [(Float,Float,Float)] = [(-2.20,0.9,0),(-2.20,1.8,0),(2.20,0.9,0),(2.20,1.8,0),(-1.1,0.42,1.25),(1.1,0.42,1.25),(-1.1,0.42,-1.25),(1.1,0.42,-1.25)]
        for (i,p) in points.enumerated() {
            let g = SCNBox(width: 0.30, height: 0.30, length: 0.035, chamferRadius: 0.008)
            let n = SCNNode(geometry: g)
            n.name = "marker-\(i+1)"
            n.eulerAngles.y = p.0 < 0 ? -Float.pi/2 : Float.pi/2
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
        camera.position = SCNVector3(6.0,4.3,6.8)
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
        let view = PreviewView(frame: .zero)
        view.layerSession.session = session
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) {
        if view.layerSession.session !== session { view.layerSession.session = session }
    }
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
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ?? AVCaptureDevice.default(for: .video),
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
