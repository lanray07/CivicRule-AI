import SwiftUI

enum CivicTheme {
    static let forest = Color(red: 0.10, green: 0.24, blue: 0.20)
    static let lime = Color(red: 0.84, green: 0.92, blue: 0.61)
    static let paper = Color(uiColor: .systemGroupedBackground)
    static let amber = Color(red: 0.58, green: 0.34, blue: 0.10)
}

struct CivicCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.primary.opacity(0.055)))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(1.7).foregroundStyle(.secondary) }
}

struct CivicButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.vertical, 16).frame(maxWidth: .infinity)
            .foregroundStyle(.white).background(CivicTheme.forest, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct EmptyCard: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        CivicCard {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(CivicTheme.forest).padding(.bottom, 12)
            Text(title).font(.title3.bold())
            Text(message).font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
        }
    }
}

struct SourceCard: View {
    let source: OfficialSource
    var body: some View {
        CivicCard {
            Label("OFFICIAL SOURCE", systemImage: "checkmark.seal").font(.caption.bold()).foregroundStyle(CivicTheme.forest)
            Text(source.title).font(.headline).padding(.top, 8)
            Text(source.authority).font(.subheadline)
            Text(source.jurisdiction).font(.caption).foregroundStyle(.secondary)
            Divider().padding(.vertical, 8)
            Text(source.section).font(.subheadline.bold())
            Text("“\(source.excerpt)”").font(.subheadline).textSelection(.enabled)
            Text(source.publicationDate.map { "Published: \($0)" } ?? "Publication date not provided.").font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            Text("Last checked: \(source.checkedAt)").font(.caption).foregroundStyle(.secondary)
            if source.url.hasPrefix("https://www.gov.uk/") {
                Text("Contains public sector information licensed under the Open Government Licence v3.0.").font(.caption2).foregroundStyle(.secondary)
                Link("Open Government Licence", destination: URL(string: "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/")!).font(.caption2)
            }
            if let url = URL(string: source.url), url.scheme == "https" {
                Link(destination: url) { Label("View official source", systemImage: "arrow.up.right").font(.subheadline.bold()) }.padding(.top, 8)
            }
        }
    }
}
