import SwiftUI
import Foundation
import CoreML

// MARK: - Processing View
struct ProcessingView: View {
    let catName: String
    let capturedImage: UIImage
    @Environment(\.dismiss) var dismiss
    @StateObject private var processingManager = ProcessingManager()
    @State private var showResults = false
    @State private var showImageRejected = false
    @State private var resultsLandmarks: [(x: Double, y: Double)] = []
    @State private var resultsPainScores: (eye: Int, ear: Int, muzzle: Int) = (0, 0, 0)
    @State private var orientedImage: UIImage?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Section
                ProcessingHeaderView()
                
                // Main Content
                VStack(spacing: 20) {
                    // Image Preview
                    ImagePreviewSection(image: orientedImage ?? capturedImage)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Analysis Status
                    AnalysisStatusView(progress: processingManager.progress)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 100) // Space for bottom nav
                }
            }
        }
        .background(Color.appBackground)
        .safeAreaInset(edge: .bottom) {
            ProcessingBottomNavigationView()
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showResults) {
            if let oriented = orientedImage {
                ResultsView(
                    catName: catName,
                    capturedImage: oriented,
                    landmarks: resultsLandmarks,
                    painScores: resultsPainScores
                )
            }
        }
        .onAppear {
            // Fix orientation once and use the same image for processing and display
            let fixedImage = capturedImage.fixedOrientation()
            orientedImage = fixedImage
            
            processingManager.startProcessing(image: fixedImage) { landmarks, scores in
                resultsLandmarks = landmarks
                
                // Check if any score is -1 (error)
                if scores.eye == -1 || scores.ear == -1 || scores.muzzle == -1 {
                    // Show image rejected popup instead of navigating to results
                    showImageRejected = true
                } else {
                    // All scores are valid, clamp to valid range and navigate to results
                    resultsPainScores = (
                        eye: max(0, min(2, scores.eye)),
                        ear: max(0, min(2, scores.ear)),
                        muzzle: max(0, min(2, scores.muzzle))
                    )
                    showResults = true
                }
            }
        }
        .overlay {
            // Image Rejected Popup
            if showImageRejected {
                ImageRejectedView(onRetake: {
                    // Pop back to AnalyzeCatView by dismissing multiple times
                    // Navigation stack: AnalyzeCatView -> CameraView -> ImagePreviewView -> ProcessingView
                    // We need to pop 3 times to get back to AnalyzeCatView
                    dismiss() // Pop ImagePreviewView
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        dismiss() // Pop CameraView
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            dismiss() // Pop ProcessingView, leaving us at AnalyzeCatView
                        }
                    }
                })
                .transition(.opacity)
                .zIndex(1000)
            }
        }
    }
}

// MARK: - Processing Header
struct ProcessingHeaderView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button and title
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textLight)
                        .padding(8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Title section
            VStack(alignment: .leading, spacing: 4) {
                Text("Analyze Cat")
                    .font(.poppins(.bold, size: 28))
                    .foregroundColor(.textLight)
                
                Text("Processing Image")
                    .font(.poppins(.regular, size: 16))
                    .foregroundColor(.textLight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(Color.headerBackground)
    }
}

// MARK: - Analysis Status View
struct AnalysisStatusView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Analyzing...")
                .font(.poppins(.bold, size: 18))
                .foregroundColor(.textPrimary)
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 40)
                    
                    // Progress Fill
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.headerBackground)
                        .frame(width: geometry.size.width * CGFloat(progress / 100.0), height: 40)
                    
                    // Percentage Text
                    HStack {
                        Spacer()
                        Text("\(Int(progress))%")
                            .font(.poppins(.medium, size: 16))
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                }
            }
            .frame(height: 40)
        }
    }
}

// MARK: - Processing Manager
class ProcessingManager: ObservableObject {
    @Published var progress: Double = 0
    @Published var isProcessing = false
    
    private var completionHandler: (([(x: Double, y: Double)], (eye: Int, ear: Int, muzzle: Int)) -> Void)?
    
    func startProcessing(image: UIImage, completion: @escaping ([(x: Double, y: Double)], (eye: Int, ear: Int, muzzle: Int)) -> Void) {
        isProcessing = true
        progress = 0
        completionHandler = completion
        
        // Save image to temporary file
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("ERROR: Could not convert image to JPEG data")
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let imagePath = tempDir.appendingPathComponent("cat_image_\(UUID().uuidString).jpg")
        
        do {
            try imageData.write(to: imagePath)
            print("Image saved to: \(imagePath.path)")
            
            // Start processing with progress updates
            processImage(imagePath: imagePath.path)
        } catch {
            print("ERROR: Could not save image: \(error.localizedDescription)")
        }
    }
    
    private func processImage(imagePath: String) {
        // Start progress animation
        startProgressAnimation()
        
        // Load image from path
        guard let image = UIImage(contentsOfFile: imagePath) else {
            print("ERROR: Could not load image from \(imagePath)")
            DispatchQueue.main.async {
                self.isProcessing = false
            }
            return
        }
        
        // Start Core ML processing in background
        DispatchQueue.global(qos: .userInitiated).async {
            // Use Core ML to predict landmarks and calculate pain scores
            self.processWithCoreML(image: image)
            
            // Complete progress when done
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 0.3)) {
                    self.progress = 100
                }
                self.isProcessing = false
            }
        }
    }
    
    private func startProgressAnimation() {
        // Animate progress from 0 to 95% over estimated time
        // The last 5% will be set when processing completes
        let estimatedDuration: Double = 10.0 // Estimated processing time in seconds
        let targetProgress: Double = 95.0
        let steps = 50 // Number of animation steps
        let stepDuration = estimatedDuration / Double(steps)
        let progressIncrement = targetProgress / Double(steps)
        
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            
            DispatchQueue.main.async {
                let newProgress = min(Double(currentStep) * progressIncrement, targetProgress)
                withAnimation(.linear(duration: stepDuration)) {
                    self.progress = newProgress
                }
            }
            
            if currentStep >= steps {
                timer.invalidate()
            }
        }
    }
    
    private func processWithCoreML(image: UIImage) {
        // Use Core ML for on-device inference
        let predictor = CoreMLLandmarkPredictor()
        
        print("🔍 Predicting landmarks with Core ML...")
        
        guard let landmarks = predictor.predictLandmarks(from: image) else {
            print("❌ Failed to predict landmarks")
            DispatchQueue.main.async {
                self.isProcessing = false
            }
            return
        }
        
        print("✅ Predicted \(landmarks.count) landmarks")
        for (i, landmark) in landmarks.enumerated() {
            print("  Landmark \(i): (\(landmark.x), \(landmark.y))")
        }
        
        // Calculate pain scores
        print("\n📊 Calculating pain scores...")
        let scores = PainScoreCalculator.calculatePainScores(landmarks: landmarks)
        
        print("✅ Pain scores calculated:")
        print("   Eye score: \(scores.eye) (-1=error, 0=normal, 1=mild, 2=moderate/severe)")
        print("   Ear score: \(scores.ear) (-1=error, 0=normal, 1=mild, 2=moderate/severe)")
        print("   Muzzle score: \(scores.muzzle) (-1=error, 0=normal, 1=mild, 2=moderate/severe)")
        
        if scores.eye == -1 || scores.ear == -1 || scores.muzzle == -1 {
            print("⚠️  WARNING: One or more scores indicate an error in landmark detection")
        }
        
        // Call completion handler with original scores (not clamped)
        // The ProcessingView will check for -1 and show the rejection popup
        DispatchQueue.main.async {
            self.completionHandler?(landmarks, scores)
        }
    }
}

// MARK: - Processing Bottom Navigation
struct ProcessingBottomNavigationView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.black)
                .frame(width: 134, height: 5)
                .cornerRadius(100)
                .padding(.top, 8)
            
            // Navigation Items
            HStack {
                NavButton(icon: "house", isSelected: false)
                NavButton(icon: "magnifyingglass", isSelected: false)
                NavButton(icon: "square.on.square", isSelected: true, size: 24, highlightColor: .purple)
                NavButton(icon: "calendar", isSelected: false)
                NavButton(icon: "person", isSelected: false)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.appBackground)
        .shadow(color: Color.borderColor, radius: 0)
    }
}

// MARK: - Image Rejected View
struct ImageRejectedView: View {
    let onRetake: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            // Popup Card
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("Image")
                                .font(.poppins(.bold, size: 28))
                                .foregroundColor(.textPrimary)
                            
                            Text("Rejected")
                                .font(.poppins(.bold, size: 28))
                                .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.45)) // Coral
                        }
                        
                        // Explanation text
                        Text("We couldn't detect your cat's face clearly. Please take another photo.")
                            .font(.poppins(.regular, size: 14))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Requirements Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Does your photo meet the following requirements?")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundColor(.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InstructionBullet(text: "Shows one cat only (no other cats in frame)")
                            InstructionBullet(text: "Shows the whole face")
                            InstructionBullet(text: "Has good lighting")
                            InstructionBullet(text: "Shows the cat in the center of the screen")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    
                    // Retake Photo Button
                    Button(action: onRetake) {
                        Text("Retake Photo")
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 32)
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
}

// MARK: - Preview
struct ProcessingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProcessingView(
                catName: "noodle",
                capturedImage: UIImage(systemName: "photo")!
            )
        }
    }
}

