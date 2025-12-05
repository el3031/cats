import SwiftUI

// MARK: - Calendar View
struct CalendarView: View {
    @Environment(\.dismiss) var dismiss
    @State private var allRecordsByDate: [String: [PainAnalysisEntry]] = [:]
    @State private var filteredRecordsByDate: [String: [PainAnalysisEntry]] = [:]
    @State private var selectedDate: Date = Date()
    @State private var showFilter = false
    @State private var expandedMonths: Set<String> = []
    
    // Filter state
    @State private var selectedScoreRanges: Set<String> = []
    @State private var selectedCats: Set<String> = []
    @State private var dateFrom: Date? = nil
    @State private var dateTo: Date? = nil
    @State private var showDateRecords = false
    @State private var selectedDateRecords: [PainAnalysisEntry] = []
    @State private var showComingSoonPopup = false
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // Sticky Header
                CalendarHeaderView(
                    showFilter: $showFilter,
                    hasActiveFilters: !selectedScoreRanges.isEmpty || !selectedCats.isEmpty || dateFrom != nil || dateTo != nil,
                    onClearFilters: {
                        clearFilters()
                    },
                    onBack: {
                        dismiss()
                    }
                )
                
                ScrollView {
                    // Main Content
                    VStack(spacing: 0) {
                        // Load and display calendar months
                        ForEach(getMonthsToDisplay(), id: \.self) { monthKey in
                            MonthCalendarView(
                                monthKey: monthKey,
                                recordsByDate: filteredRecordsByDate,
                                selectedDate: $selectedDate,
                                isExpanded: expandedMonths.contains(monthKey),
                                onToggle: {
                                    // Toggle expansion
                                    if expandedMonths.contains(monthKey) {
                                        expandedMonths.remove(monthKey)
                                    } else {
                                        expandedMonths.insert(monthKey)
                                    }
                                },
                                onViewRecords: { records in
                                    selectedDateRecords = records
                                    showDateRecords = true
                                }
                            )
                            .id(monthKey)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100) // Space for bottom nav
                }
            }
            .background(Color.appBackground)
            .safeAreaInset(edge: .bottom) {
                CalendarBottomNavigationView(onProfileTap: {
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
            .onAppear {
                loadRecords()
                // Expand all months by default
                let months = getMonthsToDisplay()
                expandedMonths = Set(months)
                // Scroll to current month
                let currentMonth = getCurrentMonthKey()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo(currentMonth, anchor: .top)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToHome"))) { _ in
                dismiss()
            }
            .overlay {
                if showFilter {
                    FilterPopupView(
                        isPresented: $showFilter,
                        selectedScoreRanges: $selectedScoreRanges,
                        selectedCats: $selectedCats,
                        dateFrom: $dateFrom,
                        dateTo: $dateTo,
                        onApply: {
                            applyFilters()
                            // Scroll to date range if set
                            if let fromDate = dateFrom {
                                scrollToMonth(for: fromDate, proxy: proxy)
                            } else if let toDate = dateTo {
                                scrollToMonth(for: toDate, proxy: proxy)
                            }
                        },
                        onDateRangeChanged: { newFrom, newTo in
                            // Update temp dates and scroll when date range changes
                            if let fromDate = newFrom {
                                scrollToMonth(for: fromDate, proxy: proxy)
                            } else if let toDate = newTo {
                                scrollToMonth(for: toDate, proxy: proxy)
                            }
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $showDateRecords) {
                if !selectedDateRecords.isEmpty {
                    DateRecordsView(entries: selectedDateRecords, date: selectedDate)
                }
            }
        }
    }
    
    private func scrollToMonth(for date: Date, proxy: ScrollViewProxy) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthKey = formatter.string(from: date)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                proxy.scrollTo(monthKey, anchor: .top)
            }
        }
    }
    
    private func getCurrentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    private func loadRecords() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ ERROR: Could not access documents directory")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("pain_analysis_entries.json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ℹ️  No pain analysis entries file found")
            allRecordsByDate = [:]
            filteredRecordsByDate = [:]
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
            
            // Group entries by date (yyyy-MM-dd format)
            var grouped: [String: [PainAnalysisEntry]] = [:]
            for entry in entries {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                if let date = dateFormatter.date(from: entry.dateTime) {
                    let dateKeyFormatter = DateFormatter()
                    dateKeyFormatter.dateFormat = "yyyy-MM-dd"
                    let dateKey = dateKeyFormatter.string(from: date)
                    if grouped[dateKey] == nil {
                        grouped[dateKey] = []
                    }
                    grouped[dateKey]?.append(entry)
                }
            }
            
            allRecordsByDate = grouped
            filteredRecordsByDate = grouped
            print("✅ Loaded \(entries.count) records, grouped into \(grouped.count) dates")
            applyFilters()
        } catch {
            print("❌ ERROR: Failed to load entries: \(error.localizedDescription)")
            allRecordsByDate = [:]
            filteredRecordsByDate = [:]
        }
    }
    
    private func applyFilters() {
        var filtered: [String: [PainAnalysisEntry]] = [:]
        
        for (dateKey, entries) in allRecordsByDate {
            var matchingEntries: [PainAnalysisEntry] = []
            
            for entry in entries {
                // Filter by score range
                if !selectedScoreRanges.isEmpty {
                    let scoreRange: String
                    switch entry.overallScore {
                    case 0...2:
                        scoreRange = "0-2"
                    case 3...4:
                        scoreRange = "3-4"
                    default:
                        scoreRange = "5-6"
                    }
                    if !selectedScoreRanges.contains(scoreRange) {
                        continue
                    }
                }
                
                // Filter by cat
                if !selectedCats.isEmpty {
                    if !selectedCats.contains(entry.catName) {
                        continue
                    }
                }
                
                // Filter by date range
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                if let entryDate = dateFormatter.date(from: entry.dateTime) {
                    if let fromDate = dateFrom, entryDate < fromDate {
                        continue
                    }
                    if let toDate = dateTo, entryDate > toDate {
                        continue
                    }
                }
                
                matchingEntries.append(entry)
            }
            
            if !matchingEntries.isEmpty {
                filtered[dateKey] = matchingEntries
            }
        }
        
        filteredRecordsByDate = filtered
    }
    
    private func clearFilters() {
        selectedScoreRanges = []
        selectedCats = []
        dateFrom = nil
        dateTo = nil
        filteredRecordsByDate = allRecordsByDate
    }
    
    private func getMonthsToDisplay() -> [String] {
        // Get current month and a few months before/after
        let calendar = Calendar.current
        let now = Date()
        var months: [String] = []
        
        // Add 6 months before and 6 months after
        for i in -6...6 {
            if let date = calendar.date(byAdding: .month, value: i, to: now) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM"
                months.append(formatter.string(from: date))
            }
        }
        
        return months
    }
}

// MARK: - Calendar Header
struct CalendarHeaderView: View {
    @Binding var showFilter: Bool
    let hasActiveFilters: Bool
    let onClearFilters: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Title row: Back button | "Past Records" | Clear button or spacer
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
                
                // Clear filter button or spacer
                if hasActiveFilters {
                    Button(action: onClearFilters) {
                        Text("Clear")
                            .font(.poppins(.medium, size: 14))
                            .foregroundColor(.textLight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                } else {
                    Color.clear
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Filter button row
            HStack {
                Button(action: { showFilter = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16))
                        Text("Filter")
                            .font(.poppins(.semiBold, size: 14))
                    }
                    .foregroundColor(.textLight)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                
                Spacer()
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

// MARK: - Month Calendar View
struct MonthCalendarView: View {
    let monthKey: String
    let recordsByDate: [String: [PainAnalysisEntry]]
    @Binding var selectedDate: Date
    let isExpanded: Bool
    let onToggle: () -> Void
    let onViewRecords: ([PainAnalysisEntry]) -> Void
    
    private var monthDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: monthKey) ?? Date()
    }
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM, yyyy"
        return formatter.string(from: monthDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month Header
            Button(action: onToggle) {
                HStack {
                    Text(monthName)
                        .font(.poppins(.bold, size: 20))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            
            if isExpanded {
                // Calendar Grid
                CalendarGridView(
                    monthDate: monthDate,
                    recordsByDate: recordsByDate,
                    selectedDate: $selectedDate,
                    onViewRecords: onViewRecords
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
            // Divider
            Rectangle()
                .fill(Color.borderColor.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 20)
        }
    }
}

// MARK: - Calendar Grid View
struct CalendarGridView: View {
    let monthDate: Date
    let recordsByDate: [String: [PainAnalysisEntry]]
    @Binding var selectedDate: Date
    let onViewRecords: ([PainAnalysisEntry]) -> Void
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private var firstDayOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) ?? monthDate
    }
    
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 0
    }
    
    private var firstWeekday: Int {
        (calendar.component(.weekday, from: firstDayOfMonth) + 5) % 7 // Convert to Monday = 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Day labels
            HStack(spacing: 0) {
                ForEach(["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"], id: \.self) { day in
                    Text(day)
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Empty cells for days before month starts
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear
                        .frame(height: 40)
                }
                
                // Days of the month
                ForEach(1...daysInMonth, id: \.self) { day in
                    DayCellView(
                        day: day,
                        monthDate: monthDate,
                        recordsByDate: recordsByDate,
                        isSelected: isDateSelected(day: day),
                        onTap: {
                            selectDate(day: day)
                        },
                        onViewRecords: onViewRecords
                    )
                }
            }
        }
    }
    
    private func isDateSelected(day: Int) -> Bool {
        let calendar = Calendar.current
        if let date = calendar.date(bySetting: .day, value: day, of: monthDate) {
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
        return false
    }
    
    private func selectDate(day: Int) {
        let calendar = Calendar.current
        if let date = calendar.date(bySetting: .day, value: day, of: monthDate) {
            selectedDate = date
        }
    }
}

// MARK: - Day Cell View
struct DayCellView: View {
    let day: Int
    let monthDate: Date
    let recordsByDate: [String: [PainAnalysisEntry]]
    let isSelected: Bool
    let onTap: () -> Void
    let onViewRecords: ([PainAnalysisEntry]) -> Void
    
    private var dateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        if let date = calendar.date(bySetting: .day, value: day, of: monthDate) {
            return formatter.string(from: date)
        }
        // Fallback: construct date string manually
        let year = calendar.component(.year, from: monthDate)
        let month = calendar.component(.month, from: monthDate)
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
    
    private var recordsForDate: [PainAnalysisEntry] {
        recordsByDate[dateKey] ?? []
    }
    
    private var isToday: Bool {
        let calendar = Calendar.current
        let today = Date()
        if let date = calendar.date(bySetting: .day, value: day, of: monthDate) {
            return calendar.isDate(date, inSameDayAs: today)
        }
        return false
    }
    
    private var scoreGroups: [(range: String, count: Int, color: Color)] {
        var groups: [String: Int] = [:]
        for record in recordsForDate {
            let range: String
            switch record.overallScore {
            case 0...2:
                range = "0-2"
            case 3...4:
                range = "3-4"
            default:
                range = "5+"
            }
            groups[range, default: 0] += 1
        }
        
        return groups.map { (range: $0.key, count: $0.value, color: colorForRange($0.key)) }
            .sorted { $0.range < $1.range }
    }
    
    private func colorForRange(_ range: String) -> Color {
        switch range {
        case "0-2":
            return Color(red: 0.20, green: 0.50, blue: 0.30) // Dark green
        case "3-4":
            return Color(red: 0.95, green: 0.55, blue: 0.45) // Coral
        default: // "5+"
            return Color(red: 0.70, green: 0.20, blue: 0.20) // Dark red
        }
    }
    
    var body: some View {
        Button(action: {
            if !recordsForDate.isEmpty {
                onViewRecords(recordsForDate)
            } else {
                onTap()
            }
        }) {
            ZStack(alignment: .topTrailing) {
                // Day number
                Text("\(day)")
                    .font(.poppins(.regular, size: 14))
                    .foregroundColor(isSelected ? .textLight : (isToday ? .white : .textPrimary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(isSelected ? Color.headerBackground : (isToday ? Color(red: 0.20, green: 0.50, blue: 0.30) : Color.clear))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.borderColor.opacity(0.3), lineWidth: isSelected || isToday ? 0 : 0.5)
                    )
                
                // Score indicators - positioned at absolute corner
                if !recordsForDate.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(scoreGroups, id: \.range) { group in
                            if group.count == 1 {
                                // Single record - just show circle (1.5x bigger: 8 -> 12)
                                Circle()
                                    .fill(group.color)
                                    .frame(width: 12, height: 12)
                            } else {
                                // Multiple records - show circle with number (1.5x bigger: 16 -> 24)
                                ZStack {
                                    Circle()
                                        .fill(group.color)
                                        .frame(width: 24, height: 24)
                                    Text("\(group.count)")
                                        .font(.poppins(.bold, size: 11))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .offset(x: 4, y: -4)
                }
            }
            .frame(height: 40)
        }
    }
}

// MARK: - Filter Popup View
struct FilterPopupView: View {
    @Binding var isPresented: Bool
    @Binding var selectedScoreRanges: Set<String>
    @Binding var selectedCats: Set<String>
    @Binding var dateFrom: Date?
    @Binding var dateTo: Date?
    let onApply: () -> Void
    let onDateRangeChanged: ((Date?, Date?) -> Void)?
    
    @State private var tempScoreRanges: Set<String> = []
    @State private var tempCats: Set<String> = []
    @State private var tempDateFrom: Date? = nil
    @State private var tempDateTo: Date? = nil
    
    init(
        isPresented: Binding<Bool>,
        selectedScoreRanges: Binding<Set<String>>,
        selectedCats: Binding<Set<String>>,
        dateFrom: Binding<Date?>,
        dateTo: Binding<Date?>,
        onApply: @escaping () -> Void,
        onDateRangeChanged: ((Date?, Date?) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._selectedScoreRanges = selectedScoreRanges
        self._selectedCats = selectedCats
        self._dateFrom = dateFrom
        self._dateTo = dateTo
        self.onApply = onApply
        self.onDateRangeChanged = onDateRangeChanged
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Filter popup
            VStack(spacing: 0) {
                // Header with X button
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(.textPrimary)
                    }
                }
                .padding(16)
                
                // Filter content
                VStack(alignment: .leading, spacing: 24) {
                    // Filter by Pain Score
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filter by Pain Score")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundColor(.textPrimary)
                        
                        HStack(spacing: 8) {
                            FilterButton(
                                title: "0-2",
                                isSelected: tempScoreRanges.contains("0-2"),
                                color: Color(red: 0.20, green: 0.50, blue: 0.30)
                            ) {
                                if tempScoreRanges.contains("0-2") {
                                    tempScoreRanges.remove("0-2")
                                } else {
                                    tempScoreRanges.insert("0-2")
                                }
                            }
                            FilterButton(
                                title: "3-4",
                                isSelected: tempScoreRanges.contains("3-4"),
                                color: Color(red: 0.95, green: 0.55, blue: 0.45)
                            ) {
                                if tempScoreRanges.contains("3-4") {
                                    tempScoreRanges.remove("3-4")
                                } else {
                                    tempScoreRanges.insert("3-4")
                                }
                            }
                            FilterButton(
                                title: "5-6",
                                isSelected: tempScoreRanges.contains("5-6"),
                                color: Color(red: 0.70, green: 0.20, blue: 0.20)
                            ) {
                                if tempScoreRanges.contains("5-6") {
                                    tempScoreRanges.remove("5-6")
                                } else {
                                    tempScoreRanges.insert("5-6")
                                }
                            }
                        }
                    }
                    
                    // Filter by Cat
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filter by Cat")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundColor(.textPrimary)
                        
                        HStack(spacing: 8) {
                            CatFilterButton(
                                name: "noodle",
                                isSelected: tempCats.contains("noodle")
                            ) {
                                if tempCats.contains("noodle") {
                                    tempCats.remove("noodle")
                                } else {
                                    tempCats.insert("noodle")
                                }
                            }
                            CatFilterButton(
                                name: "boba",
                                isSelected: tempCats.contains("boba")
                            ) {
                                if tempCats.contains("boba") {
                                    tempCats.remove("boba")
                                } else {
                                    tempCats.insert("boba")
                                }
                            }
                        }
                    }
                    
                    // Filter by Date Range
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filter by Date Range")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundColor(.textPrimary)
                        
                        VStack(spacing: 8) {
                            DateFilterField(
                                label: "From",
                                date: $tempDateFrom,
                                onChange: { newDate in
                                    onDateRangeChanged?(newDate, tempDateTo)
                                }
                            )
                            DateFilterField(
                                label: "To",
                                date: $tempDateTo,
                                onChange: { newDate in
                                    onDateRangeChanged?(tempDateFrom, newDate)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Buttons
                VStack(spacing: 12) {
                    // Clear Filters button
                    Button(action: {
                        tempScoreRanges = []
                        tempCats = []
                        tempDateFrom = nil
                        tempDateTo = nil
                    }) {
                        Text("Clear Filters")
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.borderColor, lineWidth: 1)
                            )
                    }
                    
                    // Apply button
                    Button(action: {
                        selectedScoreRanges = tempScoreRanges
                        selectedCats = tempCats
                        dateFrom = tempDateFrom
                        dateTo = tempDateTo
                        onApply()
                        isPresented = false
                    }) {
                        Text("Apply Filters")
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0xDC/255.0, green: 0x8B/255.0, blue: 0x6D/255.0))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
        .onAppear {
            tempScoreRanges = selectedScoreRanges
            tempCats = selectedCats
            tempDateFrom = dateFrom
            tempDateTo = dateTo
        }
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.poppins(.medium, size: 14))
                .foregroundColor(isSelected ? .white : .textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color, lineWidth: 1)
                )
        }
    }
}

// MARK: - Cat Filter Button
struct CatFilterButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                CatImageCircle(imagePath: nil, size: 20, catName: name)
                
                Text(name)
                    .font(.poppins(.medium, size: 14))
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.headerBackground.opacity(0.2) : Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
        }
    }
}

// MARK: - Date Filter Field
struct DateFilterField: View {
    let label: String
    @Binding var date: Date?
    let onChange: ((Date?) -> Void)?
    @State private var showDatePicker = false
    
    init(label: String, date: Binding<Date?>, onChange: ((Date?) -> Void)? = nil) {
        self.label = label
        self._date = date
        self.onChange = onChange
    }
    
    private var dateString: String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: { showDatePicker = true }) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                
                if date != nil {
                    Text(dateString)
                        .font(.poppins(.regular, size: 14))
                        .foregroundColor(.textPrimary)
                } else {
                    Text("Select date")
                        .font(.poppins(.regular, size: 14))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                if date != nil {
                    Button(action: { date = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderColor, lineWidth: 0.5)
            )
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                DatePicker(
                    label,
                    selection: Binding(
                        get: { date ?? Date() },
                        set: { newDate in
                            date = newDate
                            onChange?(newDate)
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .navigationTitle(label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showDatePicker = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Calendar Bottom Navigation
struct CalendarBottomNavigationView: View {
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
                NavButtonWithCustomCalendarIcon(isSelected: true, action: {
                    // Already on CalendarView, do nothing
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

// MARK: - Navigation Button with Custom Search Icon (Outline)
struct NavButtonWithCustomSearchIconOutline: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            // Show outline search icon (not selected)
            SearchIcon(selected: false, size: 31.2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Date Records View
struct DateRecordsView: View {
    let entries: [PainAnalysisEntry]
    let date: Date
    @Environment(\.dismiss) var dismiss
    @State private var showComingSoonPopup = false
    
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
    
    private func noteSnippet(for entry: PainAnalysisEntry) -> String {
        let maxLength = 50
        if entry.notes.count <= maxLength {
            return entry.notes.isEmpty ? "" : entry.notes
        }
        return String(entry.notes.prefix(maxLength)) + "..."
    }
    
    private func formatDisplayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (outside ScrollView so background extends to top)
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.textLight)
                            .padding(8)
                    }
                    
                    Spacer()
                    
                    Text(formatDisplayDate(date))
                        .font(.poppins(.bold, size: 20))
                        .foregroundColor(.textLight)
                    
                    Spacer()
                    
                    // Invisible button for balance
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
            
            // Scrollable Records List
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(entries) { entry in
                        NavigationLink(destination: PastRecordDetailView(entry: entry)) {
                            VStack(spacing: 0) {
                                // Header: Cat name and date
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
                                    let scoreColor: Color = {
                                        switch entry.overallScore {
                                        case 0...2:
                                            return Color(red: 0.20, green: 0.50, blue: 0.30)
                                        case 3...4:
                                            return Color(red: 0.95, green: 0.55, blue: 0.45)
                                        default:
                                            return Color(red: 0.70, green: 0.20, blue: 0.20)
                                        }
                                    }()
                                    
                                    Circle()
                                        .stroke(scoreColor.opacity(0.3), lineWidth: 8)
                                        .frame(width: 104, height: 104)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(entry.overallScore) / 6.0)
                                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                        .frame(width: 104, height: 104)
                                        .rotationEffect(.degrees(-90))
                                    
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
                                    Text(noteSnippet(for: entry))
                                        .font(.poppins(.regular, size: 12))
                                        .foregroundColor(.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 14)
                                        .padding(.top, 12)
                                }
                                
                                // View Details button
                                HStack {
                                    Text("View Details")
                                        .font(.poppins(.regular, size: 14))
                                        .foregroundColor(.textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.textSecondary)
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
                                .padding(.top, 12)
                                .padding(.bottom, 14)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.borderColor.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            .background(Color.appBackground)
        }
        .safeAreaInset(edge: .bottom) {
            DateRecordsBottomNavigationView(onCalendarTap: {
                dismiss()
            }, onProfileTap: {
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
    }
}

// MARK: - Date Records Bottom Navigation
struct DateRecordsBottomNavigationView: View {
    let onCalendarTap: () -> Void
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
                NavButtonWithCustomCalendarIcon(isSelected: true, action: {
                    // Dismiss to go back to CalendarView
                    onCalendarTap()
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
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CalendarView()
        }
    }
}

