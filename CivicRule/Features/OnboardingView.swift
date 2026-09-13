import SwiftUI

struct OnboardingView: View {
    var finish: () -> Void
    @State private var page = 0
    private let headlines = ["Before you open,\nknow what to check.", "Ask normal\nquestions.", "See the rule\nbehind the answer.", "Ask while you’re\nat the property.", "A clear path\nto opening day.", "Stay aware as\nregulations change."]
    private let details = ["Local requirements. Plain-English answers. Sources included.", "From your first idea to your next premises, start with what you want to do.", "Official sources, checked dates and honest limitations accompany every supported answer.", "Speak naturally, review your words, then ask. On-device transcription keeps your audio local.", "Turn the things you need to verify into a practical business checklist.", "Rule Watch is being prepared. Until monitoring is connected, no live change coverage is claimed."]
    private let icons = ["storefront", "text.bubble", "doc.text.magnifyingglass", "waveform", "checklist", "bell.badge"]
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            HStack { Label("civicrule", systemImage: "building.2.crop.circle.fill").font(.title3.bold()); Spacer(); Text("\(page + 1) / 6").font(.caption.monospacedDigit()) }
            Spacer()
            ZStack {
                if page == 0 || page == 3 {
                    GeometryReader { geometry in
                        Image(page == 3 ? "CafeOwner" : "ShopOwner").resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    }
                } else {
                  RoundedRectangle(cornerRadius: 40).fill(CivicTheme.forest.gradient)
                  VStack(spacing: 24) {
                    Image(systemName: icons[page]).font(.system(size: 90, weight: .ultraLight)).foregroundStyle(CivicTheme.lime)
                    Text(page == 0 ? "YOUR NEXT CHAPTER\nSTARTS HERE" : "KNOW WHAT TO CHECK").font(.caption.bold()).tracking(3).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8))
                  }.padding(24)
                }
            }.frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 32)).accessibilityHidden(true)
            Text(headlines[page]).font(.system(.largeTitle, design: .serif).weight(.medium)).fixedSize(horizontal: false, vertical: true)
            Text(details[page]).font(.body).foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) { ForEach(0..<6) { index in Capsule().fill(index == page ? CivicTheme.forest : Color.secondary.opacity(0.2)).frame(width: index == page ? 24 : 6, height: 6) } }.accessibilityLabel("Page \(page + 1) of 6")
            Button(page == 5 ? "Check my business" : "Continue") { if page == 5 { finish() } else { withAnimation { page += 1 } } }.buttonStyle(CivicButton())
            Button("Get started now", action: finish).font(.subheadline).frame(maxWidth: .infinity)
        }.padding(28).frame(maxWidth: 580).frame(maxWidth: .infinity) }.background(CivicTheme.paper)
    }
}
