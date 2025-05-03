//
//  ContentView.swift
//  Ferienverwaltung
//
//  Created by Michael Schellenberger on 02.04.25.
//

import SwiftUI

struct HolidayListItemView: View {
    let viewModel: VacationViewModel
    let holiday: SchoolHoliday
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
    
    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    private func calculateDays() -> (total: Int, unattended: Int) {
        var total = 0
        var unattended = 0
        let calendar = Calendar.current
        
        let start = holiday.startDateObject
        let end = holiday.endDateObject
        // Optional: Prüfe auf Fallback-Werte, falls nötig
        // if start == Date.distantPast || end == Date.distantFuture { return (0, 0) }
        
        var currentDate = start
        while currentDate <= end {
            total += 1
            if viewModel.hasUnattendedDay(on: currentDate) {
                unattended += 1
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return (total, unattended)
    }
    
    var body: some View {
        let days = calculateDays()
        
        NavigationLink(destination: HolidayDetailView(viewModel: viewModel, holiday: holiday)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let name = holiday.name.first(where: { $0.language == "DE" })?.text {
                        Text(name)
                            .font(.headline)
                    }
                    Spacer()
                    if days.unattended > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text("\(days.unattended) unbetreut")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            Text("Betreut")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                let start = holiday.startDateObject
                let end = holiday.endDateObject
                // Optional: Prüfe auf Fallback-Werte
                // if start == Date.distantPast || end == Date.distantFuture { continue }
                
                HStack {
                    Text("\(dateFormatter.string(from: start)) - \(dateFormatter.string(from: end))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(days.total) \(days.total == 1 ? "Tag" : "Tage")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Fortschrittsbalken für betreute Tage
                if days.total > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: 8)
                                .opacity(0.2)
                                .foregroundColor(.gray)
                            
                            Rectangle()
                                .frame(width: geometry.size.width * CGFloat(days.total - days.unattended) / CGFloat(days.total), height: 8)
                                .foregroundColor(.green)
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 8)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct HolidayDetailView: View {
    let viewModel: VacationViewModel
    let holiday: SchoolHoliday
    
    @State private var showParentSelection = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
    
    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    private func getDaysInHoliday() -> [Date] {
        var days = [Date]()
        let calendar = Calendar.current
        
        let start = holiday.startDateObject
        let end = holiday.endDateObject
        // Optional: Prüfe auf Fallback-Werte
        // if start == Date.distantPast || end == Date.distantFuture { return [] }
        
        var currentDate = start
        while currentDate <= end {
            days.append(calendar.startOfDay(for: currentDate))
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return days
    }
    
    var body: some View {
        let days = getDaysInHoliday()
        let holidayName = holiday.name.first(where: { $0.language == "DE" })?.text ?? "Ferienzeitraum"
        let totalDays = days.count
        let unbetreut = days.filter { viewModel.hasUnattendedDay(on: $0) }.count
        let betreut = totalDays - unbetreut
        
        List {
            Section {
                let start = holiday.startDateObject
                let end = holiday.endDateObject
                // Optional: Prüfe auf Fallback-Werte
                // if start == Date.distantPast || end == Date.distantFuture { continue }
                
                HStack {
                    Text("Zeitraum:")
                    Spacer()
                    Text("\(dateFormatter.string(from: start)) - \(dateFormatter.string(from: end))")
                }
                
                HStack {
                    Text("Gesamttage:")
                    Spacer()
                    Text("\(totalDays)")
                }
                
                HStack {
                    Text("Betreute Tage:")
                    Spacer()
                    Text("\(betreut)")
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Unbetreute Tage:")
                    Spacer()
                    Text("\(unbetreut)")
                        .foregroundColor(unbetreut > 0 ? .red : .green)
                }
                
                // Fortschrittsbalken
                if totalDays > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Betreuungsstatus:")
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .frame(width: geometry.size.width, height: 20)
                                    .opacity(0.2)
                                    .foregroundColor(.gray)
                                
                                Rectangle()
                                    .frame(width: totalDays > 0 ? geometry.size.width * CGFloat(betreut) / CGFloat(totalDays) : 0, height: 20)
                                    .foregroundColor(.green)
                            }
                            .cornerRadius(4)
                            .overlay(
                                Text("\(totalDays > 0 ? Int(Double(betreut) / Double(totalDays) * 100) : 0)%")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.leading, 8),
                                alignment: .leading
                            )
                        }
                        .frame(height: 20)
                    }
                }
            }
            
            Section {
                Button(action: {
                    // Zeige die Elternauswahl für die unbetreuten Tage
                    showParentSelection = true
                }) {
                    Label("Betreuung für unbetreute Tage planen", systemImage: "calendar.badge.plus")
                }
                .disabled(unbetreut == 0)
            }
            .sheet(isPresented: $showParentSelection) {
                ParentSelectionView(viewModel: viewModel, holidayDays: days.filter { viewModel.hasUnattendedDay(on: $0) })
            }
            
            Section("Tagesübersicht") {
                ForEach(days, id: \.self) { date in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(dateFormatter.string(from: date))
                                .font(.headline)
                            Text(weekdayFormatter.string(from: date))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.hasUnattendedDay(on: date) {
                            HStack {
                                Text("Unbetreut")
                                    .foregroundColor(.red)
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        } else {
                            HStack {
                                Text("Betreut")
                                    .foregroundColor(.green)
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(holidayName)
    }
}

struct ContentView: View {
    @StateObject var viewModel = VacationViewModel()
    enum MainSection: Int, CaseIterable, Identifiable {
        case dashboard, family, holidays, settings
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .family: return "Familie"
            case .holidays: return "Ferien"
            case .settings: return "Einstellungen"
            }
        }
        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .family: return "person.2.fill"
            case .holidays: return "calendar"
            case .settings: return "gear"
            }
        }
    }
    @State private var selectedSection: MainSection = .dashboard
    @State private var isAddParentSheetPresented = false
    @State private var isSettingsPresented = false
    @State private var newParentName = ""
    @State private var showSplash = true
    @State private var showErrorAlert = false

    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView(isActive: $showSplash)
            } else {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            ForEach(MainSection.allCases) { section in
                                Button(action: { selectedSection = section }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: section.icon)
                                        Text(section.title)
                                    }
                                    .font(.system(size: 16, weight: selectedSection == section ? .bold : .regular))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(selectedSection == section ? Color.accentColor.opacity(0.13) : Color.clear)
                                    .cornerRadius(12)
                                }
                                .foregroundColor(selectedSection == section ? .accentColor : .primary)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        Group {
                            switch selectedSection {
                            case .dashboard:
                                NavigationStack {
                                    DashboardView(viewModel: viewModel)
                                }
                            case .family:
                                NavigationStack {
                                    VacationView(viewModel: viewModel)
                                }
                            case .holidays:
                                NavigationStack {
                                    HolidaysView(viewModel: viewModel)
                                }
                            case .settings:
                                NavigationStack {
                                    SettingsView(viewModel: viewModel)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .onAppear {
                        Task {
                            await viewModel.updateHolidayCacheIfNeeded()
                            viewModel.scheduleUnattendedHolidayNotifications()
                        }
                    }
                    .alert(isPresented: $showErrorAlert) {
                        Alert(
                            title: Text("Fehler beim Laden der Daten"),
                            message: Text(viewModel.error ?? "Unbekannter Fehler. Bitte Internetverbindung prüfen und App neu starten."),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                    .onChange(of: viewModel.error) { _, _ in
                        showErrorAlert = viewModel.error != nil
                    }
                    .onChange(of: viewModel.error) { _, _ in
                        showErrorAlert = viewModel.error != nil
                    }
                } else {
                    TabView(selection: $selectedSection) {
                        NavigationStack {
                            DashboardView(viewModel: viewModel)
                        }
                        .tabItem {
                            Label("Dashboard", systemImage: "house.fill")
                        }
                        .tag(MainSection.dashboard)
                        NavigationStack {
                            VacationView(viewModel: viewModel)
                        }
                            .tabItem {
                                Label("Familie", systemImage: "person.2.fill")
                            }
                            .tag(MainSection.family)
                        NavigationStack {
                            HolidaysView(viewModel: viewModel)
                        }
                            .tabItem {
                                Label("Ferien", systemImage: "calendar")
                            }
                            .tag(MainSection.holidays)
                        NavigationStack {
                            SettingsView(viewModel: viewModel)
                        }
                            .tabItem {
                                Label("Einstellungen", systemImage: "gear")
                            }
                            .tag(MainSection.settings)
                    }
                    .onAppear {
                        Task {
                            await viewModel.updateHolidayCacheIfNeeded()
                            viewModel.scheduleUnattendedHolidayNotifications()
                        }
                    }
                    .alert(isPresented: $showErrorAlert) {
                        Alert(
                            title: Text("Fehler beim Laden der Daten"),
                            message: Text(viewModel.error ?? "Unbekannter Fehler. Bitte Internetverbindung prüfen und App neu starten."),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                    .onChange(of: viewModel.error) { _, _ in
                        showErrorAlert = viewModel.error != nil
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView(viewModel: VacationViewModel())
}
