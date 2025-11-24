import SwiftUI
import UIKit

// Helper to debug and list available fonts
struct FontHelper {
    static func listAvailableFonts() {
        print("\n=== Checking for Poppins Fonts ===")
        
        // Check if fonts are in the bundle
        let fontFiles = [
            "Poppins-Regular.ttf",
            "Poppins-Bold.ttf",
            "Poppins-Medium.ttf",
            "Poppins-SemiBold.ttf"
        ]
        
        print("\nFont files in bundle:")
        for fontFile in fontFiles {
            let fontName = fontFile.replacingOccurrences(of: ".ttf", with: "")
            // Try root first (where they actually are)
            if let path = Bundle.main.path(forResource: fontName, ofType: "ttf") {
                print("  ✓ Found: \(fontFile) at \(path)")
            } else if let path = Bundle.main.path(forResource: fontName, ofType: "ttf", inDirectory: "Fonts") {
                print("  ✓ Found: \(fontFile) at \(path)")
            } else {
                print("  ✗ Missing: \(fontFile)")
            }
        }
        
        print("\nAll available font families:")
        let fontFamilyNames = UIFont.familyNames.sorted()
        var foundPoppins = false
        for familyName in fontFamilyNames {
            if familyName.contains("Poppins") || familyName.lowercased() == "poppins" {
                foundPoppins = true
                print("\n✓ Found Poppins Family: \(familyName)")
                let fontNames = UIFont.fontNames(forFamilyName: familyName)
                for fontName in fontNames.sorted() {
                    print("  - \(fontName)")
                }
            }
        }
        
        if !foundPoppins {
            print("\n✗ No Poppins fonts found in system!")
            print("\nTroubleshooting:")
            print("1. Verify fonts are added to Xcode project")
            print("2. Check Target Membership for font files")
            print("3. Verify INFOPLIST_KEY_UIAppFonts in build settings")
            print("4. Clean build folder and rebuild")
        }
        
        print("\n===============================\n")
    }
    
    static func testFont(name: String, size: CGFloat = 18) -> Font? {
        if UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        }
        return nil
    }
}

