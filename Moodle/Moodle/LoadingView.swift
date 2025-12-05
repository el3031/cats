import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color #49594B
                Color(red: 73/255.0, green: 89/255.0, blue: 75/255.0)
                    .ignoresSafeArea()
                
                // Loading image
                Image("loading")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: min(geometry.size.width * 0.8, 300), height: min(geometry.size.height * 0.8, 300))
            }
        }
    }
}

// MARK: - Preview
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}

