import Speech
import AVFoundation

@MainActor
@Observable
final class SpeechRecognitionService {
    var transcribedText: String = ""
    var isRecording: Bool = false
    var isAuthorized: Bool = false
    var errorMessage: String?
    var audioLevel: Float = 0.0
    var recordingDuration: TimeInterval = 0

    // Voice note output
    var savedAudioURL: URL?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            errorMessage = "Speech recognition not authorized."
            return false
        }

        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        guard micGranted else {
            errorMessage = "Microphone access not granted."
            return false
        }

        isAuthorized = true
        return true
    }

    func startRecording() throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available."
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Start audio file recording (AVAudioRecorder)
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicenote_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        audioRecorder?.record()
        savedAudioURL = audioURL

        // Start speech recognition
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let request = recognitionRequest

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frames { sum += abs(channelData[i]) }
            let normalized = min(sum / Float(max(frames, 1)) * 10, 1.0)

            Task { @MainActor [weak self] in
                self?.audioLevel = normalized
            }
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.cleanupAudioEngine()
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        transcribedText = ""
        errorMessage = nil
        recordingStartTime = Date()
        recordingDuration = 0

        // Timer for duration display
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    func stopRecording() {
        cleanupAudioEngine()
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        audioLevel = 0
    }

    /// Save voice note as a document file and return the transcription
    func saveVoiceNote() -> (audioURL: URL, transcription: String)? {
        guard let url = savedAudioURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        let text = transcribedText
        savedAudioURL = nil
        return (url, text)
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            Task {
                if !isAuthorized {
                    let authorized = await requestAuthorization()
                    guard authorized else { return }
                }
                do {
                    try startRecording()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func reset() {
        transcribedText = ""
        errorMessage = nil
        audioLevel = 0
        recordingDuration = 0
        savedAudioURL = nil
    }

    private func cleanupAudioEngine() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
