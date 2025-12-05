import SwiftUI

// MARK: - Analyze Cat View
struct AnalyzeCatView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showCamera = false
    @State private var selectedCatName = ""
    @State private var uniqueCats: [Cat] = []
    @State private var showComingSoonPopup = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private var cardWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding: CGFloat = 20 * 2 // Left and right padding
        let spacing: CGFloat = 16 // Spacing between columns
        return (screenWidth - horizontalPadding - spacing) / 2
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section (outside ScrollView so background extends to top)
            AnalyzeCatHeaderView()
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 20) {
                    // Warning Box
                    WarningBoxView()
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Cat Selection Cards
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(uniqueCats) { cat in
                            AnalyzeCatCard(name: cat.name, cardWidth: cardWidth) {
                                selectedCatName = cat.name
                                showCamera = true
                            }
                        }
                        
                        AddCatButtonCard(cardWidth: cardWidth)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100) // Space for bottom nav
                }
            }
            .background(Color.appBackground)
        }
        .safeAreaInset(edge: .bottom) {
            AnalyzeCatBottomNavigationView(onProfileTap: {
                showComingSoonPopup = true
            })
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showCamera) {
            CameraView(catName: selectedCatName)
        }
        .onAppear {
            loadUniqueCats()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToHome"))) { _ in
            // Dismiss when navigating to home
            showCamera = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dismiss()
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
    }
    
    private func loadUniqueCats() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ ERROR: Could not access documents directory")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("pain_analysis_entries.json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ℹ️  No pain analysis entries file found for loading cats")
            uniqueCats = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            
            // Create a set of unique cat names
            var uniqueCatNames = Set<String>()
            for jsonDict in jsonArray {
                if let catName = jsonDict["catName"] as? String {
                    uniqueCatNames.insert(catName)
                }
            }
            
            // For each unique cat, create a Cat object
            var cats: [Cat] = []
            for catName in uniqueCatNames.sorted() {
                cats.append(Cat(name: catName, imagePath: nil))
            }
            
            uniqueCats = cats
            print("✅ Loaded \(uniqueCats.count) unique cats for AnalyzeCatView")
        } catch {
            print("❌ ERROR: Failed to load unique cats: \(error.localizedDescription)")
            uniqueCats = []
        }
    }
}

// MARK: - Analyze Cat Header
struct AnalyzeCatHeaderView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textLight)
                        .padding(8)
                }
                
                Spacer()
                
                Text("Analyze Cat")
                    .font(.poppins(.bold, size: 28))
                    .foregroundColor(.textLight)
                
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

// MARK: - Warning Box
struct WarningBoxView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Warning Header
            HStack(spacing: 8) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                Text("Note: This tool cannot replace a vet evaluation!")
                    .font(.poppins(.medium, size: 14))
                    .foregroundColor(.orange)
            }
            
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Upload an image of your cat and make sure it:")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(.textPrimary)
                
                VStack(alignment: .leading, spacing: 6) {
                    InstructionBullet(text: "Shows one cat only (no other cats in frame)")
                    InstructionBullet(text: "Shows the whole face")
                    InstructionBullet(text: "Has good lighting")
                    InstructionBullet(text: "Shows the cat in the center of the screen")
                }
            }
        }
        .padding(16)
        .background(Color.appBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange, lineWidth: 1)
        )
    }
}

// MARK: - Instruction Bullet
struct InstructionBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.textPrimary)
            
            Text(text)
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.textPrimary)
        }
    }
}

// MARK: - Analyze Cat Card
struct AnalyzeCatCard: View {
    let name: String
    let cardWidth: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Profile Picture - using CatImageCircle from ContentView
                CatImageCircle(imagePath: nil, size: 120, catName: name)
                    .overlay(
                        Circle()
                            .stroke(Color.textLight.opacity(0.3), lineWidth: 1)
                    )
                
                // Name
                Text(name.capitalized)
                    .font(.poppins(.semiBold, size: 18))
                    .foregroundColor(.textLight)
            }
            .frame(width: cardWidth, height: cardWidth) // Make it square
            .padding(.vertical, 20)
            .background(Color.headerBackground)
            .cornerRadius(12)
        }
    }
}

// MARK: - Add Cat Button Card
struct AddCatButtonCard: View {
    let cardWidth: CGFloat
    
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 12) {
                // Plus Icon
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.gray)
                }
                
                // Label
                Text("Add Cat")
                    .font(.poppins(.medium, size: 16))
                    .foregroundColor(.textPrimary)
            }
            .frame(width: cardWidth, height: cardWidth) // Make it square
            .padding(.vertical, 20)
            .background(Color.appBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Analyze Cat Bottom Navigation
struct AnalyzeCatBottomNavigationView: View {
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
                NavButtonWithCustomCameraIcon(isSelected: true, action: {
                    // Already on AnalyzeCatView, do nothing
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


// MARK: - Preview
struct AnalyzeCatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AnalyzeCatView()
        }
    }
}

