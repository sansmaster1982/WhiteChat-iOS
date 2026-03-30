import SwiftUI

/// Chat list — shows conversations sorted by last message time
/// Matches Android ChatsScreen
struct ChatsListView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @StateObject private var contactRepo = ContactRepository.shared
    @State private var lastMessages: [String: Message] = [:]
    @State private var showNewChat = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedContacts) { contact in
                    NavigationLink {
                        ChatView(contact: contact)
                    } label: {
                        ChatRow(contact: contact, lastMessage: lastMessages[contact.email])
                    }
                }
                .onDelete(perform: deleteChats)
            }
            .listStyle(.plain)
            .navigationTitle(L("chats_title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView()
            }
            .onAppear { refreshLastMessages() }
        }
    }

    private var sortedContacts: [Contact] {
        contactRepo.contacts.sorted { a, b in
            let dateA = lastMessages[a.email]?.timestamp ?? a.addedAt
            let dateB = lastMessages[b.email]?.timestamp ?? b.addedAt
            return dateA > dateB
        }
    }

    private func refreshLastMessages() {
        lastMessages = MessageRepository.shared.lastMessages()
    }

    private func deleteChats(offsets: IndexSet) {
        for index in offsets {
            let contact = sortedContacts[index]
            try? MessageRepository.shared.deleteMessages(for: contact.email)
        }
        refreshLastMessages()
    }
}

// MARK: - Chat Row

struct ChatRow: View {
    let contact: Contact
    let lastMessage: Message?

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: contact.displayName, hue: contact.avatarColor)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if let msg = lastMessage {
                        Text(msg.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let msg = lastMessage {
                    HStack(spacing: 4) {
                        if msg.isOutgoing {
                            Image(systemName: statusIcon(msg.status))
                                .font(.caption2)
                                .foregroundColor(statusColor(msg.status))
                        }
                        Text(messagePreview(msg))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(L("chats_no_messages"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func messagePreview(_ msg: Message) -> String {
        if msg.attachmentType != nil {
            switch msg.attachmentType {
            case .image: return "📷 " + L("attachment_photo")
            case .voice: return "🎤 " + L("attachment_voice")
            case .document: return "📎 " + L("attachment_document")
            case .video: return "🎬 " + L("attachment_video")
            case .none: return msg.body
            }
        }
        return msg.body
    }

    private func statusIcon(_ status: MessageStatus) -> String {
        switch status {
        case .sending: return "arrow.up.circle"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        case .received: return "arrow.down.circle"
        }
    }

    private func statusColor(_ status: MessageStatus) -> Color {
        switch status {
        case .failed: return AppTheme.red
        case .delivered: return AppTheme.green
        default: return .secondary
        }
    }
}
