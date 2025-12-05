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
    @State private var isKeyboardVisible = false
    @State private var showComingSoonPopup = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (outside ScrollView so background extends to top)
            ResultsHeaderView(onBack: {
                // Pop back to ImagePreviewView by dismissing twice
                // Navigation stack: ... -> ImagePreviewView -> ProcessingView -> ResultsView
                // We need to pop 2 times to get back to ImagePreviewView
                popToImagePreviewView()
            })
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 20) {
                    // Cat Image with Landmarks
                    CatImageWithLandmarksView(image: capturedImage, landmarks: landmarks)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .onTapGesture {
                            dismissKeyboard()
                        }
                    
                    // Disclaimer
                    DisclaimerView()
                        .padding(.horizontal, 20)
                        .onTapGesture {
                            dismissKeyboard()
                        }
                    
                    // Pain Score Card
                    PainScoreCardView(
                        catName: catName,
                        eyeScore: painScores.eye,
                        earScore: painScores.ear,
                        muzzleScore: painScores.muzzle
                    )
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    
                    // EYES Score Display
                    PainScoreDisplayView(
                        title: "EYES",
                        score: painScores.eye
                    )
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    
                    // EARS Score Display
                    PainScoreDisplayView(
                        title: "EARS",
                        score: painScores.ear
                    )
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    
                    // MUZZLE Score Display
                    PainScoreDisplayView(
                        title: "MUZZLE",
                        score: painScores.muzzle
                    )
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    
                    // NOTES Section
                    NotesSectionView(notes: $notes)
                        .padding(.horizontal, 20)
                    
                    // Save Entry Button
                    SaveEntryButton {
                        saveEntry()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for bottom nav
                    .onTapGesture {
                        dismissKeyboard()
                    }
                }
            }
            .background(Color.appBackground)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // Dismiss keyboard on downward drag
                    if value.translation.height > 50 {
                        dismissKeyboard()
                    }
                }
        )
        .safeAreaInset(edge: .bottom) {
            if !isKeyboardVisible {
                ResultsBottomNavigationView(onProfileTap: {
                    showComingSoonPopup = true
                })
            }
        }
        .navigationBarBackButtonHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = false
            }
        }
        .overlay {
            if showComingSoonPopup {
                ComingSoonPopupView(onClose: {
                    showComingSoonPopup = false
                })
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .overlay {
            // Success Popup
            if showSaveConfirmation {
                SuccessPopupView(onClose: {
                    popToContentView()
                })
                .transition(.opacity)
                .zIndex(1000)
            }
            
            // Coming Soon Popup
            if showComingSoonPopup {
                ComingSoonPopupView(onClose: {
                    showComingSoonPopup = false
                })
                .transition(.opacity)
                .zIndex(1001)
            }
        }
    }
    
    private func dismissKeyboard() {
        // Dismiss keyboard by resigning first responder
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func saveEntry() {
        // Calculate overall score
        let overallScore = painScores.eye + painScores.ear + painScores.muzzle
        
        // Create date formatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateTimeString = dateFormatter.string(from: Date())
        
        // Get documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ ERROR: Could not access documents directory")
            return
        }
        
        // Save the image and get the path
        var imagePath: String? = nil
        let imagesDirectory = documentsDirectory.appendingPathComponent("cat_images")
        
        // Create images directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
        
        // Save the image with a unique filename
        let imageFilename = "\(catName)_\(dateTimeString.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: ":", with: "-")).jpg"
        let imageURL = imagesDirectory.appendingPathComponent(imageFilename)
        
        if let imageData = capturedImage.jpegData(compressionQuality: 0.8) {
            do {
                try imageData.write(to: imageURL)
                imagePath = "cat_images/\(imageFilename)"
                print("✅ Saved cat image to: \(imagePath ?? "unknown")")
            } catch {
                print("⚠️  WARNING: Could not save cat image: \(error.localizedDescription)")
            }
        }
        
        // Create new entry
        var newEntry: [String: Any] = [
            "catName": catName,
            "dateTime": dateTimeString,
            "overallScore": overallScore,
            "scoreBreakdown": [
                "eye": painScores.eye,
                "ear": painScores.ear,
                "muzzle": painScores.muzzle
            ],
            "notes": notes
        ]
        
        if let imagePath = imagePath {
            newEntry["imagePath"] = imagePath
        }
        
        // Use a single JSON file for all entries
        let fileURL = documentsDirectory.appendingPathComponent("pain_analysis_entries.json")
        
        // Read existing entries or create new array
        var entries: [[String: Any]] = []
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // File exists, read and parse it
            do {
                let data = try Data(contentsOf: fileURL)
                if let parsedEntries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    entries = parsedEntries
                } else if let singleEntry = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Handle case where file contains a single entry object instead of array
                    entries = [singleEntry]
                }
            } catch {
                print("⚠️  WARNING: Could not read existing entries file: \(error.localizedDescription)")
                print("   Creating new entries file...")
            }
        }
        
        // Append new entry
        entries.append(newEntry)
        
        // Convert to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: entries, options: .prettyPrinted) else {
            print("❌ ERROR: Failed to serialize JSON data")
            return
        }
        
        // Write updated entries back to file
        do {
            try jsonData.write(to: fileURL)
            print("✅ Entry saved successfully to: \(fileURL.path)")
            print("💾 Saved entry:")
            print("   Cat: \(catName)")
            print("   Date/Time: \(dateTimeString)")
            print("   Overall Score: \(overallScore)")
            print("   Eye: \(painScores.eye), Ear: \(painScores.ear), Muzzle: \(painScores.muzzle)")
            print("   Notes: \(notes.isEmpty ? "(none)" : notes)")
            print("   Total entries in file: \(entries.count)")
            
            showSaveConfirmation = true
        } catch {
            print("❌ ERROR: Failed to write JSON file: \(error.localizedDescription)")
        }
    }
    
    private func popToImagePreviewView() {
        // Pop back to ImagePreviewView by dismissing twice
        // Navigation stack: ... -> ImagePreviewView -> ProcessingView -> ResultsView
        // We need to pop both ResultsView and ProcessingView
        // First dismiss ResultsView, then notify ImagePreviewView to dismiss ProcessingView
        dismiss() // Dismiss ResultsView
        
        // Notify ImagePreviewView to dismiss ProcessingView
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NSNotification.Name("DismissProcessingView"), object: nil)
        }
    }
    
    private func popToContentView() {
        // Pop all the way back to ContentView (home page)
        // Navigation stack: ContentView -> AnalyzeCatView -> CameraView -> ImagePreviewView -> ProcessingView -> ResultsView
        // Use notification to tell ContentView to reset navigation first
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToHome"), object: nil)
        
        // Then dismiss ResultsView - the notification will handle resetting ContentView's navigation state
        // We only need to dismiss ResultsView, and let the navigation stack handle the rest
        dismiss()
    }
}

// MARK: - Results Header
struct ResultsHeaderView: View {
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button and title on same row
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textLight)
                        .padding(8)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Analyze Cat")
                        .font(.poppins(.bold, size: 28))
                        .foregroundColor(.textLight)
                    
                    Text("Results")
                        .font(.poppins(.regular, size: 16))
                        .foregroundColor(.textLight)
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                // Invisible spacer to balance the back button
                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(
            Color.headerBackground
                .ignoresSafeArea(edges: .top)
        )
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
                    CatImageCircle(imagePath: nil, size: 32, catName: catName)
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
    @State private var isExpanded = false
    
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
    
    // Content based on title
    private var whatItMeasuresText: String {
        switch title.uppercased() {
        case "EYES":
            return "The vertical gap between eyelids. Cats in pain often squint, making this a key indicator to distinguish discomfort from normal rest."
        case "EARS":
            return "The position and rotation of the ears. Cats in pain often pull their ears apart and rotate them outward."
        case "MUZZLE":
            return "The shape and tension of the muzzle. Cats in pain display a tense, elongated muzzle rather than their normal rounded shape."
        default:
            return ""
        }
    }
    
    private var score0Text: String {
        switch title.uppercased() {
        case "EYES":
            return "Eyes round and open. The eyelid opening is about 80% of the eye's width."
        case "EARS":
            return "Ears facing forward in a relaxed, alert position."
        case "MUZZLE":
            return "Muzzle relaxed and round."
        default:
            return ""
        }
    }
    
    private var score1Text: String {
        switch title.uppercased() {
        case "EYES":
            return "Slightly narrowed. The eyelid opening is roughly half the eye's width."
        case "EARS":
            return "Ears slightly pulled apart with minor outward rotation."
        case "MUZZLE":
            return "Muzzle shows mild tension. The shape is slightly elongated or less rounded."
        default:
            return ""
        }
    }
    
    private var score2Text: String {
        switch title.uppercased() {
        case "EYES":
            return "Quite narrow or squinted. The eyelid opening is noticeably less than half the eye's width."
        case "EARS":
            return "Ears noticeably rotated outwards and pulled apart, often flattened to the sides."
        case "MUZZLE":
            return "Muzzle tense and elliptical instead of round."
        default:
            return ""
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.poppins(.semiBold, size: 14))
                .foregroundColor(.textPrimary)
            
            // Container with white background and rounded rectangle (full width)
            VStack(spacing: 0) {
                // Header row with score indicator and chevron
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 12) {
                        // Score display with dots and line (takes up about half the screen width, left-aligned)
                        ZStack(alignment: .leading) {
                            // Horizontal line connecting the dots
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                                .frame(maxWidth: .infinity)
                            
                            // Dots at positions 0, 1, 2
                            HStack(spacing: 0) {
                                ForEach(0..<3) { index in
                                    // Dot for each score position
                                    ZStack {
                                        Circle()
                                            .fill(index == score ? color : Color.gray.opacity(0.3))
                                            .frame(width: index == score ? 40 : 32, height: index == score ? 40 : 32)
                                        
                                        if index == score {
                                            Text("\(score)")
                                                .font(.poppins(.bold, size: 16))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    
                                    if index < 2 {
                                        Spacer()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(width: UIScreen.main.bounds.width * 0.5) // About half the screen width
                        .frame(height: 32)
                        
                        Spacer()
                        
                        // Chevron icon on the right side
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Dropdown content (inside the white box)
                if isExpanded {
                    VStack(alignment: .leading, spacing: 20) {
                        // WHAT IT MEASURES section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WHAT IT MEASURES:")
                                .font(.poppins(.bold, size: 14))
                                .foregroundColor(.textPrimary)
                            
                            Text(whatItMeasuresText)
                                .font(.poppins(.regular, size: 14))
                                .foregroundColor(.textPrimary)
                        }
                        
                        // SCORE MEANINGS section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SCORE MEANINGS:")
                                .font(.poppins(.bold, size: 14))
                                .foregroundColor(.textPrimary)
                            
                            // Score 0
                            VStack(alignment: .leading, spacing: 4) {
                                Text("0 - Healthy")
                                    .font(.poppins(.bold, size: 14))
                                    .foregroundColor(.textPrimary)
                                Text(score0Text)
                                    .font(.poppins(.regular, size: 14))
                                    .foregroundColor(.textPrimary)
                            }
                            
                            // Score 1
                            VStack(alignment: .leading, spacing: 4) {
                                Text("1 - Monitor")
                                    .font(.poppins(.bold, size: 14))
                                    .foregroundColor(.textPrimary)
                                Text(score1Text)
                                    .font(.poppins(.regular, size: 14))
                                    .foregroundColor(.textPrimary)
                            }
                            
                            // Score 2
                            VStack(alignment: .leading, spacing: 4) {
                                Text("2 - Concern")
                                    .font(.poppins(.bold, size: 14))
                                    .foregroundColor(.textPrimary)
                                Text(score2Text)
                                    .font(.poppins(.regular, size: 14))
                                    .foregroundColor(.textPrimary)
                            }
                        }
                        
                        // Note
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Note:")
                                .font(.poppins(.bold, size: 14))
                                .foregroundColor(.textPrimary)
                            Text("Consult a vet if score is 2 or symptoms worsen.")
                                .font(.poppins(.regular, size: 14))
                                .foregroundColor(.textPrimary)
                                .italic()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderColor, lineWidth: 0.5)
            )
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
                .scrollContentBackground(.hidden)
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
    let onProfileTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Items
            HStack {
                NavButtonWithCustomIcon(isSelected: false, action: {
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToHome"), object: nil)
                })
                NavButtonWithCustomSearchIconOutline(isSelected: false, action: {
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToSearch"), object: nil)
                })
                NavButtonWithCustomCameraIcon(isSelected: false, action: {
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToAnalyzeCat"), object: nil)
                })
                NavButtonWithCustomCalendarIcon(isSelected: false, action: {
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToCalendar"), object: nil)
                })
                NavButtonWithCustomProfileIcon(action: onProfileTap)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.appBackground)
        .shadow(color: Color.borderColor, radius: 0)
    }
}

// MARK: - Success Popup View
struct SuccessPopupView: View {
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            // Popup Card
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    // X button in top right
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Green checkmark circle
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.20, green: 0.50, blue: 0.30)) // Dark green
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 8)
                    
                    // Success text
                    VStack(spacing: 8) {
                        Text("Success!")
                            .font(.poppins(.bold, size: 24))
                            .foregroundColor(.textPrimary)
                        
                        Text("Entry Saved")
                            .font(.poppins(.regular, size: 16))
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
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

