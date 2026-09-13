import SwiftUI
import SwiftData

struct HomeView: View {
    let business: Business?
    let open: (AppSheet) -> Void
    @Query private var checks: [ChecklistItem]
    @Query private var permits: [Permit]
    var pending: Int { checks.filter { $0.businessID == business?.id && ![CheckStatus.completed.rawValue, CheckStatus.confirmed.rawValue].contains($0.status) }.count }
    var renewals: Int { permits.filter { $0.businessID == business?.id && ($0.renewalDate ?? $0.expiryDate).map { $0 >= .now && $0 < Date.now.addingTimeInterval(90 * 86400) } == true }.count }
    var greeting: String { Calendar.current.component(.hour, from: .now) < 12 ? "Good morning." : "Good afternoon." }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Eyebrow(text: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))); Spacer(); Label("Private workspace", systemImage: "lock").font(.caption2).foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting).font(.system(.largeTitle, design: .serif))
                    Text("Let’s make your next step clearer.").foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 18) {
                    HStack { Text("YOUR BUSINESS").font(.caption.bold()).tracking(2); Spacer(); Image(systemName: "storefront") }.foregroundStyle(CivicTheme.lime)
                    Text(business?.name ?? "A new beginning.").font(.system(.title, design: .serif)).foregroundStyle(.white)
                    Text(business?.address ?? "Add your business to build a checklist around your plans.").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    Divider().overlay(.white.opacity(0.2))
                    if business != nil {
                        HStack(alignment: .top, spacing: 36) {
                            metric("\(pending)", "items to check")
                            metric("\(renewals)", "upcoming dates")
                        }
                        Label("Source monitoring not yet connected", systemImage: "clock").font(.caption).foregroundStyle(.white.opacity(0.75))
                    } else {
                        Button { open(.business) } label: { Label("Add my business", systemImage: "plus").font(.headline).foregroundStyle(CivicTheme.forest).padding(14).background(CivicTheme.lime, in: Capsule()) }
                    }
                }.padding(24).background(CivicTheme.forest.gradient, in: RoundedRectangle(cornerRadius: 28))
                HStack { Eyebrow(text: "How can we help?"); Spacer() }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 14) {
                    action("Ask a question", "Start with what’s on your mind", "text.bubble", .ask)
                    action("Ask by voice", "Talk it through, naturally", "waveform", .voice)
                    action("Check an address", "Get to know your premises", "mappin.and.ellipse", .address)
                    action("Explain a notice", "Keep the original in view", "doc.viewfinder", .scan)
                }
                Button { open(.lease) } label: {
                    CivicCard {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "key.horizontal").font(.title2).foregroundStyle(CivicTheme.amber)
                            VStack(alignment: .leading, spacing: 6) { Eyebrow(text: "Before you commit"); Text("A little clarity before\nyou sign the lease.").font(.system(.title3, design: .serif)); Text("Build your pre-check →").font(.caption.bold()).padding(.top, 6) }
                            Spacer()
                        }
                    }
                }.buttonStyle(.plain)
                Label("Informational support. Always check the source and confirm property-specific conditions.", systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(maxWidth: 900)
        }.background(CivicTheme.paper).navigationBarTitleDisplayMode(.inline)
    }
    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(value).font(.system(.largeTitle, design: .rounded).weight(.light)).foregroundStyle(CivicTheme.lime); Text(label).font(.caption).foregroundStyle(.white.opacity(0.85)) }
    }
    private func action(_ title: String, _ subtitle: String, _ icon: String, _ route: AppSheet) -> some View {
        Button { open(route) } label: {
            CivicCard { VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).font(.title2).foregroundStyle(CivicTheme.forest).frame(width: 44, height: 44).background(CivicTheme.lime.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                Text(title).font(.subheadline.bold()); Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, minHeight: 125, alignment: .topLeading) }
        }.buttonStyle(.plain)
    }
}
