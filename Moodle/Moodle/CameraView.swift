import SwiftUI
import AVFoundation
import UIKit

// MARK: - Camera View
struct CameraView: View {
    let catName: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var showInstructions = true
    
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
        .onAppear {
            cameraManager.checkPermission()
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
    }
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published var isTaken = false
    @Published var capturedImage: UIImage?
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status {
                    DispatchQueue.main.async {
                        self.setUp()
                    }
                }
            }
        case .denied, .restricted:
            alert = true
        @unknown default:
            break
        }
    }
    
    func setUp() {
        do {
            session.beginConfiguration()
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                return
            }
            
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func takePic() {
        DispatchQueue.global(qos: .background).async {
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            self.session.stopRunning()
            
            DispatchQueue.main.async {
                withAnimation {
                    self.isTaken = true
                }
            }
        }
    }
    
    func retake() {
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
            
            DispatchQueue.main.async {
                withAnimation {
                    self.isTaken = false
                    self.capturedImage = nil
                }
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        capturedImage = UIImage(data: imageData)
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        cameraManager.preview = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        cameraManager.preview.frame = view.frame
        cameraManager.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(cameraManager.preview)
        
        DispatchQueue.global(qos: .background).async {
            cameraManager.session.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let preview = cameraManager.preview {
            preview.frame = uiView.frame
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
            let centerY = geometry.size.height / 2
            let size: CGFloat = 200
            
            ZStack {
                // Top-left corner
                Path { path in
                    path.move(to: CGPoint(x: centerX - size/2, y: centerY - size/2))
                    path.addLine(to: CGPoint(x: centerX - size/2 + 30, y: centerY - size/2))
                    path.move(to: CGPoint(x: centerX - size/2, y: centerY - size/2))
                    path.addLine(to: CGPoint(x: centerX - size/2, y: centerY - size/2 + 30))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                // Top-right corner
                Path { path in
                    path.move(to: CGPoint(x: centerX + size/2, y: centerY - size/2))
                    path.addLine(to: CGPoint(x: centerX + size/2 - 30, y: centerY - size/2))
                    path.move(to: CGPoint(x: centerX + size/2, y: centerY - size/2))
                    path.addLine(to: CGPoint(x: centerX + size/2, y: centerY - size/2 + 30))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                // Bottom-left corner
                Path { path in
                    path.move(to: CGPoint(x: centerX - size/2, y: centerY + size/2))
                    path.addLine(to: CGPoint(x: centerX - size/2 + 30, y: centerY + size/2))
                    path.move(to: CGPoint(x: centerX - size/2, y: centerY + size/2))
                    path.addLine(to: CGPoint(x: centerX - size/2, y: centerY + size/2 - 30))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                // Bottom-right corner
                Path { path in
                    path.move(to: CGPoint(x: centerX + size/2, y: centerY + size/2))
                    path.addLine(to: CGPoint(x: centerX + size/2 - 30, y: centerY + size/2))
                    path.move(to: CGPoint(x: centerX + size/2, y: centerY + size/2))
                    path.addLine(to: CGPoint(x: centerX + size/2, y: centerY + size/2 - 30))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
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
                cameraManager.takePic()
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

