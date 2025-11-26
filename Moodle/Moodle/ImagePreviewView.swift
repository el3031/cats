import SwiftUI

// MARK: - Image Preview View
struct ImagePreviewView: View {
    let catName: String
    let capturedImage: UIImage
    @Environment(\.dismiss) var dismiss
    @State private var showCamera = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Section
                ImagePreviewHeaderView()
                
                // Main Content
                VStack(spacing: 20) {
                    // Great Photo Box
                    GreatPhotoBoxView()
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Image Preview
                    ImagePreviewSection(image: capturedImage)
                        .padding(.horizontal, 20)
                    
                    // Action Buttons
                    ImagePreviewActionButtonsView(
                        onContinue: {
                            // Navigate to analysis screen
                        },
                        onRetake: {
                            dismiss()
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for bottom nav
                }
            }
        }
        .background(Color.appBackground)
        .safeAreaInset(edge: .bottom) {
            ImagePreviewBottomNavigationView()
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Image Preview Header
struct ImagePreviewHeaderView: View {
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
                
                Text("Image Preview")
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

// MARK: - Great Photo Box
struct GreatPhotoBoxView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Great Photo!")
                .font(.poppins(.bold, size: 20))
                .foregroundColor(.textPrimary)
            
            Text("Does your photo meet the following requirements?")
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.textPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                InstructionBullet(text: "Shows one cat only (no other cats in frame)")
                InstructionBullet(text: "Shows the whole face")
                InstructionBullet(text: "Has good lighting")
                InstructionBullet(text: "Shows the cat in the center of the screen")
            }
        }
        .padding(20)
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Image Preview Section
struct ImagePreviewSection: View {
    let image: UIImage
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.width - 40)
            .clipped()
            .cornerRadius(12)
    }
}

// MARK: - Image Preview Action Buttons
struct ImagePreviewActionButtonsView: View {
    let onContinue: () -> Void
    let onRetake: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Continue With Photo Button
            Button(action: onContinue) {
                Text("Continue With Photo")
                    .font(.poppins(.semiBold, size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 1.0, green: 0.4, blue: 0.2)) // Orange-red
                    .cornerRadius(8)
            }
            
            // Retake Photo Button
            Button(action: onRetake) {
                Text("Retake Photo")
                    .font(.poppins(.medium, size: 16))
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Image Preview Bottom Navigation
struct ImagePreviewBottomNavigationView: View {
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
struct ImagePreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ImagePreviewView(
                catName: "noodle",
                capturedImage: UIImage(systemName: "photo")!
            )
        }
    }
}

