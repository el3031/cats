import SwiftUI

// MARK: - Color Extensions
extension Color {
    static let appBackground = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let headerBackground = Color(red: 0.46, green: 0.54, blue: 0.51)
    static let textPrimary = Color(red: 0.12, green: 0.14, blue: 0.12)
    static let textSecondary = Color(red: 0.27, green: 0.27, blue: 0.27)
    static let textLight = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let catImageBackground = Color(red: 0.50, green: 0.23, blue: 0.27).opacity(0.50)
    static let buttonPrimary = Color(red: 0.29, green: 0.35, blue: 0.29)
    static let borderColor = Color(red: 0.65, green: 0.65, blue: 0.67)
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var showAnalyzeCat = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    HeaderView()
                    
                    // Main Content
                    VStack(spacing: 20) {
                        // Section Title
                        SectionHeaderView(title: "Latest Pain Analysis", action: "See All")
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        // Action Buttons
                        ActionButtonsView(showAnalyzeCat: $showAnalyzeCat)
                            .padding(.horizontal, 20)
                        
                        // Pain Analysis Cards
                        PainAnalysisCard(catName: "noodle", date: "9 Oct 2025, 12:18")
                            .padding(.horizontal, 20)
                        
                        PainAnalysisCard(catName: "boba", date: "8 Oct 2025, 19:18")
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100) // Space for bottom nav
                    }
                }
            }
            .background(Color.appBackground)
            .safeAreaInset(edge: .bottom) {
                BottomNavigationView()
            }
            .navigationDestination(isPresented: $showAnalyzeCat) {
                AnalyzeCatView()
            }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                // Welcome Text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back, John!")
                        .font(.poppins(.bold, size: 20))
                        .foregroundColor(.textLight)
                    
                    Text("How are your cats doing today?")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.textLight.opacity(0.75))
                }
                
                Spacer()
                
                // Profile Button
                Button(action: {}) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.textLight)
                }
                .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Cat Cards
            HStack(spacing: 30) {
                CatCard(name: "noodle")
                CatCard(name: "boba")
                AddCatCard()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .background(Color.headerBackground)
    }
}

// MARK: - Cat Card Component
struct CatCard: View {
    let name: String
    
    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.catImageBackground)
                .frame(width: 68, height: 68)
                .overlay(
                    Circle()
                        .stroke(Color.textLight, lineWidth: 1)
                )
            
            Text(name)
                .font(.poppins(.semiBold, size: 18))
                .foregroundColor(.textLight)
        }
        .frame(width: 77)
    }
}

// MARK: - Add Cat Card
struct AddCatCard: View {
    var body: some View {
        VStack(spacing: 7) {
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 24))
                    .foregroundColor(.textLight)
                    .frame(width: 68, height: 68)
                    .background(Color.textLight.opacity(0.75))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.textLight.opacity(0.50), lineWidth: 0.5)
                    )
            }
            
            Text("Add Cat")
                .font(.poppins(.regular, size: 16))
                .foregroundColor(.textLight)
        }
        .frame(width: 71)
    }
}

// MARK: - Section Header
struct SectionHeaderView: View {
    let title: String
    let action: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.poppins(.semiBold, size: 18))
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Button(action: {}) {
                Text(action)
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(.textPrimary)
            }
        }
    }
}

// MARK: - Pressable Button Style
struct PressableButtonStyle: ButtonStyle {
    var backgroundColor: Color
    var pressedColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? pressedColor : backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderColor.opacity(0.50), lineWidth: 1)
            )
    }
}

// MARK: - Action Buttons
struct ActionButtonsView: View {
    @Binding var showAnalyzeCat: Bool
    
    var body: some View {
        HStack(spacing: 9) {
            // Analyze Cat Button
            Button(action: { showAnalyzeCat = true }) {
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.textLight)
                        .frame(width: 40, height: 40)
                    
                    Text("Analyze Cat")
                        .font(.poppins(.medium, size: 16))
                        .foregroundColor(.textLight)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 110)
            }
            .buttonStyle(PressableButtonStyle(
                backgroundColor: Color.buttonPrimary,
                pressedColor: Color.buttonPrimary.opacity(0.7)
            ))
            
            // Past Records Button
            Button(action: {}) {
                VStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.textPrimary)
                        .frame(width: 40, height: 40)
                    
                    Text("Past Records")
                        .font(.poppins(.medium, size: 16))
                        .foregroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .background(Color.appBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.textPrimary.opacity(0.50), lineWidth: 0.25)
                )
            }
        }
    }
}

// MARK: - Pain Analysis Card
struct PainAnalysisCard: View {
    let catName: String
    let date: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.catImageBackground)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.borderColor, lineWidth: 0.25)
                        )
                    
                    Text(catName)
                        .font(.poppins(.medium, size: 14))
                        .foregroundColor(.textPrimary)
                }
                
                Spacer()
                
                Text(date)
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            
            // Image Placeholder
            Rectangle()
                .fill(Color.catImageBackground)
                .frame(width: 104, height: 104)
                .cornerRadius(8)
                .padding(.top, 14)
            
            // View Details Button
            Button(action: {}) {
                HStack(spacing: 64) {
                    Text("View Details")
                        .font(.poppins(.medium, size: 12))
                        .foregroundColor(.textPrimary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .padding(.horizontal, 14)
            }
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
        .background(Color.appBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.borderColor, lineWidth: 0.25)
        )
    }
}

// MARK: - Bottom Navigation
struct BottomNavigationView: View {
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
                NavButton(icon: "house.fill", isSelected: false)
                NavButton(icon: "chart.bar.fill", isSelected: false)
                NavButton(icon: "plus.circle.fill", isSelected: true, size: 40)
                NavButton(icon: "clock.fill", isSelected: false)
                NavButton(icon: "person.fill", isSelected: false)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.appBackground)
        .shadow(color: Color.borderColor, radius: 0)
    }
}

// MARK: - Navigation Button
struct NavButton: View {
    let icon: String
    let isSelected: Bool
    var size: CGFloat = 24
    var highlightColor: Color = Color.textPrimary
    
    var body: some View {
        Button(action: {}) {
            if isSelected {
                ZStack {
                    Circle()
                        .fill(highlightColor)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: size))
                        .foregroundColor(.textLight)
                }
            } else {
                Image(systemName: icon)
                    .font(.system(size: size))
                    .foregroundColor(.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

