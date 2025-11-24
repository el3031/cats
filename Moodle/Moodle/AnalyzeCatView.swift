import SwiftUI

// MARK: - Analyze Cat View
struct AnalyzeCatView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showCamera = false
    @State private var selectedCatName = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Section
                AnalyzeCatHeaderView()
                
                // Main Content
                VStack(spacing: 20) {
                    // Warning Box
                    WarningBoxView()
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Cat Selection Cards
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            AnalyzeCatCard(name: "noodle") {
                                selectedCatName = "noodle"
                                showCamera = true
                            }
                            AnalyzeCatCard(name: "boba") {
                                selectedCatName = "boba"
                                showCamera = true
                            }
                        }
                        
                        AddCatButtonCard()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100) // Space for bottom nav
                }
            }
        }
        .background(Color.appBackground)
        .safeAreaInset(edge: .bottom) {
            AnalyzeCatBottomNavigationView()
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showCamera) {
            CameraView(catName: selectedCatName)
        }
    }
}

// MARK: - Analyze Cat Header
struct AnalyzeCatHeaderView: View {
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
                
                Text("Select Cat")
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Profile Picture
                Circle()
                    .fill(Color.catImageBackground)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(Color.textLight.opacity(0.3), lineWidth: 1)
                    )
                
                // Name
                Text(name)
                    .font(.poppins(.semiBold, size: 18))
                    .foregroundColor(.textLight)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.headerBackground)
            .cornerRadius(12)
        }
    }
}

// MARK: - Add Cat Button Card
struct AddCatButtonCard: View {
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 12) {
                // Plus Icon
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.gray)
                }
                
                // Label
                Text("Add Cat")
                    .font(.poppins(.medium, size: 16))
                    .foregroundColor(.textPrimary)
            }
            .frame(maxWidth: .infinity)
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
struct AnalyzeCatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AnalyzeCatView()
        }
    }
}

