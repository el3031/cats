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

// MARK: - Cat Model
struct Cat: Identifiable {
    let id: UUID
    let name: String
    let imagePath: String?
    
    init(name: String, imagePath: String? = nil) {
        self.id = UUID()
        self.name = name
        self.imagePath = imagePath
    }
}

// MARK: - Pain Analysis Entry Model
struct PainAnalysisEntry: Identifiable {
    let id: UUID
    let catName: String
    let dateTime: String
    let overallScore: Int
    let scoreBreakdown: ScoreBreakdown
    let notes: String
    let imagePath: String?
    
    struct ScoreBreakdown {
        let eye: Int
        let ear: Int
        let muzzle: Int
    }
    
    init(catName: String, dateTime: String, overallScore: Int, scoreBreakdown: ScoreBreakdown, notes: String, imagePath: String? = nil) {
        self.id = UUID()
        self.catName = catName
        self.dateTime = dateTime
        self.overallScore = overallScore
        self.scoreBreakdown = scoreBreakdown
        self.notes = notes
        self.imagePath = imagePath
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var showAnalyzeCat = false
    @State private var showSearch = false
    @State private var showCalendar = false
    @State private var recentEntries: [PainAnalysisEntry] = []
    @State private var uniqueCats: [Cat] = []
    @State private var selectedEntry: PainAnalysisEntry? = nil
    @State private var showEntryDetail = false
    @State private var showComingSoonPopup = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Section (outside ScrollView so background extends to top)
                HeaderView(cats: uniqueCats)
                
                // Scrollable Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Action Buttons
                        ActionButtonsView(showAnalyzeCat: $showAnalyzeCat, showCalendar: $showCalendar)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        // Section Title
                        SectionHeaderView(title: "Latest Pain Analysis", action: "See All", onActionTap: {
                            showCalendar = true
                        })
                            .padding(.horizontal, 20)
                        
                        // Pain Analysis Cards (dynamically loaded)
                        ForEach(recentEntries) { entry in
                            PainAnalysisCard(
                                catName: entry.catName,
                                date: formatDate(entry.dateTime),
                                painScore: entry.overallScore,
                                imagePath: entry.imagePath
                            )
                            .padding(.horizontal, 20)
                            .onTapGesture {
                                selectedEntry = entry
                                showEntryDetail = true
                            }
                        }
                        
                        if recentEntries.isEmpty {
                            Text("No pain analysis entries yet")
                                .font(.poppins(.regular, size: 14))
                                .foregroundColor(.textSecondary)
                                .padding(.vertical, 20)
                        }
                        
                        Spacer()
                            .frame(height: 100) // Space for bottom nav
                    }
                }
                .background(Color.appBackground)
            }
            .safeAreaInset(edge: .bottom) {
                BottomNavigationView(showSearch: $showSearch, showAnalyzeCat: $showAnalyzeCat, showCalendar: $showCalendar, onProfileTap: {
                    showComingSoonPopup = true
                })
            }
            .overlay {
                if showComingSoonPopup {
                    ComingSoonPopupView(onClose: {
                        showComingSoonPopup = false
                    })
                    .transition(.opacity)
                    .zIndex(1000)
                }
            }
            .navigationDestination(isPresented: $showAnalyzeCat) {
                AnalyzeCatView()
            }
            .navigationDestination(isPresented: $showSearch) {
                SearchView()
            }
            .navigationDestination(isPresented: $showCalendar) {
                CalendarView()
            }
            .navigationDestination(isPresented: $showEntryDetail) {
                if let entry = selectedEntry {
                    PastRecordDetailView(entry: entry)
                }
            }
            .onAppear {
                createProfileImagesIfNeeded()
                loadRecentEntries()
                loadUniqueCats()
                verifyAndUpdateDummyRecordImages()
            }
            .onChange(of: showAnalyzeCat) { _ in
                // Reload entries when returning from analyze view
                if !showAnalyzeCat {
                    loadRecentEntries()
                    loadUniqueCats()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToHome"))) { _ in
                // Reset navigation when notification is received
                // This will automatically dismiss all views in the navigation stack
                showAnalyzeCat = false
                showSearch = false
                showCalendar = false
                loadRecentEntries()
                loadUniqueCats()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSearch"))) { _ in
                // Navigate to search view
                showCalendar = false
                showAnalyzeCat = false
                showSearch = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToAnalyzeCat"))) { _ in
                // Navigate to analyze cat view
                showCalendar = false
                showSearch = false
                showAnalyzeCat = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToCalendar"))) { _ in
                // Navigate to calendar view
                showSearch = false
                showAnalyzeCat = false
                showCalendar = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToCalendar"))) { _ in
                // Navigate to calendar view
                showCalendar = true
            }
        }
    }
    
    private func loadRecentEntries() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ ERROR: Could not access documents directory")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("pain_analysis_entries.json")
        
        // Create dummy data file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            createDummyDataFile(at: fileURL)
        } else {
            // Update existing dummy entries to use profile images if they don't have imagePath
            updateDummyEntriesWithProfileImages(at: fileURL)
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ℹ️  No pain analysis entries file found")
            recentEntries = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            
            // Parse entries
            var entries: [PainAnalysisEntry] = []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
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
            
            // Sort by date (most recent first) and take top 3
            entries.sort { entry1, entry2 in
                guard let date1 = dateFormatter.date(from: entry1.dateTime),
                      let date2 = dateFormatter.date(from: entry2.dateTime) else {
                    return false
                }
                return date1 > date2
            }
            
            recentEntries = Array(entries.prefix(3))
            print("✅ Loaded \(recentEntries.count) recent entries")
        } catch {
            print("❌ ERROR: Failed to load entries: \(error.localizedDescription)")
            recentEntries = []
        }
    }
    
    private func loadUniqueCats() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ ERROR: Could not access documents directory")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("pain_analysis_entries.json")
        let imagesDirectory = documentsDirectory.appendingPathComponent("cat_images")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ℹ️  No pain analysis entries file found for loading cats")
            uniqueCats = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            
            // Create a set of unique cat names
            var uniqueCatNames = Set<String>()
            for jsonDict in jsonArray {
                if let catName = jsonDict["catName"] as? String {
                    uniqueCatNames.insert(catName)
                }
            }
            
            // For each unique cat, use their profile image
            var cats: [Cat] = []
            for catName in uniqueCatNames.sorted() {
                let profileImagePath = imagesDirectory.appendingPathComponent("\(catName.lowercased())_profile.jpg")
                let profileImageRelativePath = "cat_images/\(catName.lowercased())_profile.jpg"
                
                // Always use profile image path if it exists, otherwise nil
                let imagePath: String? = FileManager.default.fileExists(atPath: profileImagePath.path) ? profileImageRelativePath : nil
                
                cats.append(Cat(name: catName, imagePath: imagePath))
            }
            
            uniqueCats = cats
            print("✅ Loaded \(uniqueCats.count) unique cats with profile images")
        } catch {
            print("❌ ERROR: Failed to load unique cats: \(error.localizedDescription)")
            uniqueCats = []
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
    
    private func createDummyDataFile(at fileURL: URL) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ ERROR: Could not access documents directory")
            return
        }
        
        let imagesDirectory = documentsDirectory.appendingPathComponent("cat_images")
        
        // Create images directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
        
        // Try to get profile images for dummy entries
        var noodleImagePath: String? = nil
        var bobaImagePath: String? = nil
        
        // Try to find noodle profile image
        let noodleProfilePath = imagesDirectory.appendingPathComponent("noodle_profile.jpg")
        if FileManager.default.fileExists(atPath: noodleProfilePath.path) {
            noodleImagePath = "cat_images/noodle_profile.jpg"
        }
        
        // Try to find boba profile image
        let bobaProfilePath = imagesDirectory.appendingPathComponent("boba_profile.jpg")
        if FileManager.default.fileExists(atPath: bobaProfilePath.path) {
            bobaImagePath = "cat_images/boba_profile.jpg"
        }
        
        var dummyEntries: [[String: Any]] = [
            [
                "catName": "noodle",
                "dateTime": "2025-10-09 12:18:00",
                "overallScore": 1,
                "scoreBreakdown": [
                    "eye": 0,
                    "ear": 0,
                    "muzzle": 1
                ],
                "notes": ""
            ],
            [
                "catName": "boba",
                "dateTime": "2025-10-08 19:18:00",
                "overallScore": 3,
                "scoreBreakdown": [
                    "eye": 1,
                    "ear": 0,
                    "muzzle": 2
                ],
                "notes": ""
            ]
        ]
        
        // Add image paths if available
        if let noodlePath = noodleImagePath {
            dummyEntries[0]["imagePath"] = noodlePath
        }
        if let bobaPath = bobaImagePath {
            dummyEntries[1]["imagePath"] = bobaPath
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dummyEntries, options: .prettyPrinted)
            try jsonData.write(to: fileURL)
            print("✅ Created dummy data file at: \(fileURL.path)")
            if noodleImagePath != nil {
                print("   ✅ Added noodle profile image path")
            }
            if bobaImagePath != nil {
                print("   ✅ Added boba profile image path")
            }
        } catch {
            print("❌ ERROR: Failed to create dummy data file: \(error.localizedDescription)")
        }
    }
    
    private func updateDummyEntriesWithProfileImages(at fileURL: URL) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let imagesDirectory = documentsDirectory.appendingPathComponent("cat_images")
        
        do {
            let data = try Data(contentsOf: fileURL)
            guard var entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return
            }
            
            var updated = false
            
            // Check each entry and add profile image path if missing
            for (index, var entry) in entries.enumerated() {
                // Only update entries that don't have an imagePath or have empty imagePath
                if let imagePath = entry["imagePath"] as? String, !imagePath.isEmpty {
                    continue
                }
                
                if let catName = entry["catName"] as? String {
                    let profileImagePath = imagesDirectory.appendingPathComponent("\(catName.lowercased())_profile.jpg")
                    
                    // If profile image exists, add it to the entry
                    if FileManager.default.fileExists(atPath: profileImagePath.path) {
                        entry["imagePath"] = "cat_images/\(catName.lowercased())_profile.jpg"
                        entries[index] = entry
                        updated = true
                        print("✅ Updated dummy entry for \(catName) with profile image")
                    }
                }
            }
            
            // Write back if updated
            if updated {
                let jsonData = try JSONSerialization.data(withJSONObject: entries, options: .prettyPrinted)
                try jsonData.write(to: fileURL)
                print("✅ Updated dummy entries with profile images")
            }
        } catch {
            print("⚠️  Could not update dummy entries: \(error.localizedDescription)")
        }
    }
    
    private func createProfileImagesIfNeeded() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let imagesDirectory = documentsDirectory.appendingPathComponent("cat_images")
        let jsonFileURL = documentsDirectory.appendingPathComponent("pain_analysis_entries.json")
        
        // Check if profile images exist
        let noodleProfilePath = imagesDirectory.appendingPathComponent("noodle_profile.jpg")
        let bobaProfilePath = imagesDirectory.appendingPathComponent("boba_profile.jpg")
        
        var needsNoodle = !FileManager.default.fileExists(atPath: noodleProfilePath.path)
        var needsBoba = !FileManager.default.fileExists(atPath: bobaProfilePath.path)
        
        if !needsNoodle && !needsBoba {
            return // Both profile images exist
        }
        
        // Try to find images from JSON entries
        guard let data = try? Data(contentsOf: jsonFileURL),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }
        
        // Find most recent image for each cat
        var noodleImagePath: String? = nil
        var bobaImagePath: String? = nil
        var noodleDate: Date? = nil
        var bobaDate: Date? = nil
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for entry in entries {
            guard let catName = entry["catName"] as? String,
                  let dateTimeString = entry["dateTime"] as? String,
                  let date = dateFormatter.date(from: dateTimeString),
                  let imagePath = entry["imagePath"] as? String else {
                continue
            }
            
            let fullImagePath = documentsDirectory.appendingPathComponent(imagePath).path
            
            if catName.lowercased() == "noodle" && needsNoodle {
                if FileManager.default.fileExists(atPath: fullImagePath) {
                    if noodleDate == nil || date > noodleDate! {
                        noodleImagePath = fullImagePath
                        noodleDate = date
                    }
                }
            } else if catName.lowercased() == "boba" && needsBoba {
                if FileManager.default.fileExists(atPath: fullImagePath) {
                    if bobaDate == nil || date > bobaDate! {
                        bobaImagePath = fullImagePath
                        bobaDate = date
                    }
                }
            }
        }
        
        // Copy the most recent images as profile images
        if let noodlePath = noodleImagePath, needsNoodle {
            do {
                try FileManager.default.copyItem(at: URL(fileURLWithPath: noodlePath), to: noodleProfilePath)
                print("✅ Created noodle_profile.jpg from existing image: \(noodlePath)")
            } catch {
                print("⚠️  Could not create noodle_profile.jpg: \(error.localizedDescription)")
            }
        }
        
        if let bobaPath = bobaImagePath, needsBoba {
            do {
                try FileManager.default.copyItem(at: URL(fileURLWithPath: bobaPath), to: bobaProfilePath)
                print("✅ Created boba_profile.jpg from existing image: \(bobaPath)")
            } catch {
                print("⚠️  Could not create boba_profile.jpg: \(error.localizedDescription)")
            }
        }
    }
    
    private func verifyAndUpdateDummyRecordImages() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("pain_analysis_entries.json")
        let imagesDirectory = documentsDirectory.appendingPathComponent("cat_images")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            guard var entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return
            }
            
            var updated = false
            
            // Check each entry and verify/update image paths
            for (index, var entry) in entries.enumerated() {
                guard let catName = entry["catName"] as? String else {
                    continue
                }
                
                let currentImagePath = entry["imagePath"] as? String
                var needsUpdate = false
                var newImagePath: String? = nil
                
                // If there's an imagePath, verify it exists
                if let imagePath = currentImagePath, !imagePath.isEmpty {
                    let fullPath = documentsDirectory.appendingPathComponent(imagePath).path
                    if !FileManager.default.fileExists(atPath: fullPath) {
                        print("⚠️  Image path in JSON doesn't exist: \(imagePath), trying to find profile image")
                        needsUpdate = true
                    }
                } else {
                    needsUpdate = true
                }
                
                // If we need to update, try to find the profile image
                if needsUpdate {
                    let profileImagePath = imagesDirectory.appendingPathComponent("\(catName.lowercased())_profile.jpg")
                    if FileManager.default.fileExists(atPath: profileImagePath.path) {
                        newImagePath = "cat_images/\(catName.lowercased())_profile.jpg"
                        print("✅ Found profile image for \(catName): \(newImagePath!)")
                    } else {
                        print("⚠️  Profile image not found for \(catName) at: \(profileImagePath.path)")
                    }
                }
                
                // Update the entry if needed
                if needsUpdate {
                    if let newPath = newImagePath {
                        entry["imagePath"] = newPath
                        entries[index] = entry
                        updated = true
                        print("✅ Updated entry for \(catName) with image path: \(newPath)")
                    } else {
                        // Remove invalid imagePath
                        entry.removeValue(forKey: "imagePath")
                        entries[index] = entry
                        updated = true
                        print("⚠️  Removed invalid imagePath for \(catName)")
                    }
                }
            }
            
            // Write back if updated
            if updated {
                let jsonData = try JSONSerialization.data(withJSONObject: entries, options: .prettyPrinted)
                try jsonData.write(to: fileURL)
                print("✅ Verified and updated dummy record images")
                // Reload entries to reflect changes
                loadRecentEntries()
                loadUniqueCats()
            }
        } catch {
            print("⚠️  Could not verify dummy record images: \(error.localizedDescription)")
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    let cats: [Cat]
    
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Cat Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 30) {
                    ForEach(cats) { cat in
                        CatCard(name: cat.name, imagePath: cat.imagePath)
                    }
                    AddCatCard()
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .background(
            Color.headerBackground
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Cat Card Component
struct CatCard: View {
    let name: String
    let imagePath: String?
    
    var body: some View {
        VStack(spacing: 6) {
            CatImageCircle(imagePath: imagePath, size: 68, catName: name)
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
    var onActionTap: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.poppins(.semiBold, size: 18))
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Button(action: {
                onActionTap?()
            }) {
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
    @Binding var showCalendar: Bool
    
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
            Button(action: { showCalendar = true }) {
                VStack(spacing: 10) {
                    Image("calendar")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.textPrimary)
                        .frame(width: 24, height: 24)
                    
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
    let painScore: Int
    let imagePath: String?
    
    init(catName: String, date: String, painScore: Int, imagePath: String? = nil) {
        self.catName = catName
        self.date = date
        self.painScore = painScore
        self.imagePath = imagePath
    }
    
    // Background color based on pain score
    private var scoreColor: Color {
        switch painScore {
        case 0...2:
            return Color(red: 0.20, green: 0.50, blue: 0.30) // Dark green
        case 3...4:
            return Color(red: 0.95, green: 0.55, blue: 0.45) // Coral
        default: // 5+
            return Color(red: 0.70, green: 0.20, blue: 0.20) // Red
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    CatImageCircle(imagePath: imagePath, size: 28, catName: catName)
                    
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
            
            // Pain Score Circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(scoreColor.opacity(0.3), lineWidth: 8)
                    .frame(width: 104, height: 104)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(painScore) / 6.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 104, height: 104)
                    .rotationEffect(.degrees(-90))
                
                // Score text
                VStack(spacing: 4) {
                    Text("\(painScore)/6")
                        .font(.poppins(.bold, size: 20))
                        .foregroundColor(scoreColor)
                    
                    Text("Pain Score")
                        .font(.poppins(.regular, size: 10))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.top, 14)
            
            // View Details Button
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
    }
}

// MARK: - Bottom Navigation
struct BottomNavigationView: View {
    @Binding var showSearch: Bool
    @Binding var showAnalyzeCat: Bool
    @Binding var showCalendar: Bool
    let onProfileTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Items
            HStack {
                // Home button with custom house icon (filled when on ContentView)
                NavButtonWithCustomIcon(isSelected: true, action: {
                    // Navigate to home by posting notification
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToHome"), object: nil)
                })
                NavButtonWithCustomSearchIconOutline(isSelected: false, action: {
                    showSearch = true
                })
                NavButtonWithCustomCameraIcon(isSelected: false, action: {
                    showAnalyzeCat = true
                })
                NavButtonWithCustomCalendarIcon(isSelected: false, action: {
                    showCalendar = true
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

// MARK: - Navigation Button
struct NavButton: View {
    let icon: String
    let isSelected: Bool
    var size: CGFloat = 24
    var highlightColor: Color = Color.textPrimary
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            action?()
        }) {
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

// MARK: - Navigation Button with Custom House Icon
struct NavButtonWithCustomIcon: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            if isSelected {
                // Filled house icon without dark circle
                HouseIcon(filled: true, color: .textPrimary, size: 31.2)
            } else {
                // Outline house icon
                HouseIcon(filled: false, color: .textPrimary, size: 31.2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - House Icon
struct HouseIcon: View {
    let filled: Bool
    let color: Color
    let size: CGFloat
    
    var body: some View {
        // Use image assets for the house icons
        // filled: true = dark green-grey filled house icon
        // filled: false = dark gray/charcoal outline house icon
        Image(filled ? "house_filled" : "house_outline")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

// MARK: - Navigation Button with Custom Camera Icon
struct NavButtonWithCustomCameraIcon: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            // Show selected camera icon when on AnalyzeCatView, otherwise show outline
            CameraIcon(selected: isSelected, size: 62.4)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Camera Icon
struct CameraIcon: View {
    let selected: Bool
    let size: CGFloat
    
    var body: some View {
        // Use image assets for the camera icons
        // selected: true = pixelated filled camera icon
        // selected: false = pixelated outline camera icon
        Image(selected ? "camera_selected" : "camera")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

// MARK: - Navigation Button with Custom Calendar Icon
struct NavButtonWithCustomCalendarIcon: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            // Show selected calendar icon when on CalendarView, otherwise show outline
            CalendarIcon(selected: isSelected, size: 31.2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Calendar Icon
struct CalendarIcon: View {
    let selected: Bool
    let size: CGFloat
    
    var body: some View {
        // Use image assets for the calendar icons
        // selected: true = filled calendar icon
        // selected: false = outline calendar icon
        Image(selected ? "calendar_selected" : "calendar")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

// MARK: - Navigation Button with Custom Profile Icon
struct NavButtonWithCustomProfileIcon: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ProfileIcon(size: 31.2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Icon
struct ProfileIcon: View {
    let size: CGFloat
    
    var body: some View {
        // Use profile.svg asset
        Image("profile")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

// MARK: - Coming Soon Popup View
struct ComingSoonPopupView: View {
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            // Popup Card
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    // X button in top right
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Coming Soon text
                    Text("Coming Soon")
                        .font(.poppins(.bold, size: 24))
                        .foregroundColor(.textPrimary)
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
}

// MARK: - Cat Image Circle Component
struct CatImageCircle: View {
    let imagePath: String?
    let catName: String?
    let size: CGFloat
    
    init(imagePath: String?, size: CGFloat = 28, catName: String? = nil) {
        self.imagePath = imagePath
        self.size = size
        self.catName = catName
    }
    
    private func loadImage() -> UIImage? {
        // First priority: Try profile image from assets folder by cat name
        if let catName = catName {
            let assetName = "\(catName.lowercased())_profile"
            if let image = UIImage(named: assetName) {
                print("✅ CatImageCircle: Loaded profile image from assets for cat: \(catName)")
                return image
            }
        }
        
        // Second priority: Try profile image from documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️  CatImageCircle: Could not access documents directory")
            return nil
        }
        
        if let catName = catName {
            let imagesDirectory = documentsDirectory.appendingPathComponent("cat_images")
            // Try both PNG and JPG
            let profileImagePNG = imagesDirectory.appendingPathComponent("\(catName.lowercased())_profile.png")
            let profileImageJPG = imagesDirectory.appendingPathComponent("\(catName.lowercased())_profile.jpg")
            
            if FileManager.default.fileExists(atPath: profileImagePNG.path),
               let image = UIImage(contentsOfFile: profileImagePNG.path) {
                print("✅ CatImageCircle: Loaded profile image (PNG) from documents for cat: \(catName)")
                return image
            }
            
            if FileManager.default.fileExists(atPath: profileImageJPG.path),
               let image = UIImage(contentsOfFile: profileImageJPG.path) {
                print("✅ CatImageCircle: Loaded profile image (JPG) from documents for cat: \(catName)")
                return image
            }
        }
        
        // Third priority: Try the provided imagePath (for entry-specific images)
        if let imagePath = imagePath, !imagePath.isEmpty {
            let fullPath = documentsDirectory.appendingPathComponent(imagePath).path
            if FileManager.default.fileExists(atPath: fullPath),
               let image = UIImage(contentsOfFile: fullPath) {
                print("✅ CatImageCircle: Loaded image from path: \(imagePath)")
                return image
            } else {
                print("⚠️  CatImageCircle: Image not found at path: \(fullPath)")
            }
        }
        
        // Fallback: Try other variations by cat name in documents
        if let catName = catName {
            let imagesDirectory = documentsDirectory.appendingPathComponent("cat_images")
            let possibleNames = [
                "\(catName.lowercased())_profile.png",
                "\(catName.lowercased())_profile.jpg",
                "\(catName.lowercased()).png",
                "\(catName.lowercased()).jpg",
                "\(catName)_profile.png",
                "\(catName)_profile.jpg",
                "\(catName).png",
                "\(catName).jpg"
            ]
            
            for name in possibleNames {
                let imagePath = imagesDirectory.appendingPathComponent(name).path
                if FileManager.default.fileExists(atPath: imagePath),
                   let image = UIImage(contentsOfFile: imagePath) {
                    print("✅ CatImageCircle: Loaded image by cat name: \(name)")
                    return image
                }
            }
            print("⚠️  CatImageCircle: No image found for cat: \(catName)")
        }
        
        return nil
    }
    
    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.borderColor, lineWidth: 0.25)
                    )
            } else {
                Circle()
                    .fill(Color.catImageBackground)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.borderColor, lineWidth: 0.25)
                    )
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

