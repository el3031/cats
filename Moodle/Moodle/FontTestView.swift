import SwiftUI

// Test view to check available font names
struct FontTestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Font Test")
                .font(.poppins(.bold, size: 24))
            
            Text("Regular")
                .font(.poppins(.regular, size: 18))
            
            Text("Medium")
                .font(.poppins(.medium, size: 18))
            
            Text("SemiBold")
                .font(.poppins(.semiBold, size: 18))
            
            Text("Bold")
                .font(.poppins(.bold, size: 18))
            
            // Test direct font names
            VStack(alignment: .leading, spacing: 10) {
                Text("Direct Font Tests:")
                Text("Poppins-Regular").font(.custom("Poppins-Regular", size: 16))
                Text("Poppins-Bold").font(.custom("Poppins-Bold", size: 16))
                Text("Poppins-SemiBold").font(.custom("Poppins-SemiBold", size: 16))
                Text("Poppins-Medium").font(.custom("Poppins-Medium", size: 16))
            }
            .padding()
        }
    }
}

