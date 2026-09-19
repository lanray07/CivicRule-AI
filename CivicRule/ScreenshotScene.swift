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
                        case "permits": LibraryView(business: business)
                        case "sources": ScreenshotSourceScene()
                        case "privacy": SettingsView()
                        case "address": ScreenshotAddressScene()
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
            if scene == "permits" {
                let expiry = Calendar.current.date(byAdding: .day, value: 42, to: .now)
                let permit = Permit(
                    businessID: business.id,
                    name: "Premises licence",
                    authority: "Local authority",
                    reference: "CR-2026-0142",
                    expiryDate: expiry
                )
                permit.status = PermitStatus.renewalDue.rawValue
                permit.renewalDate = Calendar.current.date(byAdding: .day, value: 30, to: .now)
                context.insert(permit)
            }
        }
    }
}

private struct ScreenshotSourceScene: View {
    private let source = OfficialSource(
        id: "govuk-pavement-licence",
        authority: "UK Government",
        title: "Pavement licences: guidance",
        jurisdiction: "England",
        url: "https://www.gov.uk/government/publications/pavement-licences-guidance",
        publicationDate: "2 April 2024",
        checkedAt: "19 September 2026",
        section: "Details",
        excerpt: "The permanent pavement licences process retains the streamlined consent route for businesses to obtain a licence to place removable furniture.",
        contentHash: "screenshot-fixture"
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("The rule behind the answer.").font(.system(.largeTitle, design: .serif))
                Text("Official evidence stays visible, dated and linked.").foregroundStyle(.secondary)
                SourceCard(source: source)
                Label("Property conditions and local requirements still need confirmation.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(maxWidth: 760)
        }.background(CivicTheme.paper).navigationTitle("Official source")
    }
}

private struct ScreenshotAddressScene: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Start with the right place.").font(.system(.largeTitle, design: .serif))
                CivicCard {
                    Eyebrow(text: "Proposed premises")
                    Label("London · prospective shop unit", systemImage: "mappin.and.ellipse")
                        .font(.title3.bold()).padding(.top, 10)
                    Text("Location is user-provided until the responsible authority is verified.")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 6)
                }
                EmptyCard(
                    icon: "building.2",
                    title: "Verify the responsible authority",
                    message: "Confirm the council and property-specific conditions before relying on local guidance."
                )
                CivicCard {
                    Eyebrow(text: "Areas to investigate")
                    Text("Planning · Licensing · Signage · Waste · Opening hours · Property conditions")
                        .font(.headline).padding(.top, 10)
                }
            }.padding(20).frame(maxWidth: 760)
        }.background(CivicTheme.paper).navigationTitle("Check an address")
    }
}
#endif
