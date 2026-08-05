//
//  ChatMessagesViewModel.swift
//  erassvet
//

import Foundation
import FirebaseFirestore
import Combine

/// Live message stream for a single chat thread.
@MainActor
final class ChatMessagesViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    func startListening(chatId: String) {
        listener?.remove()
        isLoading = true
        listener = Firestore.firestore()
            .collection("chats")
            .document(chatId)
            .collection("messages")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                self.messages = snapshot?.documents.compactMap { ChatMessage(id: $0.documentID, data: $0.data()) } ?? []
                self.errorMessage = nil
                self.isLoading = false
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        messages = []
        isLoading = true
    }
}
