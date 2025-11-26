//
//  ResultsView.swift
//  Moodle
//
//  Results screen showing pain analysis results
//

import SwiftUI

// MARK: - Results View
struct ResultsView: View {
    let catName: String
    let capturedImage: UIImage
    let landmarks: [(x: Double, y: Double)]
    let painScores: (eye: Int, ear: Int, muzzle: Int)
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentationMode) var presentationMode
    @State private var notes: String = ""
    @State private var showSaveConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                ResultsHeaderView(onBack: {
                    // Pop back to AnalyzeCatView by dismissing multiple times
                    // Navigation stack: AnalyzeCatView -> CameraView -> ImagePreviewView -> ProcessingView -> ResultsView
                    // We need to pop 3 times to get back to AnalyzeCatView
                    popToAnalyzeCatView()
                })
                
                // Main Content
                VStack(spacing: 20) {
                    // Cat Image with Landmarks
                    CatImageWithLandmarksView(image: capturedImage, landmarks: landmarks)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Disclaimer
                    DisclaimerView()
                        .padding(.horizontal, 20)
                    
                    // Pain Score Card
                    PainScoreCardView(
                        catName: catName,
                        eyeScore: painScores.eye,
                        earScore: painScores.ear,
                        muzzleScore: painScores.muzzle
                    )
                    .padding(.horizontal, 20)
                    
                    // EYES Score Display
                    PainScoreDisplayView(
                        title: "EYES",
                        score: painScores.eye
                    )
                    .padding(.horizontal, 20)
                    
                    // EARS Score Display
                    PainScoreDisplayView(
                        title: "EARS",
                        score: painScores.ear
                    )
                    .padding(.horizontal, 20)
                    
                    // MUZZLE Score Display
                    PainScoreDisplayView(
                        title: "MUZZLE",
                        score: painScores.muzzle
                    )
                    .padding(.horizontal, 20)
                    
                    // NOTES Section
                    NotesSectionView(notes: $notes)
                        .padding(.horizontal, 20)
                    
                    // Save Entry Button
                    SaveEntryButton {
                        saveEntry()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for bottom nav
                }
            }
        }
        .background(Color.appBackground)
        .safeAreaInset(edge: .bottom) {
            ResultsBottomNavigationView()
        }
        .navigationBarBackButtonHidden(true)
        .alert("Entry Saved", isPresented: $showSaveConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your pain analysis entry has been saved successfully.")
        }
    }
    
    private func saveEntry() {
        // TODO: Save to Core Data
        print("💾 Saving entry:")
        print("   Cat: \(catName)")
        print("   Eye score: \(painScores.eye)")
        print("   Ear score: \(painScores.ear)")
        print("   Muzzle score: \(painScores.muzzle)")
        print("   Notes: \(notes)")
        
        showSaveConfirmation = true
    }
    
    private func popToAnalyzeCatView() {
        // Pop back to AnalyzeCatView by dismissing multiple times
        // Navigation stack: AnalyzeCatView -> CameraView -> ImagePreviewView -> ProcessingView -> ResultsView
        // We need to pop 3 times to get back to AnalyzeCatView
        dismiss() // Pop ProcessingView
        
        // Use a small delay to ensure each dismiss completes before the next
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            dismiss() // Pop ImagePreviewView
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                dismiss() // Pop CameraView, leaving us at AnalyzeCatView
            }
        }
    }
}

// MARK: - Results Header
struct ResultsHeaderView: View {
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: onBack) {
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
                
                Text("Results")
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

// MARK: - Cat Image with Landmarks
struct CatImageWithLandmarksView: View {
    let image: UIImage
    let landmarks: [(x: Double, y: Double)]
    
    var body: some View {
        let imageSize = UIScreen.main.bounds.width - 40
        let imageAspectRatio = image.size.width / image.size.height
        let displayAspectRatio: CGFloat = 1.0 // Square display
        
        ZStack {
            // Cat Image - use .fit to show entire image without cropping
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize, height: imageSize)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.borderColor, lineWidth: 0.5)
                )
            
            // Landmarks Overlay
            GeometryReader { geometry in
                Canvas { context, size in
                    // Calculate how the image is actually displayed with .fit
                    // Image maintains aspect ratio and is centered
                    let imageAspect = image.size.width / image.size.height
                    let displayAspect: CGFloat = 1.0 // Square display
                    
                    var scaleX: CGFloat
                    var scaleY: CGFloat
                    var offsetX: CGFloat = 0
                    var offsetY: CGFloat = 0
                    
                    if imageAspect > displayAspect {
                        // Image is wider - will have padding on top/bottom
                        scaleX = size.width / image.size.width
                        scaleY = scaleX // Same scale for both (maintains aspect ratio)
                        let scaledHeight = image.size.height * scaleY
                        offsetY = (size.height - scaledHeight) / 2.0
                    } else {
                        // Image is taller - will have padding on sides
                        scaleY = size.height / image.size.height
                        scaleX = scaleY // Same scale for both (maintains aspect ratio)
                        let scaledWidth = image.size.width * scaleX
                        offsetX = (size.width - scaledWidth) / 2.0
                    }
                    
                    // Draw red dots for each landmark
                    for landmark in landmarks {
                        let x = CGFloat(landmark.x) * scaleX + offsetX
                        let y = CGFloat(landmark.y) * scaleY + offsetY
                        
                        // Draw red circle
                        var path = Path()
                        path.addEllipse(in: CGRect(
                            x: x - 3,
                            y: y - 3,
                            width: 6,
                            height: 6
                        ))
                        context.fill(path, with: .color(.red))
                    }
                }
            }
            .frame(width: imageSize, height: imageSize)
        }
    }
}

// MARK: - Disclaimer View
struct DisclaimerView: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("AI results may vary.")
                .font(.poppins(.regular, size: 12))
                .foregroundColor(.textSecondary)
            
            Button(action: {
                // TODO: Handle feedback
                print("Send feedback tapped")
            }) {
                Text("Send feedback")
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Pain Score Card
struct PainScoreCardView: View {
    let catName: String
    let eyeScore: Int
    let earScore: Int
    let muzzleScore: Int
    
    // Calculate overall pain score (0-6 scale)
    private var overallScore: Int {
        let scores = [eyeScore, earScore, muzzleScore].filter { $0 >= 0 }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +)
    }
    
    // Background color based on overall score
    private var backgroundColor: Color {
        switch overallScore {
        case 0...2:
            return Color(red: 0.20, green: 0.50, blue: 0.30) // Dark green
        case 3...4:
            return Color(red: 0.95, green: 0.55, blue: 0.45) // Coral
        default: // 5+
            return Color(red: 0.70, green: 0.20, blue: 0.20) // Red
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with cat name and date
            HStack {
                // Cat profile
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.catImageBackground)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.textLight, lineWidth: 1)
                        )
                    
                    Text(catName)
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(.textLight)
                }
                
                Spacer()
                
                // Date
                Text(dateString)
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.textLight.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Pain Score Circle
            VStack(spacing: 8) {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.textLight.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: CGFloat(overallScore) / 6.0)
                        .stroke(Color.textLight, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    // Score text
                    VStack(spacing: 4) {
                        Text("\(overallScore)/6")
                            .font(.poppins(.bold, size: 24))
                            .foregroundColor(.textLight)
                        
                        Text("Pain Score")
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(.textLight.opacity(0.8))
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .background(backgroundColor)
        .cornerRadius(16)
    }
}

// MARK: - Pain Score Display (Read-Only)
struct PainScoreDisplayView: View {
    let title: String
    let score: Int
    
    // Color based on score severity
    private var color: Color {
        switch score {
        case 0:
            return Color(red: 0.20, green: 0.50, blue: 0.30) // Dark green
        case 1:
            return Color(red: 0.95, green: 0.55, blue: 0.45) // Coral
        case 2:
            return Color(red: 0.70, green: 0.20, blue: 0.20) // Red
        default:
            return Color.gray // Fallback for invalid scores
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.poppins(.semiBold, size: 14))
                .foregroundColor(.textPrimary)
            
            // Score display with markers
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Slider track (visual only)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                    
                    // Markers (dots at positions 0, 1, 2)
                    HStack(spacing: 0) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                            
                            if index < 2 {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    
                    // Score indicator (read-only)
                    HStack {
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("\(score)")
                                    .font(.poppins(.bold, size: 14))
                                    .foregroundColor(.textLight)
                            )
                            .offset(x: CGFloat(score) * max(0, (geometry.size.width - 32) / 2.0))
                        
                        Spacer()
                    }
                }
            }
            .frame(height: 32)
            
            // Chevron button (for future expansion)
            HStack {
                Spacer()
                Button(action: {
                    // TODO: Expand for more details
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }
        }
    }
}

// MARK: - Notes Section
struct NotesSectionView: View {
    @Binding var notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTES")
                .font(.poppins(.semiBold, size: 14))
                .foregroundColor(.textPrimary)
            
            TextEditor(text: $notes)
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.textPrimary)
                .frame(height: 120)
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.borderColor, lineWidth: 0.5)
                )
                .overlay(
                    Group {
                        if notes.isEmpty {
                            VStack {
                                HStack {
                                    Text("Additional Notes")
                                        .font(.poppins(.regular, size: 14))
                                        .foregroundColor(.textSecondary.opacity(0.5))
                                        .padding(.leading, 16)
                                        .padding(.top, 20)
                                    Spacer()
                                }
                                Spacer()
                            }
                        }
                    }
                )
        }
    }
}

// MARK: - Save Entry Button
struct SaveEntryButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Save Entry")
                .font(.poppins(.semiBold, size: 16))
                .foregroundColor(.textLight)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(red: 0.95, green: 0.55, blue: 0.45)) // Orange/coral
                .cornerRadius(12)
        }
        .padding(.top, 8)
    }
}

// MARK: - Results Bottom Navigation
struct ResultsBottomNavigationView: View {
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

// MARK: - Preview
struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ResultsView(
                catName: "boba",
                capturedImage: UIImage(systemName: "photo")!,
                landmarks: [
                    (x: 100, y: 100), (x: 150, y: 100), (x: 200, y: 100),
                    (x: 100, y: 150), (x: 150, y: 150), (x: 200, y: 150)
                ],
                painScores: (eye: 0, ear: 1, muzzle: 2)
            )
        }
    }
}

