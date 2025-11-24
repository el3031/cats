import SwiftUI

// MARK: - Poppins Font Extension
extension Font {
    static func poppins(_ style: PoppinsStyle = .regular, size: CGFloat) -> Font {
        return Font.custom(style.fontName, size: size)
    }
}

enum PoppinsStyle {
    case thin
    case extraLight
    case light
    case regular
    case medium
    case semiBold
    case bold
    case extraBold
    case black
    
    var fontName: String {
        switch self {
        case .thin: return "Poppins-Thin"
        case .extraLight: return "Poppins-ExtraLight"
        case .light: return "Poppins-Light"
        case .regular: return "Poppins-Regular"
        case .medium: return "Poppins-Medium"
        case .semiBold: return "Poppins-SemiBold"
        case .bold: return "Poppins-Bold"
        case .extraBold: return "Poppins-ExtraBold"
        case .black: return "Poppins-Black"
        }
    }
}

// MARK: - Convenience Font Modifiers
extension View {
    func poppins(_ style: PoppinsStyle = .regular, size: CGFloat) -> some View {
        self.font(.poppins(style, size: size))
    }
}

