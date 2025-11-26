import SwiftUI
import AVFoundation
import UIKit

// MARK: - Camera View
struct CameraView: View {
    let catName: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var showInstructions = true
    @State private var showImagePreview = false
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Instructions Overlay
            if showInstructions {
                InstructionsOverlay()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation {
                            showInstructions = false
                        }
                    }
            }
            
            // Framing Guide Overlay
            FramingGuideOverlay()
            
            // Top Back Button
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                
                Spacer()
            }
            
            // Bottom Camera Controls
            VStack {
                Spacer()
                
                CameraControlsView(
                    cameraManager: cameraManager,
                    showInstructions: $showInstructions
                )
                .padding(.bottom, 34) // Space for home indicator
            }
        }
        .task {
            cameraManager.checkPermission()
        }
        .onAppear {
            // Restart camera session when view appears (e.g., when navigating back)
            if !cameraManager.isSessionRunning && cameraManager.session.inputs.count > 0 {
                print("View appeared, restarting camera session")
                cameraManager.restartSession()
            }
            // Reset navigation state
            cameraManager.shouldNavigateToPreview = false
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showImagePreview) {
            if let image = cameraManager.capturedImage {
                ImagePreviewView(catName: catName, capturedImage: image)
            }
        }
        .alert("Camera Permission", isPresented: $cameraManager.alert) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please allow camera access in Settings to take photos of your cat.")
        }
        .onChange(of: cameraManager.shouldNavigateToPreview) { oldValue, newValue in
            if newValue && cameraManager.capturedImage != nil {
                print("Navigating to image preview")
                DispatchQueue.main.async {
                    showImagePreview = true
                    // Reset flag after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        cameraManager.shouldNavigateToPreview = false
                    }
                }
            }
        }
        .onChange(of: cameraManager.capturedImage) { oldValue, newValue in
            if newValue != nil && oldValue == nil && !showImagePreview {
                print("Image captured, triggering navigation via image change")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if cameraManager.capturedImage != nil {
                        showImagePreview = true
                    }
                }
            }
        }
    }
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    var preview: AVCaptureVideoPreviewLayer?
    @Published var isTaken = false
    @Published var capturedImage: UIImage?
    @Published var isSessionRunning = false
    @Published var shouldNavigateToPreview = false
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status {
                    self.setUp()
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.alert = true
            }
        @unknown default:
            break
        }
    }
    
    func setUp() {
        sessionQueue.async {
            do {
                self.session.beginConfiguration()
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    return
                }
                
                let input = try AVCaptureDeviceInput(device: device)
                
                // Remove existing inputs
                for existingInput in self.session.inputs {
                    self.session.removeInput(existingInput)
                }
                
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                // Remove existing outputs
                for existingOutput in self.session.outputs {
                    self.session.removeOutput(existingOutput)
                }
                
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                
                self.session.commitConfiguration()
                
                // Start session on background queue
                self.sessionQueue.async {
                    if !self.session.isRunning {
                        self.session.startRunning()
                        print("Camera session started: \(self.session.isRunning)")
                        DispatchQueue.main.async {
                            self.isSessionRunning = true
                        }
                    }
                }
            } catch {
                print("Camera setup error: \(error.localizedDescription)")
            }
        }
    }
    
    func takePic() {
        print("takePic() called")
        sessionQueue.async {
            print("takePic() - on session queue")
            print("Session isRunning: \(self.session.isRunning)")
            print("Output connections count: \(self.output.connections.count)")
            
            guard self.session.isRunning else {
                print("ERROR: Session is not running")
                return
            }
            
            guard !self.output.connections.isEmpty else {
                print("ERROR: No connections available")
                return
            }
            
            // Create photo settings with proper format
            var settings: AVCapturePhotoSettings
            if self.output.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }
            
            // Ensure we have a valid connection
            if let connection = self.output.connection(with: .video) {
                print("Video connection found, isActive: \(connection.isActive)")
                if connection.isActive {
                    print("Capturing photo...")
                    self.output.capturePhoto(with: settings, delegate: self)
                    print("capturePhoto called")
                    
                    // Don't stop session immediately - wait for photo to be captured
                    // self.session.stopRunning()
                    
                    DispatchQueue.main.async {
                        self.isSessionRunning = false
                        withAnimation {
                            self.isTaken = true
                        }
                    }
                } else {
                    print("ERROR: Connection is not active")
                }
            } else {
                print("ERROR: No video connection available")
            }
        }
    }
    
    func retake() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                    withAnimation {
                        self.isTaken = false
                        self.capturedImage = nil
                        self.shouldNavigateToPreview = false
                    }
                }
            }
        }
    }
    
    func restartSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                print("Restarting camera session")
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                    self.isTaken = false
                    self.capturedImage = nil
                    self.shouldNavigateToPreview = false
                    print("Session restarted, isSessionRunning: \(self.isSessionRunning)")
                }
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("photoOutput delegate called")
        if let error = error {
            print("Photo capture error: \(error.localizedDescription)")
            return
        }
        
        print("Photo captured successfully")
        guard let imageData = photo.fileDataRepresentation() else {
            print("ERROR: No image data available")
            return
        }
        
        print("Image data size: \(imageData.count) bytes")
        guard let image = UIImage(data: imageData) else {
            print("ERROR: Could not create UIImage from data")
            return
        }
        
        print("UIImage created successfully, size: \(image.size)")
        DispatchQueue.main.async {
            print("Setting captured image on main thread")
            self.capturedImage = image
            self.shouldNavigateToPreview = true
            print("shouldNavigateToPreview set to true, capturedImage is set: \(self.capturedImage != nil)")
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Store reference
        cameraManager.preview = previewLayer
        
        // Set initial frame
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let preview = cameraManager.preview else { return }
        
        // Update frame whenever view updates - must be on main thread
        if Thread.isMainThread {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            preview.frame = uiView.bounds
            CATransaction.commit()
        } else {
            DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                preview.frame = uiView.bounds
                CATransaction.commit()
            }
        }
    }
}

// MARK: - Instructions Overlay
struct InstructionsOverlay: View {
    var body: some View {
        VStack {
            Spacer()
                .frame(height: 100)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Upload an image of your cat and make sure it:")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(.textPrimary)
                
                VStack(alignment: .leading, spacing: 8) {
                    InstructionBullet(text: "Shows one cat only (no other cats in frame)")
                    InstructionBullet(text: "Shows the whole face")
                    InstructionBullet(text: "Has good lighting")
                    InstructionBullet(text: "Shows the cat in the center of the screen")
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.85))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}

// MARK: - Framing Guide Overlay
struct FramingGuideOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2 + 60  // Moved down by 40 points
            let size: CGFloat = 200
            let cornerRadius: CGFloat = 15
            let cornerLength: CGFloat = 30
            
            ZStack {
                // Top-left curved corner
                Path { path in
                    let startX = centerX - size/2
                    let startY = centerY - size/2
                    path.move(to: CGPoint(x: startX + cornerLength, y: startY))
                    path.addQuadCurve(
                        to: CGPoint(x: startX, y: startY + cornerLength),
                        control: CGPoint(x: startX, y: startY)
                    )
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                
                // Top-right curved corner
                Path { path in
                    let startX = centerX + size/2
                    let startY = centerY - size/2
                    path.move(to: CGPoint(x: startX - cornerLength, y: startY))
                    path.addQuadCurve(
                        to: CGPoint(x: startX, y: startY + cornerLength),
                        control: CGPoint(x: startX, y: startY)
                    )
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                
                // Bottom-left curved corner
                Path { path in
                    let startX = centerX - size/2
                    let startY = centerY + size/2
                    path.move(to: CGPoint(x: startX + cornerLength, y: startY))
                    path.addQuadCurve(
                        to: CGPoint(x: startX, y: startY - cornerLength),
                        control: CGPoint(x: startX, y: startY)
                    )
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                
                // Bottom-right curved corner
                Path { path in
                    let startX = centerX + size/2
                    let startY = centerY + size/2
                    path.move(to: CGPoint(x: startX - cornerLength, y: startY))
                    path.addQuadCurve(
                        to: CGPoint(x: startX, y: startY - cornerLength),
                        control: CGPoint(x: startX, y: startY)
                    )
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
    }
}

// MARK: - Camera Controls
struct CameraControlsView: View {
    @ObservedObject var cameraManager: CameraManager
    @Binding var showInstructions: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Gallery Thumbnail
            Button(action: {
                // Open photo gallery
            }) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    )
            }
            .padding(.leading, 30)
            
            Spacer()
            
            // Shutter Button
            Button(action: {
                print("Shutter button pressed")
                print("isSessionRunning: \(cameraManager.isSessionRunning)")
                if cameraManager.isSessionRunning {
                    print("Calling takePic()")
                    cameraManager.takePic()
                } else {
                    print("ERROR: Session not running, cannot take photo")
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                }
            }
            .disabled(!cameraManager.isSessionRunning)
            .opacity(cameraManager.isSessionRunning ? 1.0 : 0.5)
            
            Spacer()
            
            // Flash Off Icon
            Button(action: {
                // Toggle flash
            }) {
                Image(systemName: "bolt.slash.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .padding(.trailing, 30)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Preview
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(catName: "noodle")
    }
}

