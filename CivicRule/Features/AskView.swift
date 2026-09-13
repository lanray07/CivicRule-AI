import SwiftUI
import SwiftData

struct AskView: View {
    let business: Business?
    var startWithVoice = false
    @Environment(\.modelContext) private var context
    @State private var question = ""
    @State private var answer: RegulatoryAnswer?
    @State private var busy = false
    @State private var error = ""
    @State private var saved = false
    @State private var checklistCreated = false
    @State private var voice = SpeechTranscriptionService()
    @State private var speaker = SpokenAnswerService()
    @AppStorage("cloudConsent") private var cloudConsent = false
    @AppStorage("speechRate") private var speechRate = 0.48
    @AppStorage("readSources") private var readSources = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("A real question.\nA clearer next step.").font(.system(.largeTitle, design: .serif))
                Label(business.map { "\($0.name) · \($0.authority)" } ?? "Add a business before asking", systemImage: "mappin.circle").font(.subheadline).foregroundStyle(.secondary)
                if startWithVoice {
                    Button {
                        Task {
                            if voice.isRecording { voice.stopVoiceSession() }
                            else { do { try await voice.startVoiceQuestion() } catch { self.error = error.localizedDescription } }
                        }
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: voice.isRecording ? "stop.fill" : "mic.fill").font(.system(size: 38)).foregroundStyle(CivicTheme.lime).frame(width: 100, height: 100).background(CivicTheme.forest, in: Circle())
                            Text(voice.isRecording ? "Tap to finish" : "Tap to speak").font(.headline)
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                    }.buttonStyle(.plain).accessibilityLabel(voice.isRecording ? "Stop recording" : "Start on-device voice question")
                }
                CivicCard {
                    TextField("What would you like to check?", text: $question, axis: .vertical).lineLimit(4...8).font(.title3).accessibilityLabel("Your regulatory question")
                    HStack {
                        Button {
                            Task {
                                if voice.isRecording { voice.stopVoiceSession(); question = voice.transcript }
                                else { do { try await voice.startVoiceQuestion() } catch { self.error = error.localizedDescription } }
                            }
                        } label: {
                            Label(voice.isRecording ? "Stop recording" : "Ask by voice", systemImage: voice.isRecording ? "stop.circle.fill" : "mic.circle.fill").font(.headline).padding(.vertical, 8)
                        }
                        Spacer()
                    }
                    if voice.isRecording { Text(voice.transcript.isEmpty ? "Listening…" : voice.transcript).foregroundStyle(.secondary).accessibilityAddTraits(.updatesFrequently) }
                }
                Text("Audio stays on your device. Review your transcript before sending.").font(.caption).foregroundStyle(.secondary)
                if answer == nil {
                    ForEach(["Can my café put tables outside?", "What should I check before opening?", "Do I need permission for a sign?"], id: \.self) { text in
                        Button { question = text } label: { HStack { Text(text); Spacer(); Image(systemName: "arrow.up.left") }.font(.subheadline).padding(14).background(.background, in: RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain)
                    }
                }
                Toggle("Allow this question and business context to be sent to the configured source service", isOn: $cloudConsent).font(.caption)
                Button { Task { await ask() } } label: {
                    HStack { if busy { ProgressView().tint(.white) }; Text(busy ? "Checking official evidence…" : "Find the rule behind it"); Image(systemName: "arrow.right") }
                }.buttonStyle(CivicButton()).disabled(busy || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || business == nil || !cloudConsent || voice.isRecording)
                if !error.isEmpty { Label(error, systemImage: "info.circle").font(.subheadline).foregroundStyle(CivicTheme.amber) }
                if let answer {
                    AnswerContent(answer: answer)
                    HStack {
                        Button("Read aloud", systemImage: "speaker.wave.2") { speaker.readAnswer(answer.shortAnswer + (readSources ? " Sources: " + answer.sources.map(\.title).joined(separator: ". ") : ""), rate: Float(speechRate)) }
                        Spacer(); Button("Stop") { speaker.stop() }
                    }.font(.subheadline)
                    if !answer.sources.isEmpty {
                        Button(saved ? "Answer saved" : "Save answer") {
                            guard let business else { return }
                            do { context.insert(try SavedAnswer(businessID: business.id, answer: answer)); try context.save(); saved = true }
                            catch { self.error = error.localizedDescription }
                        }.buttonStyle(CivicButton()).disabled(saved)
                        Button(checklistCreated ? "Added to checklist" : "Create checklist") {
                            guard let business else { return }
                            for check in answer.checks { context.insert(ChecklistItem(businessID: business.id, title: check, category: "From saved answer", sourceURL: answer.sources.first?.url ?? "")) }
                            do { try context.save(); checklistCreated = true } catch { self.error = error.localizedDescription }
                        }.disabled(checklistCreated)
                    }
                    ShareLink(item: authorityDraft(answer)) { Label("Draft my question to the authority", systemImage: "square.and.pencil") }.font(.subheadline)
                }
            }.padding(20).frame(maxWidth: 760)
        }.background(CivicTheme.paper).navigationTitle(startWithVoice ? "Ask by voice" : "Ask CivicRule").navigationBarTitleDisplayMode(.inline)
            .onChange(of: voice.isRecording) { _, recording in if !recording && !voice.transcript.isEmpty { question = voice.transcript } }
            .onDisappear { voice.stopVoiceSession(); speaker.stop() }
    }
    private func ask() async {
        guard let business else { return }
        busy = true; error = ""; answer = nil; saved = false; checklistCreated = false
        defer { busy = false }
        do { answer = try await RegulatoryAnswerService().askRegulationQuestion(QuestionRequest(question: question, nation: business.nation, authority: business.authority, businessType: business.kind, activities: business.activities)) }
        catch { self.error = error.localizedDescription }
    }
    private func authorityDraft(_ answer: RegulatoryAnswer) -> String {
        "Subject: Clarification for \(business?.name ?? "my business")\n\nHello,\nI am preparing to operate a \(business?.kind ?? "business") at \(business?.address ?? "[address]"). Could you please clarify the following?\n\n\(answer.question)\n\n\(answer.checks.map { "• \($0)" }.joined(separator: "\n"))\n\nPlease let me know which permissions and property-specific conditions I should verify. Thank you.\n\nDraft only — review before sending."
    }
}

struct AnswerContent: View {
    let answer: RegulatoryAnswer
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CivicCard {
                Eyebrow(text: "Your question"); Text(answer.question).padding(.bottom, 12)
                Eyebrow(text: "Short answer"); Text(answer.shortAnswer).font(.title3).padding(.top, 6)
                Divider().padding(.vertical, 12)
                Label("\(answer.confidence) confidence", systemImage: "info.circle").font(.subheadline.bold())
                Text(answer.reason).font(.subheadline).foregroundStyle(.secondary)
            }
            if !answer.checks.isEmpty {
                CivicCard { Eyebrow(text: "What to check"); ForEach(Array(answer.checks.enumerated()), id: \.offset) { index, check in HStack(alignment: .top) { Text(String(format: "%02d", index + 1)).font(.caption.monospaced().bold()).foregroundStyle(.secondary); Text(check).font(.subheadline) }.padding(.top, 12) } }
            }
            ForEach(answer.sources) { SourceCard(source: $0) }
            ForEach(answer.limitations, id: \.self) { Label($0, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary) }
        }
    }
}
