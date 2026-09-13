import SwiftUI
import SwiftData

struct LibraryView: View {
    let business: Business?
    @Query private var allPermits: [Permit]
    @Query private var allAnswers: [SavedAnswer]
    @Query private var allNotices: [Notice]
    @Environment(\.modelContext) private var context
    @State private var addingPermit = false
    @State private var error = ""
    var permits: [Permit] { allPermits.filter { $0.businessID == business?.id } }
    var answers: [SavedAnswer] { allAnswers.filter { $0.businessID == business?.id }.sorted { $0.savedAt > $1.savedAt } }
    var notices: [Notice] { allNotices.filter { $0.businessID == business?.id }.sorted { $0.created > $1.created } }
    var body: some View {
        List {
            Section("My permits") {
                if permits.isEmpty { Text("Keep applications, references and renewal dates together.").foregroundStyle(.secondary) }
                ForEach(permits) { permit in
                    NavigationLink { PermitDetail(permit: permit) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(permit.name).font(.headline)
                            Text(permit.status).font(.caption).foregroundStyle(.secondary)
                            if let date = permit.expiryDate { Text("Recorded expiry: \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(date < .now ? .red : .secondary) }
                        }
                    }
                }.onDelete { offsets in for index in offsets { ReminderService().removeReminders(id: permits[index].id); context.delete(permits[index]) }; save() }
                Button("Add a permit", systemImage: "plus") { addingPermit = true }.disabled(business == nil)
            }
            Section("Saved answers") {
                if answers.isEmpty { Text("Source-backed answers you save will be available offline.").foregroundStyle(.secondary) }
                ForEach(answers) { saved in
                    NavigationLink {
                        ScrollView { VStack(alignment: .leading, spacing: 20) {
                            Label("Saved answer — sources may have changed. See each source’s last checked date.", systemImage: "clock").font(.caption).foregroundStyle(CivicTheme.amber)
                            if let answer = saved.answer { AnswerContent(answer: answer) }
                            else { Text("This saved answer could not be decoded.") }
                        }.padding(20) }.background(CivicTheme.paper).navigationTitle("Saved answer")
                    } label: { Text(saved.question) }
                }.onDelete { offsets in for index in offsets { context.delete(answers[index]) }; save() }
            }
            Section("Documents") {
                if notices.isEmpty { Text("Import or scan a notice from Overview. Original files stay on this device.").foregroundStyle(.secondary) }
                ForEach(notices) { notice in NavigationLink(notice.title) { NoticeDetail(notice: notice) } }
                    .onDelete { offsets in for index in offsets { ReminderService().removeReminders(id: notices[index].id); context.delete(notices[index]) }; save() }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }.navigationTitle("My records")
            .sheet(isPresented: $addingPermit) { NavigationStack { PermitEditor(business: business) } }
    }
    private func save() { do { try context.save() } catch { self.error = error.localizedDescription } }
}

struct PermitEditor: View {
    let business: Business?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var authority = ""
    @State private var reference = ""
    @State private var hasExpiry = false
    @State private var expiry = Date.now
    @State private var error = ""
    var body: some View {
        Form {
            TextField("Permit or licence name", text: $name)
            TextField("Authority", text: $authority)
            TextField("Reference", text: $reference)
            Toggle("I have a confirmed expiry date", isOn: $hasExpiry)
            if hasExpiry { DatePicker("Recorded expiry", selection: $expiry, displayedComponents: .date) }
            Text("Dates you enter are your records; they are not confirmed against authority systems.").font(.caption).foregroundStyle(.secondary)
            Button("Save permit") {
                guard let business else { return }
                context.insert(Permit(businessID: business.id, name: name, authority: authority, reference: reference, expiryDate: hasExpiry ? expiry : nil))
                do { try context.save(); dismiss() } catch { context.rollback(); self.error = error.localizedDescription }
            }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || business == nil)
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Add a permit").toolbar { Button("Cancel") { dismiss() } }.task { authority = business?.authority ?? "" }
    }
}

struct PermitDetail: View {
    @Bindable var permit: Permit
    @State private var days = 30
    @State private var message = ""
    var body: some View {
        Form {
            Section("Your record") {
                TextField("Name", text: $permit.name); TextField("Authority", text: $permit.authority); TextField("Reference", text: $permit.reference)
                Picker("Status", selection: $permit.status) { ForEach(PermitStatus.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
                OptionalDateRow(title: "Application date", date: $permit.applicationDate)
                OptionalDateRow(title: "Issue date", date: $permit.issueDate)
                OptionalDateRow(title: "Expiry date", date: $permit.expiryDate)
                OptionalDateRow(title: "Renewal date", date: $permit.renewalDate)
                TextField("Notes", text: $permit.notes, axis: .vertical)
            }
            Section("Optional reminder") {
                Text("Confirm the date against your original document before adding a reminder.").font(.caption)
                Picker("Remind me", selection: $days) { ForEach([90, 60, 30, 14, 7, 1], id: \.self) { Text("\($0) days before").tag($0) } }
                Button("Add reminder for recorded date") { Task {
                    guard let date = permit.renewalDate ?? permit.expiryDate else { return }
                    do { try await ReminderService().addReminder(id: permit.id, name: permit.name, date: date, daysBefore: days); message = "Reminder added for your recorded date." }
                    catch { message = error.localizedDescription }
                } }.disabled(permit.renewalDate == nil && permit.expiryDate == nil)
                if !message.isEmpty { Text(message).font(.caption) }
            }
        }.navigationTitle("Permit details")
            .onChange(of: permit.expiryDate) { _, _ in ReminderService().removeReminders(id: permit.id); message = "Date changed. Add reminders again for the new date." }
            .onChange(of: permit.renewalDate) { _, _ in ReminderService().removeReminders(id: permit.id); message = "Date changed. Add reminders again for the new date." }
    }
}

struct OptionalDateRow: View {
    let title: String
    @Binding var date: Date?
    var body: some View {
        Toggle(title, isOn: Binding(get: { date != nil }, set: { date = $0 ? .now : nil }))
        if date != nil { DatePicker(title, selection: Binding(get: { date ?? .now }, set: { date = $0 }), displayedComponents: .date) }
    }
}

struct RuleWatchView: View {
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            Text("When the rules move,\nstay in the picture.").font(.system(.largeTitle, design: .serif))
            EmptyCard(icon: "bell.badge", title: "Monitoring is not active", message: "There is no live Rule Watch subscription for this device yet. No recent changes does not mean that the rules have stayed the same.")
            CivicCard { Eyebrow(text: "Designed around evidence"); Text("Source refreshes compare meaningful page text. Changes are held for review before they can support another answer.").padding(.top, 8); Text("Business-specific alerts will show the previous text, new text, detection date and affected checklist items once the monitoring service is connected.").font(.subheadline).foregroundStyle(.secondary).padding(.top, 8) }
        }.padding(20).frame(maxWidth: 760) }.background(CivicTheme.paper).navigationTitle("Rule Watch")
    }
}

