import SwiftUI
import SwiftData
import MapKit

struct BusinessEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind = "Barber"
    @State private var address = ""
    @State private var nation = "England"
    @State private var authority = ""
    @State private var activities = ""
    @State private var hours = ""
    @State private var error = ""
    var body: some View {
        Form {
            Section("Your business") {
                TextField("Business name", text: $name)
                Picker("Business type", selection: $kind) { ForEach(BusinessTemplates.kinds, id: \.self) { Text($0) } }
                TextField("Activities you plan to offer", text: $activities, axis: .vertical)
                TextField("Planned opening hours", text: $hours)
            }
            Section {
                TextField("Full premises address", text: $address, axis: .vertical)
                Picker("Nation", selection: $nation) { ForEach(["England", "Wales", "Scotland", "Northern Ireland", "Other / not yet supported"], id: \.self) { Text($0) } }
                TextField("Local authority (if known)", text: $authority)
                Link("Find your council on GOV.UK", destination: URL(string: "https://www.gov.uk/find-local-council")!)
            } header: { Text("Location comes first") } footer: { Text("The authority you enter is user-provided, not a verified boundary match. Current source coverage is limited to an England pavement-seating pilot.") }
            Section { Text("We’ll create investigation prompts for your business type. These are things to verify, not a determination of legal requirements.").font(.subheadline) }
            Button("Create my business") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || address.trimmingCharacters(in: .whitespaces).isEmpty)
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }.navigationTitle("A little about your business").navigationBarTitleDisplayMode(.inline)
    }
    private func save() {
        let business = Business(name: name, kind: kind, address: address, nation: nation, authority: authority, activities: activities, hours: hours)
        context.insert(business)
        for (category, title) in BusinessTemplates.checks(for: kind) { context.insert(ChecklistItem(businessID: business.id, title: title, category: category)) }
        do { try context.save(); dismiss() } catch { context.rollback(); self.error = error.localizedDescription }
    }
}

struct ChecklistView: View {
    let business: Business?
    @Query private var all: [ChecklistItem]
    @Environment(\.modelContext) private var context
    @State private var filter = "All"
    @State private var error = ""
    var items: [ChecklistItem] { all.filter { $0.businessID == business?.id && (filter == "All" || $0.status == filter) }.sorted { $0.category < $1.category } }
    var body: some View {
        List {
            Section {
                Text("Before you open").font(.system(.title, design: .serif))
                Text(business?.name ?? "Add a business from Overview to get started.").foregroundStyle(.secondary)
                Text("Your progress records what you’ve checked. It does not certify compliance.").font(.caption).foregroundStyle(.secondary)
                Picker("Show", selection: $filter) { Text("All").tag("All"); ForEach(CheckStatus.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
            }
            if items.isEmpty { ContentUnavailableView("Nothing here yet", systemImage: "checklist", description: Text("Your investigation prompts and saved answer checks will appear here.")) }
            ForEach(items) { item in ChecklistRow(item: item) }
                .onDelete { indices in for index in indices { context.delete(items[index]) }; do { try context.save() } catch { self.error = error.localizedDescription } }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }.navigationTitle("My checklist")
    }
}

struct ChecklistRow: View {
    @Bindable var item: ChecklistItem
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: item.category)
            Text(item.title).font(.headline)
            Picker("Status", selection: $item.status) { ForEach(CheckStatus.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }.font(.caption)
            TextField("Evidence or notes", text: $item.notes, axis: .vertical).font(.subheadline)
            if let url = URL(string: item.sourceURL), url.scheme == "https" { Link("View supporting source", destination: url).font(.caption) }
        }.padding(.vertical, 8)
    }
}

struct LeaseView: View {
    let business: Business?
    @Environment(\.modelContext) private var context
    @State private var address = ""
    @State private var hours = ""
    @State private var signage = false
    @State private var outdoor = false
    @State private var alterations = false
    @State private var food = false
    @State private var alcohol = false
    @State private var created = false
    @State private var error = ""
    var body: some View {
        Form {
            Section { Text("Before you sign, know what to ask.").font(.system(.title, design: .serif)); Text("Informational due diligence support. These prompts do not establish whether the premises are suitable.").font(.subheadline).foregroundStyle(.secondary) }
            Section("Your proposed premises") {
                TextField("Address", text: $address, axis: .vertical)
                Text(business?.kind ?? "Add a business first")
                TextField("Proposed opening hours", text: $hours)
                Toggle("New signage", isOn: $signage); Toggle("Outdoor use", isOn: $outdoor)
                Toggle("Building alterations", isOn: $alterations); Toggle("Food service", isOn: $food); Toggle("Alcohol activity", isOn: $alcohol)
            }
            Button(created ? "Pre-check added to your checklist" : "Build my lease pre-check") { generate() }.disabled(business == nil || address.isEmpty || created)
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Lease pre-check").task { address = business?.address ?? ""; hours = business?.hours ?? "" }
    }
    private func generate() {
        guard let business else { return }
        var titles = ["Verify the authorised use and suitability for \(business.kind)", "Check lease restrictions and property-specific conditions", "Confirm permitted hours against your plan: \(hours.isEmpty ? "not yet specified" : hours)", "Review waste and storage arrangements"]
        if signage { titles.append("Ask about permissions for proposed signs") }
        if outdoor { titles.append("Verify ownership and permissions for outdoor use") }
        if alterations { titles.append("Check permissions and approvals for alterations") }
        if food { titles.append("Investigate food-business requirements") }
        if alcohol { titles.append("Investigate alcohol licensing for the planned activities") }
        for title in titles { let item = ChecklistItem(businessID: business.id, title: title, category: "Lease pre-check"); item.notes = "Proposed premises: \(address)"; context.insert(item) }
        do { try context.save(); created = true } catch { context.rollback(); self.error = error.localizedDescription }
    }
}

struct AddressView: View {
    @State private var address = ""
    @State private var results: [MKMapItem] = []
    @State private var selected: MKMapItem?
    @State private var busy = false
    @State private var error = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Start with the right place.").font(.system(.largeTitle, design: .serif))
                TextField("Enter the full address", text: $address).textFieldStyle(.roundedBorder).textContentType(.fullStreetAddress)
                Text("Searching shares this address with Apple Maps. A map result does not verify the regulatory authority or property use.").font(.caption).foregroundStyle(.secondary)
                Button(busy ? "Searching…" : "Find address") { Task { await search() } }.buttonStyle(CivicButton()).disabled(busy || address.isEmpty)
                ForEach(Array(results.enumerated()), id: \.offset) { _, item in Button { selected = item } label: { Label(item.placemark.title ?? item.name ?? "Address", systemImage: "mappin").frame(maxWidth: .infinity, alignment: .leading).padding(12) } }
                if let selected {
                    Map { Marker(selected.name ?? "Premises", coordinate: selected.placemark.coordinate) }.frame(height: 250).clipShape(RoundedRectangle(cornerRadius: 24))
                    EmptyCard(icon: "building.2", title: "Verify the responsible authority", message: "No verified authority boundary dataset is connected. Confirm the council before using local guidance.")
                    Link("Find the local council", destination: URL(string: "https://www.gov.uk/find-local-council")!)
                    CivicCard { Eyebrow(text: "Areas to investigate"); Text("Planning · Licensing · Signage · Waste · Operating restrictions · Property conditions").padding(.top, 8) }
                }
                if !error.isEmpty { Text(error).foregroundStyle(CivicTheme.amber) }
            }.padding(20).frame(maxWidth: 760)
        }.navigationTitle("Check an address").background(CivicTheme.paper)
    }
    private func search() async {
        busy = true; error = ""; results = []; selected = nil
        defer { busy = false }
        do { let request = MKLocalSearch.Request(); request.naturalLanguageQuery = address; let response = try await MKLocalSearch(request: request).start(); results = response.mapItems; if results.isEmpty { error = "No matching addresses found. Try adding the postcode." } }
        catch { self.error = error.localizedDescription }
    }
}
