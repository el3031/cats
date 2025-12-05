import SwiftUI

// MARK: - Image Preview View
struct ImagePreviewView: View {
    let catName: String
    let capturedImage: UIImage
    @Environment(\.dismiss) var dismiss
    @State private var showCamera = false
    @State private var showProcessing = false
    @State private var showComingSoonPopup = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section (outside ScrollView so background extends to top)
            ImagePreviewHeaderView()
            
            // Scrollable Content
            ScrollView {
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
                            showProcessing = true
                        },
                        onRetake: {
                            dismiss()
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for bottom nav
                }
            }
            .background(Color.appBackground)
        }
        .safeAreaInset(edge: .bottom) {
            ImagePreviewBottomNavigationView(onProfileTap: {
                showComingSoonPopup = true
            })
        }
        .navigationBarBackButtonHidden(true)
        .overlay {
            if showComingSoonPopup {
                ComingSoonPopupView(onClose: {
                    showComingSoonPopup = false
                })
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .navigationDestination(isPresented: $showProcessing) {
            ProcessingView(catName: catName, capturedImage: capturedImage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissProcessingView"))) { _ in
            // When ResultsView wants to go back, dismiss ProcessingView
            showProcessing = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToHome"))) { _ in
            // Dismiss when navigating to home
            showProcessing = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dismiss()
            }
        }
    }
}

// MARK: - Image Preview Header
struct ImagePreviewHeaderView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button and title on same row
            HStack {
                Button(action: { dismiss() }) {
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
                    
                    Text("Image Preview")
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

