import Foundation
#if canImport(Speech)
import Speech
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

protocol SpeechServiceProtocol: AnyObject {
    func authorizationStatus() -> PermissionStatus
    func requestAuthorization() async -> PermissionStatus
    func supports(localeIdentifier: String) -> Bool
    func startTranscription(localeIdentifier: String) async throws
    func finishTranscription() async throws -> String
    func cancelTranscription()
}

enum SpeechServiceError: LocalizedError, Equatable {
    case notAuthorized
    case recognizerUnavailable
    case microphoneUnavailable
    case noTranscript

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Speech recognition is not authorized."
        case .recognizerUnavailable: return "Speech recognition is unavailable for this language."
        case .microphoneUnavailable: return "The microphone is unavailable."
        case .noTranscript: return "No speech was transcribed."
        }
    }
}

#if canImport(Speech) && canImport(AVFoundation)
final class SystemSpeechService: NSObject, SpeechServiceProtocol {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""

    func authorizationStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .allowed
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unknown
        }
    }

    func requestAuthorization() async -> PermissionStatus {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        switch status {
        case .authorized: return .allowed
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unknown
        }
    }

    func supports(localeIdentifier: String) -> Bool {
        SFSpeechRecognizer.supportedLocales().contains(Locale(identifier: localeIdentifier))
    }

    func startTranscription(localeIdentifier: String) async throws {
        cancelTranscription()
        guard authorizationStatus() == .allowed else { throw SpeechServiceError.notAuthorized }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)), recognizer.isAvailable else {
            throw SpeechServiceError.recognizerUnavailable
        }

        latestTranscript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw SpeechServiceError.microphoneUnavailable
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result { self?.latestTranscript = result.bestTranscription.formattedString }
            if error != nil || result?.isFinal == true { self?.stopAudioCapture() }
        }
    }

    func finishTranscription() async throws -> String {
        stopAudioCapture()
        recognitionRequest?.endAudio()
        try? await Task.sleep(nanoseconds: 500_000_000)
        let transcript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        guard !transcript.isEmpty else { throw SpeechServiceError.noTranscript }
        return transcript
    }

    func cancelTranscription() {
        stopAudioCapture()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func stopAudioCapture() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}
#else
final class SystemSpeechService: SpeechServiceProtocol {
    func authorizationStatus() -> PermissionStatus { .unavailable }
    func requestAuthorization() async -> PermissionStatus { .unavailable }
    func supports(localeIdentifier: String) -> Bool { false }
    func startTranscription(localeIdentifier: String) async throws { throw SpeechServiceError.recognizerUnavailable }
    func finishTranscription() async throws -> String { throw SpeechServiceError.noTranscript }
    func cancelTranscription() {}
}
#endif

final class MockSpeechService: SpeechServiceProtocol {
    var transcript: String
    var authorization: PermissionStatus
    var startError: Error?
    var finishError: Error?
    var authorizationDelayNanoseconds: UInt64
    var startDelayNanoseconds: UInt64
    var finishDelayNanoseconds: UInt64
    var ignoresFinishCancellation: Bool
    private(set) var requestAuthorizationCount = 0
    private(set) var startTranscriptionCount = 0
    private(set) var finishTranscriptionCount = 0
    private(set) var cancelTranscriptionCount = 0

    init(
        transcript: String = "Meeting with Alex tomorrow at 3 PM",
        authorization: PermissionStatus = .allowed,
        startError: Error? = nil,
        finishError: Error? = nil,
        authorizationDelayNanoseconds: UInt64 = 0,
        startDelayNanoseconds: UInt64 = 0,
        finishDelayNanoseconds: UInt64 = 0,
        ignoresFinishCancellation: Bool = false
    ) {
        self.transcript = transcript
        self.authorization = authorization
        self.startError = startError
        self.finishError = finishError
        self.authorizationDelayNanoseconds = authorizationDelayNanoseconds
        self.startDelayNanoseconds = startDelayNanoseconds
        self.finishDelayNanoseconds = finishDelayNanoseconds
        self.ignoresFinishCancellation = ignoresFinishCancellation
    }

    func authorizationStatus() -> PermissionStatus { authorization }
    func requestAuthorization() async -> PermissionStatus {
        requestAuthorizationCount += 1
        if authorizationDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: authorizationDelayNanoseconds)
        }
        return authorization
    }
    func supports(localeIdentifier: String) -> Bool { true }
    func startTranscription(localeIdentifier: String) async throws {
        startTranscriptionCount += 1
        if startDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: startDelayNanoseconds)
        }
        if let startError { throw startError }
    }
    func finishTranscription() async throws -> String {
        finishTranscriptionCount += 1
        if finishDelayNanoseconds > 0 {
            if ignoresFinishCancellation {
                try? await Task.sleep(nanoseconds: finishDelayNanoseconds)
            } else {
                try await Task.sleep(nanoseconds: finishDelayNanoseconds)
            }
        }
        if let finishError { throw finishError }
        return transcript
    }
    func cancelTranscription() { cancelTranscriptionCount += 1 }
}
