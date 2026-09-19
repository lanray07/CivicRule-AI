#if DEBUG
import SwiftUI
import SwiftData

// Compiled out of Release. Renders the real feature views with fictional local records.
struct ScreenshotScene: View {
    let scene: String
    @Environment(\.modelContext) private var context
    @State private var business: Business

    init(scene: String) {
        self.scene = scene
        _business = State(initialValue: Business(
            name: "Lanre’s Barbers",
            kind: "Barber",
            address: "London · prospective premises",
            nation: "England",
            authority: "To be confirmed",
            activities: "Haircuts and grooming",
            hours: "Monday–Saturday, 9am–6pm"
        ))
    }

    var body: some View {
        Group {
            if scene == "welcome" { OnboardingView {} }
            else {
                NavigationStack {
                    Group {
                        switch scene {
                        case "checklist": ChecklistView(business: business)
                        case "voice": AskView(business: business, startWithVoice: true)
                        case "documents": DocumentImportView(business: business)
                        case "lease": LeaseView(business: business)
                        default: HomeView(business: business, open: { _ in })
                        }
                    }
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Label("civicrule", systemImage: "building.2.crop.circle.fill").font(.headline) } }
                }
            }
        }.tint(CivicTheme.forest).task {
            guard scene != "welcome", business.modelContext == nil else { return }
            context.insert(business)
            for (category,title) in BusinessTemplates.checks(for: business.kind) {
                context.insert(ChecklistItem(businessID: business.id, title: title, category: category))
            }
        }
    }
}
#endif
