import SwiftUI
import PhotosUI
import AVFoundation

/// Chat conversation view — matches Android ChatScreen
struct ChatView: View {
    let contact: Contact
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var appState: AppState

    @State private var messageText = ""
    @State private var messages: [Message] = []
    @State private var showAttachMenu = false
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false

    // Voice recording
    @State private var isRecording = false
    @State private var isPaused = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var audioRecorder: AVAudioRecorder?

    // Timer
    @State private var recordingTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let lastId = messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Recording bar
            if isRecording {
                recordingBar
            }

            // Input bar
            inputBar
        }
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadMessages() }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { image in
                sendImage(image)
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { urls in
                if let url = urls.first {
                    sendDocument(url)
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Attach button with dropdown
            Menu {
                Button {
                    showCamera = true
                } label: {
                    Label(L("attach_camera"), systemImage: "camera")
                }

                Button {
                    showImagePicker = true
                } label: {
                    Label(L("attach_gallery"), systemImage: "photo")
                }

                Button {
                    showDocumentPicker = true
                } label: {
                    Label(L("attach_document"), systemImage: "doc")
                }
            } label: {
                Image(systemName: "paperclip")
                    .font(.title3)
                    .foregroundColor(AppTheme.primary)
            }

            // Text field
            TextField(L("chat_placeholder"), text: $messageText)
                .textFieldStyle(.roundedBorder)

            // Send or record button
            if messageText.isEmpty {
                Button {
                    toggleRecording()
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.title3)
                        .foregroundColor(isRecording ? AppTheme.red : AppTheme.primary)
                }
            } else {
                Button {
                    sendTextMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Recording Bar

    private var recordingBar: some View {
        HStack {
            Circle()
                .fill(isPaused ? AppTheme.orange : AppTheme.red)
                .frame(width: 10, height: 10)

            Text(formatDuration(recordingDuration))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)

            Spacer()

            // Pause/Resume
            Button {
                togglePause()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .foregroundColor(.primary)
            }

            // Cancel
            Button {
                cancelRecording()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isPaused ? AppTheme.orange.opacity(0.1) : AppTheme.red.opacity(0.1))
    }

    // MARK: - Actions

    private func loadMessages() {
        messages = MessageRepository.shared.messages(for: contact.email)
    }

    private func sendTextMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""

        Task {
            do {
                guard let recipientKey = PgpKeyManager.shared.getContactKey(email: contact.email) else {
                    print("No public key for \(contact.email)")
                    return
                }

                let encrypted = try PgpCryptoEngine.shared.encrypt(
                    message: "From: \(settingsStore.accountEmail)\n\(text)",
                    recipientPublicKeyArmored: recipientKey
                )

                var msg = Message(
                    contactEmail: contact.email,
                    body: text,
                    isOutgoing: true,
                    timestamp: Date(),
                    status: .sending,
                    emailMessageId: UUID().uuidString
                )
                msg = try MessageRepository.shared.insert(msg)
                await MainActor.run { loadMessages() }

                // Send via SMTP
                let smtp = SmtpClient(email: settingsStore.accountEmail, password: settingsStore.accountPassword)
                try await smtp.send(
                    from: settingsStore.accountEmail,
                    to: contact.email,
                    subject: "\(EmailConstants.subjectPrefix)-\(UUID().uuidString.prefix(8))",
                    body: encrypted
                )

                if let id = msg.id {
                    try MessageRepository.shared.updateStatus(id: id, status: .sent)
                }
                await MainActor.run { loadMessages() }
            } catch {
                print("Send failed: \(error)")
            }
        }
    }

    private func sendImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        sendAttachment(data: data, filename: "photo_\(Int(Date().timeIntervalSince1970)).jpg", type: .image)
    }

    private func sendDocument(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        sendAttachment(data: data, filename: url.lastPathComponent, type: .document)
    }

    private func sendAttachment(data: Data, filename: String, type: AttachmentType) {
        Task {
            do {
                guard let recipientKey = PgpKeyManager.shared.getContactKey(email: contact.email) else { return }
                let encryptedData = try PgpCryptoEngine.shared.encryptData(data, recipientPublicKeyArmored: recipientKey)

                let encrypted = try PgpCryptoEngine.shared.encrypt(
                    message: "From: \(settingsStore.accountEmail)\n[attachment: \(filename)]",
                    recipientPublicKeyArmored: recipientKey
                )

                var msg = Message(
                    contactEmail: contact.email,
                    body: "[attachment: \(filename)]",
                    isOutgoing: true,
                    timestamp: Date(),
                    status: .sending,
                    attachmentType: type,
                    emailMessageId: UUID().uuidString
                )
                msg = try MessageRepository.shared.insert(msg)
                await MainActor.run { loadMessages() }

                let smtp = SmtpClient(email: settingsStore.accountEmail, password: settingsStore.accountPassword)
                try await smtp.send(
                    from: settingsStore.accountEmail,
                    to: contact.email,
                    subject: "\(EmailConstants.subjectPrefix)-\(UUID().uuidString.prefix(8))",
                    body: encrypted,
                    attachmentData: encryptedData,
                    attachmentFilename: filename + ".pgp",
                    attachmentMimeType: "application/pgp-encrypted"
                )

                if let id = msg.id {
                    try MessageRepository.shared.updateStatus(id: id, status: .sent)
                }
                await MainActor.run { loadMessages() }
            } catch {
                print("Attachment send failed: \(error)")
            }
        }
    }

    // MARK: - Voice Recording

    private func toggleRecording() {
        if isRecording {
            stopAndSendRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Audio session error: \(error)")
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice_\(Int(Date().timeIntervalSince1970)).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            isPaused = false
            recordingDuration = 0
            startTimer()
        } catch {
            print("Recording error: \(error)")
        }
    }

    private func togglePause() {
        if isPaused {
            audioRecorder?.record()
            isPaused = false
            startTimer()
        } else {
            audioRecorder?.pause()
            isPaused = true
            recordingTimer?.invalidate()
        }
    }

    private func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        audioRecorder = nil
        isRecording = false
        isPaused = false
        recordingTimer?.invalidate()
        recordingDuration = 0
    }

    private func stopAndSendRecording() {
        guard let recorder = audioRecorder else { return }
        let url = recorder.url
        recorder.stop()
        recordingTimer?.invalidate()
        isRecording = false
        isPaused = false

        guard let data = try? Data(contentsOf: url) else { return }
        sendAttachment(data: data, filename: url.lastPathComponent, type: .voice)
        try? FileManager.default.removeItem(at: url)
    }

    private func startTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 60) }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                // Attachment indicator
                if let type = message.attachmentType {
                    HStack(spacing: 4) {
                        Image(systemName: attachmentIcon(type))
                            .font(.caption)
                        Text(attachmentLabel(type))
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.7))
                }

                Text(message.body)
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))

                    if message.isOutgoing {
                        Image(systemName: statusIcon)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(message.isOutgoing ? AppTheme.outgoingBubble :
                            (colorScheme == .dark ? AppTheme.incomingBubbleDark : AppTheme.incomingBubbleLight))
            .cornerRadius(16)

            if !message.isOutgoing { Spacer(minLength: 60) }
        }
    }

    private var statusIcon: String {
        switch message.status {
        case .sending: return "arrow.up"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        case .received: return ""
        }
    }

    private func attachmentIcon(_ type: AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .voice: return "mic"
        case .document: return "doc"
        case .video: return "video"
        }
    }

    private func attachmentLabel(_ type: AttachmentType) -> String {
        switch type {
        case .image: return L("attachment_photo")
        case .voice: return L("attachment_voice")
        case .document: return L("attachment_document")
        case .video: return L("attachment_video")
        }
    }
}
