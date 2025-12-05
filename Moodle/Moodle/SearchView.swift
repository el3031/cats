import SwiftUI

// MARK: - Search View
struct SearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    @State private var recentSearches: [String] = ["poop", "puking", "not eating", "blood", "tired"]
    @State private var isKeyboardVisible = false
    @State private var searchResults: [PainAnalysisEntry] = []
    @State private var hasSearched = false
    @State private var selectedEntry: PainAnalysisEntry? = nil
    @State private var showDetailView = false
    @State private var showComingSoonPopup = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section (outside ScrollView so background extends to top)
            SearchHeaderView()
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 20) {
                    // Search Bar
                    SearchBarView(
                        searchText: $searchText,
                        onSearch: {
                            performSearch()
                        },
                        onClear: {
                            searchResults = []
                            hasSearched = false
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Show results if search has been performed
                    if hasSearched {
                        if searchResults.isEmpty {
                            // No results
                            VStack(spacing: 12) {
                                Text("No matching records")
                                    .font(.poppins(.regular, size: 16))
                                    .foregroundColor(.textSecondary)
                                    .padding(.top, 40)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            // Results section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Results")
                                    .font(.poppins(.semiBold, size: 14))
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 20)
                                
                                // Search Result Cards
                                ForEach(searchResults) { entry in
                                    SearchResultCard(entry: entry) {
                                        selectedEntry = entry
                                        showDetailView = true
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.top, 20)
                        }
                    } else {
                        // Recent Searches Section (only show when not searching)
                        if !recentSearches.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent searches")
                                    .font(.poppins(.semiBold, size: 14))
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 20)
                                
                                // Recent Search Buttons
                                VStack(spacing: 8) {
                                    ForEach(recentSearches, id: \.self) { searchTerm in
                                        RecentSearchButton(searchTerm: searchTerm) {
                                            searchText = searchTerm
                                            performSearch()
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                            .padding(.top, 20)
                        }
                    }
                    
                    Spacer()
                        .frame(height: 100) // Space for bottom nav
                }
            }
        }
        .background(Color.appBackground)
        .safeAreaInset(edge: .bottom) {
            SearchBottomNavigationView(onProfileTap: {
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
        .navigationDestination(isPresented: $showDetailView) {
            if let entry = selectedEntry {
                PastRecordDetailView(entry: entry)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = false
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            hasSearched = false
            return
        }
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Load and search entries
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ ERROR: Could not access documents directory")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("pain_analysis_entries.json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            searchResults = []
            hasSearched = true
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            
            // Parse and filter entries
            var entries: [PainAnalysisEntry] = []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let searchTerm = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            for jsonDict in jsonArray {
                guard let catName = jsonDict["catName"] as? String,
                      let dateTime = jsonDict["dateTime"] as? String,
                      let overallScore = jsonDict["overallScore"] as? Int,
                      let scoreBreakdownDict = jsonDict["scoreBreakdown"] as? [String: Any],
                      let eye = scoreBreakdownDict["eye"] as? Int,
                      let ear = scoreBreakdownDict["ear"] as? Int,
                      let muzzle = scoreBreakdownDict["muzzle"] as? Int,
                      let notes = jsonDict["notes"] as? String else {
                    continue
                }
                
                // Search in notes (case-insensitive)
                if notes.lowercased().contains(searchTerm) {
                    let imagePath = jsonDict["imagePath"] as? String
                    
                    let entry = PainAnalysisEntry(
                        catName: catName,
                        dateTime: dateTime,
                        overallScore: overallScore,
                        scoreBreakdown: PainAnalysisEntry.ScoreBreakdown(eye: eye, ear: ear, muzzle: muzzle),
                        notes: notes,
                        imagePath: imagePath
                    )
                    entries.append(entry)
                }
            }
            
            // Sort by date (most recent first)
            entries.sort { entry1, entry2 in
                guard let date1 = dateFormatter.date(from: entry1.dateTime),
                      let date2 = dateFormatter.date(from: entry2.dateTime) else {
                    return false
                }
                return date1 > date2
            }
            
            searchResults = entries
            hasSearched = true
            
            // Add to recent searches if not already there
            if !recentSearches.contains(searchText) {
                recentSearches.insert(searchText, at: 0)
                // Keep only last 5
                if recentSearches.count > 5 {
                    recentSearches = Array(recentSearches.prefix(5))
                }
            }
        } catch {
            print("❌ ERROR: Failed to load entries: \(error.localizedDescription)")
            searchResults = []
            hasSearched = true
        }
    }
}

// MARK: - Search Header
struct SearchHeaderView: View {
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
                
                Text("Search")
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

// MARK: - Search Bar
struct SearchBarView: View {
    @Binding var searchText: String
    let onSearch: () -> Void
    let onClear: () -> Void
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)
            
            // Text field
            TextField("Search by the keyword", text: $searchText)
                .font(.poppins(.regular, size: 14))
                .foregroundColor(.textPrimary)
                .focused($isSearchFocused)
                .onSubmit {
                    onSearch()
                }
            
            // Clear button
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    onClear()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.textLight)
                        .padding(6)
                        .background(Color.textSecondary)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Recent Search Button
struct RecentSearchButton: View {
    let searchTerm: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                
                Text(searchTerm)
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.borderColor.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Search Result Card
struct SearchResultCard: View {
    let entry: PainAnalysisEntry
    let onTap: () -> Void
    
    // Background color based on pain score
    private var scoreColor: Color {
        switch entry.overallScore {
        case 0...2:
            return Color(red: 0.20, green: 0.50, blue: 0.30) // Dark green
        case 3...4:
            return Color(red: 0.95, green: 0.55, blue: 0.45) // Coral
        default: // 5+
            return Color(red: 0.70, green: 0.20, blue: 0.20) // Red
        }
    }
    
    private func formatDate(_ dateTimeString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d MMM yyyy, HH:mm"
        
        if let date = inputFormatter.date(from: dateTimeString) {
            return outputFormatter.string(from: date)
        }
        return dateTimeString
    }
    
    // Extract note snippet (first 50 characters or so)
    private var noteSnippet: String {
        let maxLength = 50
        if entry.notes.count <= maxLength {
            return entry.notes
        }
        return String(entry.notes.prefix(maxLength)) + "..."
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    CatImageCircle(imagePath: entry.imagePath, size: 28, catName: entry.catName)
                    
                    Text(entry.catName)
                        .font(.poppins(.medium, size: 14))
                        .foregroundColor(.textPrimary)
                }
                
                Spacer()
                
                Text(formatDate(entry.dateTime))
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            
            // Pain Score Circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(scoreColor.opacity(0.3), lineWidth: 8)
                    .frame(width: 104, height: 104)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(entry.overallScore) / 6.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 104, height: 104)
                    .rotationEffect(.degrees(-90))
                
                // Score text
                VStack(spacing: 4) {
                    Text("\(entry.overallScore)/6")
                        .font(.poppins(.bold, size: 20))
                        .foregroundColor(scoreColor)
                    
                    Text("Pain Score")
                        .font(.poppins(.regular, size: 10))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.top, 14)
            
            // Note snippet
            if !entry.notes.isEmpty {
                Text(noteSnippet)
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
            }
            
            // View Details Button
            Button(action: onTap) {
                HStack {
                    Text("View Details")
                        .font(.poppins(.medium, size: 12))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.textPrimary)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.borderColor, lineWidth: 0.25)
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
        .background(Color.appBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.borderColor, lineWidth: 0.25)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Search Bottom Navigation
struct SearchBottomNavigationView: View {
    let onProfileTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Items
            HStack {
                NavButtonWithCustomIcon(isSelected: false, action: {
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToHome"), object: nil)
                })
                NavButtonWithCustomSearchIcon(isSelected: true)
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

// MARK: - Navigation Button with Custom Search Icon
struct NavButtonWithCustomSearchIcon: View {
    let isSelected: Bool
    
    var body: some View {
        // Always show the selected search icon without the dark circle
        SearchIcon(selected: true, size: 31.2)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Search Icon
struct SearchIcon: View {
    let selected: Bool
    let size: CGFloat
    
    var body: some View {
        // Use image assets for the search icons
        // selected: true = pixelated filled search icon
        // selected: false = pixelated outline search icon
        Image(selected ? "search_selected" : "search")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

// MARK: - Past Record Detail View
struct PastRecordDetailView: View {
    let entry: PainAnalysisEntry
    @Environment(\.dismiss) var dismiss
    @State private var isKeyboardVisible = false
    @State private var showComingSoonPopup = false
    
    // Background color based on pain score
    private var scoreColor: Color {
        switch entry.overallScore {
        case 0...2:
            return Color(red: 0.20, green: 0.50, blue: 0.30) // Dark green
        case 3...4:
            return Color(red: 0.95, green: 0.55, blue: 0.45) // Coral
        default: // 5+
            return Color(red: 0.70, green: 0.20, blue: 0.20) // Red
        }
    }
    
    private func formatDate(_ dateTimeString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d MMM yyyy, HH:mm"
        
        if let date = inputFormatter.date(from: dateTimeString) {
            return outputFormatter.string(from: date)
        }
        return dateTimeString
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (outside ScrollView so background extends to top)
            PastRecordHeaderView(onBack: {
                dismiss()
            })
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 20) {
                    // Cat Image (if available)
                    if let imagePath = entry.imagePath, !imagePath.isEmpty {
                        EntryImageView(imagePath: imagePath)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .onTapGesture {
                                dismissKeyboard()
                            }
                    }
                    
                    // Pain Score Card
                    PastRecordPainScoreCardView(
                        catName: entry.catName,
                        dateTime: formatDate(entry.dateTime),
                        overallScore: entry.overallScore,
                        backgroundColor: scoreColor
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, entry.imagePath != nil && !entry.imagePath!.isEmpty ? 0 : 20)
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    
                    // EYES Score Display
                    PainScoreDisplayView(
                        title: "EYES",
                        score: entry.scoreBreakdown.eye
                    )
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    
                    // EARS Score Display
                    PainScoreDisplayView(
                        title: "EARS",
                        score: entry.scoreBreakdown.ear
                    )
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    
                    // MUZZLE Score Display
                    PainScoreDisplayView(
                        title: "MUZZLE",
                        score: entry.scoreBreakdown.muzzle
                    )
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        dismissKeyboard()
                    }
                    
                    // NOTES Section (Read-only for now)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundColor(.textPrimary)
                        
                        Text(entry.notes.isEmpty ? "No notes" : entry.notes)
                            .font(.poppins(.regular, size: 14))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.borderColor, lineWidth: 0.25)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    // Edit Entry Button
                    Button(action: {
                        // TODO: Implement edit functionality
                        print("Edit entry tapped")
                    }) {
                        Text("Edit Entry")
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(.textLight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(scoreColor)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100) // Space for bottom nav
                }
            }
            .background(Color.appBackground)
        }
        .safeAreaInset(edge: .bottom) {
            PastRecordBottomNavigationView(onProfileTap: {
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = false
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Entry Image View
struct EntryImageView: View {
    let imagePath: String
    
    private var image: UIImage? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fullPath = documentsDirectory.appendingPathComponent(imagePath).path
        return UIImage(contentsOfFile: fullPath)
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.borderColor.opacity(0.3), lineWidth: 1)
                    )
            } else {
                // Placeholder if image not found
                Rectangle()
                    .fill(Color.catImageBackground)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.textSecondary)
                            Text("Image not available")
                                .font(.poppins(.regular, size: 14))
                                .foregroundColor(.textSecondary)
                        }
                    )
            }
        }
    }
}

// MARK: - Past Record Header
struct PastRecordHeaderView: View {
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button and title on same row
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textLight)
                        .padding(8)
                }
                
                Spacer()
                
                Text("Past Records")
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

// MARK: - Past Record Pain Score Card
struct PastRecordPainScoreCardView: View {
    let catName: String
    let dateTime: String
    let overallScore: Int
    let backgroundColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with cat name and date
            HStack {
                // Cat profile
                HStack(spacing: 8) {
                    CatImageCircle(imagePath: nil, size: 32, catName: catName)
                        .overlay(
                            Circle()
                                .stroke(Color.textLight, lineWidth: 1)
                        )
                    
                    Text(catName)
                        .font(.poppins(.semiBold, size: 16))
                        .foregroundColor(.textLight)
                }
                
                Spacer()
                
                // Date
                Text(dateTime)
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.textLight.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Pain Score Circle
            VStack(spacing: 8) {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.textLight.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: CGFloat(overallScore) / 6.0)
                        .stroke(Color.textLight, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    // Score text
                    VStack(spacing: 4) {
                        Text("\(overallScore)/6")
                            .font(.poppins(.bold, size: 24))
                            .foregroundColor(.textLight)
                        
                        Text("Pain Score")
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(.textLight.opacity(0.8))
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .background(backgroundColor)
        .cornerRadius(16)
    }
}

// MARK: - Past Record Bottom Navigation
struct PastRecordBottomNavigationView: View {
    let onProfileTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Items
            HStack {
                NavButtonWithCustomIcon(isSelected: false, action: {
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToHome"), object: nil)
                })
                NavButtonWithCustomSearchIcon(isSelected: false)
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
struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SearchView()
        }
    }
}

