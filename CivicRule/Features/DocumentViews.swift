import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit
import VisionKit

struct DocumentImportView: View {
    let business: Business?
    @Environment(\.modelContext) private var context
    @State private var importing = false
    @State private var scanning = false
    @State private var busy = false
    @State private var notice: Notice?
    @State private var error = ""
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            Text("Make sense of\nwhat’s in front of you.").font(.system(.largeTitle, design: .serif))
            EmptyCard(icon: "doc.viewfinder", title: "Your document, kept intact", message: "Import a PDF, photo or screenshot. Text recognition runs on your device. You can compare extracted text with the original at any time.")
            Button("Import a document", systemImage: "square.and.arrow.down") { importing = true }.buttonStyle(CivicButton()).disabled(business == nil || busy)
            if VNDocumentCameraViewController.isSupported {
                Button("Scan a paper notice", systemImage: "camera") { scanning = true }.disabled(business == nil || busy)
            }
            if business == nil { Text("Add a business before saving documents.").font(.caption) }
            if busy { ProgressView("Reading on this device…") }
            if !error.isEmpty { Text(error).foregroundStyle(CivicTheme.amber) }
            if let notice { NavigationLink("Review extracted text") { NoticeDetail(notice: notice) }.buttonStyle(CivicButton()) }
        }.padding(20).frame(maxWidth: 760) }.background(CivicTheme.paper).navigationTitle("Explain a notice")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image]) { result in
                Task {
                    do {
                        let url = try result.get()
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        guard size <= 20_000_000 else { throw CivicError.message("Choose a document smaller than 20 MB.") }
                        let data = try Data(contentsOf: url)
                        await ingest(data, isPDF: url.pathExtension.lowercased() == "pdf", title: url.lastPathComponent)
                    } catch { self.error = error.localizedDescription }
                }
            }
            .sheet(isPresented: $scanning) {
                NoticeCamera { result in
                    scanning = false
                    switch result {
                    case .success(let data): Task { await ingest(data, isPDF: true, title: "Scanned notice") }
                    case .failure(let failure): error = failure.localizedDescription
                    }
                }
            }
    }
    private func ingest(_ data: Data, isPDF: Bool, title: String) async {
        guard let business else { return }
        busy = true; error = ""; notice = nil
        defer { busy = false }
        do {
            let extracted = try await DocumentService.extract(data: data, isPDF: isPDF)
            let newNotice = Notice(businessID: business.id, title: title, pages: extracted.pages, original: data, fileType: extracted.type)
            context.insert(newNotice); try context.save(); notice = newNotice
        } catch { context.rollback(); self.error = error.localizedDescription }
    }
}

struct NoticeDetail: View {
    let notice: Notice
    @State private var showOriginal = false
    @State private var date = Date.now.addingTimeInterval(86400)
    @State private var confirmed = false
    @State private var message = ""
    var body: some View {
        List {
            Section {
                Button(showOriginal ? "Show extracted text" : "Inspect original document") { showOriginal.toggle() }
                Text("OCR can misread wording and dates. Compare every important detail with the original. AI interpretation is not connected in this build.").font(.caption).foregroundStyle(.secondary)
            }
            if showOriginal {
                Section("Original") {
                    if notice.fileType == "pdf" { OriginalPDF(data: notice.original).frame(height: 550) }
                    else if let image = UIImage(data: notice.original) { Image(uiImage: image).resizable().scaledToFit() }
                }
            } else {
                Section("Wording that may mention an action or date") {
                    let lines = DocumentService.actionLines(notice.pages)
                    if lines.isEmpty { Text("No action or date phrases were detected. This does not mean the document has no deadlines.") }
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 6) { Eyebrow(text: "Page \(entry.0) · extracted wording"); Text(entry.1).textSelection(.enabled) }
                    }
                }
                ForEach(Array(notice.pages.enumerated()), id: \.offset) { index, page in
                    Section("Page \(index + 1) · full extracted text") { Text(page.isEmpty ? "No text was recognised on this page. Inspect the original." : page).font(.subheadline).textSelection(.enabled) }
                }
            }
            Section("Add a date you have verified") {
                DatePicker("Reminder date and time", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                Toggle("I checked this date against the original wording", isOn: $confirmed)
                Button("Add reminder") { Task { do { try await ReminderService().addReminder(id: notice.id, name: notice.title, date: date, daysBefore: 0); message = "Reminder added." } catch { message = error.localizedDescription } } }.disabled(!confirmed)
                if !message.isEmpty { Text(message).font(.caption) }
            }
        }.navigationTitle(notice.title).navigationBarTitleDisplayMode(.inline)
            .onChange(of: date) { _, _ in confirmed = false }
    }
}

struct OriginalPDF: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.document = PDFDocument(data: data); return view }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

struct NoticeCamera: UIViewControllerRepresentable {
    var completion: (Result<Data, Error>) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController { let controller = VNDocumentCameraViewController(); controller.delegate = context.coordinator; return controller }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: NoticeCamera
        init(parent: NoticeCamera) { self.parent = parent }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { parent.dismiss() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { parent.completion(.failure(error)) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount <= 50 else { parent.completion(.failure(CivicError.message("Scan up to 50 pages at a time."))); return }
            let document = PDFDocument()
            for index in 0..<scan.pageCount { if let page = PDFPage(image: scan.imageOfPage(at: index)) { document.insert(page, at: document.pageCount) } }
            guard let data = document.dataRepresentation() else { parent.completion(.failure(CivicError.message("Could not save scan."))); return }
            parent.completion(.success(data))
        }
    }
}
