import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var businesses: [Business]
    @Query private var checks: [ChecklistItem]
    @Query private var permits: [Permit]
    @Query private var answers: [SavedAnswer]
    @Query private var notices: [Notice]
    @AppStorage("appLock") private var appLock = false
    @AppStorage("cloudConsent") private var cloudConsent = false
    @AppStorage("speechRate") private var speechRate = 0.48
    @AppStorage("readSources") private var readSources = false
    @AppStorage("onboarded") private var onboarded = false
    @State private var deleteAll = false
    @State private var deletingBusiness: Business?
    @State private var export: ExportDocument?
    @State private var exporting = false
    @State private var message = ""
    @State private var token = ""
    @State private var store = StoreService()
    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Require device authentication", isOn: Binding(get: { appLock }, set: { newValue in
                    Task { do { if try await PrivacyService.authenticate() { appLock = newValue } } catch { message = error.localizedDescription } }
                }))
                Toggle("Send questions to the source service", isOn: $cloudConsent)
                Text("Business records and original documents are stored locally. Only questions, nation, authority, business type and activities are sent when you enable live questions. Voice audio and document OCR stay on device. No advertising or analytics SDK is included.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Spoken answers") {
                Toggle("Read source titles aloud", isOn: $readSources)
                Slider(value: $speechRate, in: 0.3...0.6) { Text("Speech rate") }
                Text("Speech rate: \(speechRate, specifier: "%.2f")").font(.caption)
            }
            Section("Your data") {
                Button("Export all records and original documents") { buildExport() }
                Button("Delete saved question history", role: .destructive) { for answer in answers { context.delete(answer) }; persist() }
                ForEach(businesses) { business in Button("Delete \(business.name)", role: .destructive) { deletingBusiness = business } }
                Button("Delete all local data", role: .destructive) { deleteAll = true }
                Text("There is no cloud account in this build. Device backups and any exports you make are managed separately.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Membership") {
                Text("CivicRule is in development. Purchases are not available; no subscription pricing has been assumed from the unfinished brief.").font(.subheadline)
                ForEach(store.products) { product in Button("\(product.displayName) · \(product.displayPrice)") { Task { await store.purchase(product) } }.disabled(store.busy) }
                Button("Restore purchases") { Task { await store.restore() } }
                if !store.message.isEmpty { Text(store.message).font(.caption) }
            }
            Section("Pilot connection") {
                SecureField("Service access token", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Save token to Keychain") { do { try KeychainService.save(token, key: "apiToken"); token = ""; message = "Token saved securely." } catch { message = error.localizedDescription } }.disabled(token.count < 32)
                Text("The HTTPS service URL is configured at build time. Never put a service secret in the app bundle.").font(.caption).foregroundStyle(.secondary)
            }
            Section { Button("View introduction again") { onboarded = false }; Text("CivicRule AI · Local Permits & Compliance\nKnow what the rules say before you act.").font(.caption).foregroundStyle(.secondary) }
            if !message.isEmpty { Text(message).font(.caption) }
        }.navigationTitle("Settings").task { await store.load() }
            .confirmationDialog("Delete every local business, permit, answer and document?", isPresented: $deleteAll, titleVisibility: .visible) {
                Button("Delete all local data", role: .destructive) {
                    for business in businesses { context.delete(business) }
                    for item in checks { context.delete(item) }; for item in permits { context.delete(item) }
                    for item in answers { context.delete(item) }; for item in notices { context.delete(item) }
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                    KeychainService.deleteAll(); cloudConsent = false; persist()
                }
            }
            .confirmationDialog("Delete this business and its records?", isPresented: Binding(get: { deletingBusiness != nil }, set: { if !$0 { deletingBusiness = nil } }), titleVisibility: .visible) {
                Button("Delete business", role: .destructive) { if let business = deletingBusiness { remove(business); persist() }; deletingBusiness = nil }
            }
            .fileExporter(isPresented: $exporting, document: export, contentType: .json, defaultFilename: "CivicRule-export") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
                export = nil
            }
    }
    private func persist() { do { try context.save(); message = "Changes saved." } catch { context.rollback(); message = error.localizedDescription } }
    private func remove(_ business: Business) {
        for item in checks where item.businessID == business.id { context.delete(item) }
        for item in permits where item.businessID == business.id { ReminderService().removeReminders(id: item.id); context.delete(item) }
        for item in answers where item.businessID == business.id { context.delete(item) }
        for item in notices where item.businessID == business.id { ReminderService().removeReminders(id: item.id); context.delete(item) }
        context.delete(business)
    }
    private func buildExport() {
        let object: [String: Any] = [
            "schemaVersion": 1, "exportedAt": Date.now.ISO8601Format(),
            "businesses": businesses.map { ["id": $0.id.uuidString, "name": $0.name, "kind": $0.kind, "address": $0.address, "nation": $0.nation, "authority": $0.authority, "activities": $0.activities, "hours": $0.hours, "created": $0.created.ISO8601Format()] },
            "checklist": checks.map { ["id": $0.id.uuidString, "businessID": $0.businessID.uuidString, "title": $0.title, "category": $0.category, "status": $0.status, "sourceURL": $0.sourceURL, "notes": $0.notes] },
            "permits": permits.map { ["id": $0.id.uuidString, "businessID": $0.businessID.uuidString, "name": $0.name, "authority": $0.authority, "reference": $0.reference, "status": $0.status, "applicationDate": $0.applicationDate?.ISO8601Format() ?? "", "issueDate": $0.issueDate?.ISO8601Format() ?? "", "expiryDate": $0.expiryDate?.ISO8601Format() ?? "", "renewalDate": $0.renewalDate?.ISO8601Format() ?? "", "notes": $0.notes] },
            "answers": answers.map { ["id": $0.id.uuidString, "businessID": $0.businessID.uuidString, "question": $0.question, "savedAt": $0.savedAt.ISO8601Format(), "payloadBase64": $0.payload.base64EncodedString()] },
            "documents": notices.map { ["id": $0.id.uuidString, "businessID": $0.businessID.uuidString, "title": $0.title, "pages": $0.pages, "fileType": $0.fileType, "originalBase64": $0.original.base64EncodedString(), "created": $0.created.ISO8601Format()] as [String: Any] }
        ]
        do { export = ExportDocument(data: try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])); exporting = true }
        catch { message = error.localizedDescription }
    }
}
