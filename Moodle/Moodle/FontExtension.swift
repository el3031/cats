import SwiftUI
import UIKit
import CoreText

// MARK: - Poppins Font Extension
extension Font {
    static func poppins(_ style: PoppinsStyle = .regular, size: CGFloat) -> Font {
        let fontName = style.postScriptName
        
        // Try to load font if not already registered
        if UIFont(name: fontName, size: size) == nil {
            // Attempt to register font from bundle
            if let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf"),
               let fontData = try? Data(contentsOf: fontURL),
               let provider = CGDataProvider(data: fontData as CFData),
               let font = CGFont(provider) {
                var error: Unmanaged<CFError>?
                if !CTFontManagerRegisterGraphicsFont(font, &error) {
                    #if DEBUG
                    if let error = error?.takeRetainedValue() {
                        print("Failed to register font \(fontName): \(error)")
                    }
                    #endif
                }
            }
        }
        
        // Verify font is available, fallback to system font if not
        if UIFont(name: fontName, size: size) != nil {
            return Font.custom(fontName, size: size)
        } else {
            // Fallback: try using family name with weight
            return Font.system(size: size, weight: style.systemWeight)
        }
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
    
    var postScriptName: String {
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
    
    var systemWeight: Font.Weight {
        switch self {
        case .thin: return .thin
        case .extraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semiBold: return .semibold
        case .bold: return .bold
        case .extraBold: return .heavy
        case .black: return .black
        }
    }
}

// MARK: - Convenience Font Modifiers
extension View {
    func poppins(_ style: PoppinsStyle = .regular, size: CGFloat) -> some View {
        self.font(.poppins(style, size: size))
    }
}

