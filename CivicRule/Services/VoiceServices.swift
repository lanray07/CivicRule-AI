import Foundation
import Observation
import AVFoundation
import Speech

@MainActor @Observable final class SpeechTranscriptionService {
    var transcript = ""
    var isRecording = false
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasTap = false
    private var generation = 0

    func startVoiceQuestion() async throws {
        stopVoiceSession()
        let currentGeneration = generation
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { throw CivicError.message("Speech access is off. You can type your question or enable access in Settings.") }
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard generation == currentGeneration, !Task.isCancelled else { return }
        guard microphone else { throw CivicError.message("Microphone access is off. Enable it in Settings or type instead.") }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw CivicError.message("On-device speech is unavailable for your current language. Please type your question.")
        }
        transcript = ""
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true)
        let recognition = SFSpeechAudioBufferRecognitionRequest()
        recognition.requiresOnDeviceRecognition = true
        recognition.shouldReportPartialResults = true
        request = recognition
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw CivicError.message("No microphone input is available.") }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in recognition.append(buffer) }
        hasTap = true
        task = recognizer.recognitionTask(with: recognition) { [weak self] result, error in
            Task { @MainActor in
                guard self?.generation == currentGeneration else { return }
                if let result { self?.transcript = result.bestTranscription.formattedString }
                if result?.isFinal == true || error != nil { self?.stopVoiceSession() }
            }
        }
        engine.prepare()
        do { try engine.start(); isRecording = true }
        catch { stopVoiceSession(); throw error }
    }
    func stopVoiceSession() {
        generation += 1
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio(); task?.cancel(); request = nil; task = nil; isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

@MainActor @Observable final class SpokenAnswerService {
    private let synthesizer = AVSpeechSynthesizer()
    func readAnswer(_ text: String, rate: Float = 0.48) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = min(0.6, max(0.3, rate)); synthesizer.speak(utterance)
    }
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

enum VoiceIntent: Equatable { case question, permits, checklist, changes, original, reminder }
struct VoiceIntentRouter {
    func resolveIntent(_ text: String) -> VoiceIntent {
        let value = text.lowercased()
        if value.contains("original wording") { return .original }
        if value.contains("add") && (value.contains("deadline") || value.contains("reminder")) { return .reminder }
        if value.contains("expiring") { return .permits }
        if value.contains("still need to do") { return .checklist }
        if value.contains("rules changed") { return .changes }
        return .question
    }
}
