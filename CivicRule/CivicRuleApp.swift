import SwiftUI
import SwiftData

@main struct CivicRuleApp: App {
    var body: some Scene {
        WindowGroup { AppRoot() }
            .modelContainer(for: [Business.self, ChecklistItem.self, Permit.self, SavedAnswer.self, Notice.self])
    }
}

enum AppSheet: String, Identifiable {
    case business, ask, voice, address, scan, lease, settings
    var id: String { rawValue }
}

struct AppRoot: View {
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("appLock") private var appLock = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var lockError = ""
    var body: some View {
        Group {
            if appLock && !unlocked {
                VStack(spacing: 24) {
                    Image(systemName: "lock.shield").font(.system(size: 56)).foregroundStyle(CivicTheme.forest)
                    Text("Your business stays yours.").font(.title2.bold())
                    Button("Unlock CivicRule") { Task { await unlock() } }.buttonStyle(CivicButton())
                    Text(lockError).font(.caption).foregroundStyle(.secondary)
                }.padding(32).task { await unlock() }
            } else if onboarded { MainView() }
            else { OnboardingView { onboarded = true } }
        }
        .tint(CivicTheme.forest)
        .onChange(of: scenePhase) { _, phase in if phase != .active { unlocked = false } }
        .privacySensitive()
    }
    private func unlock() async {
        do { unlocked = try await PrivacyService.authenticate() }
        catch { lockError = error.localizedDescription }
    }
}

struct MainView: View {
    @Query(sort: \Business.created) private var businesses: [Business]
    @AppStorage("selectedBusiness") private var selectedID = ""
    @State private var sheet: AppSheet?
    var business: Business? { businesses.first { $0.id.uuidString == selectedID } ?? businesses.first }
    var body: some View {
        TabView {
            NavigationStack {
                HomeView(business: business, open: { sheet = $0 })
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Label("civicrule", systemImage: "building.2.crop.circle.fill").font(.headline)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                ForEach(businesses) { item in Button(item.name) { selectedID = item.id.uuidString } }
                                Button("Add a business", systemImage: "plus") { sheet = .business }
                                Button("Settings", systemImage: "gearshape") { sheet = .settings }
                            } label: { Image(systemName: "person.crop.circle").font(.title2) }
                            .accessibilityLabel("Business profiles and settings")
                        }
                    }
            }.tabItem { Label("Overview", systemImage: "square.grid.2x2") }
            NavigationStack { ChecklistView(business: business) }.tabItem { Label("Checklist", systemImage: "checklist") }
            NavigationStack { LibraryView(business: business) }.tabItem { Label("My records", systemImage: "folder") }
            NavigationStack { RuleWatchView() }.tabItem { Label("Rule Watch", systemImage: "bell.badge") }
        }
        .sheet(item: $sheet) { route in
            NavigationStack {
                Group {
                    switch route {
                    case .business: BusinessEditor()
                    case .ask: AskView(business: business, startWithVoice: false)
                    case .voice: AskView(business: business, startWithVoice: true)
                    case .address: AddressView()
                    case .scan: DocumentImportView(business: business)
                    case .lease: LeaseView(business: business)
                    case .settings: SettingsView()
                    }
                }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { sheet = nil } } }
            }.tint(CivicTheme.forest)
        }
    }
}

