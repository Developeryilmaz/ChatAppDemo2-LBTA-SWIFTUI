//
//  ChatLogView.swift
//  LBTASwiftUIFirebaseChat
//
//  Created by YILMAZ ER on 19.06.2023.
//

import SwiftUI
import Firebase
import SDWebImageSwiftUI

struct FirebaseConstants {
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
    static let timestamp = "timestamp"
    static let profileImageURL = "profileImageURL"
    static let email = "email"
    static let emptyScrollToString = "Empty"
}

struct ChatMessage: Identifiable {
    
    var id: String { documentId }
    let documentId: String
    let fromId, toId, text: String
    
    init(documentId: String, data: [String : Any]) {
        self.documentId = documentId
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
    }
}

class ChatLogViewModel: ObservableObject {
    
    @Published var chatMessage = [ChatMessage]()
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var count = 0
    let chatUser: ChatUser?
    
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        fetchMessages()
    }
    
    private func fetchMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        FirebaseManager.shared.firestore.collection("messages").document(fromId).collection(toId).order(by: "timestamp").addSnapshotListener { querySnapshot, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            
            querySnapshot?.documentChanges.forEach({ change in
                let data = change.document.data()
                self.chatMessage.append(.init(documentId: change.document.documentID, data: data))
            })
            DispatchQueue.main.async {
                self.count += 1
            }
        }

    }
    
    func handleSend() {
        print(self.chatText)
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore.collection("messages").document(fromId).collection(toId).document()
        let messageData = ["fromId": fromId, "toId": toId, "text": self.chatText, "timestamp": Timestamp() ] as [String : Any]
        document.setData(messageData) { error in
            if let error = error {
                self.errorMessage = "Failed to save message into Firestore: \(error.localizedDescription)"
                return
            }
        }
        
        persistRecentMessage()
        
        let recipientMessageDocument = FirebaseManager.shared.firestore.collection("messages").document(toId).collection(fromId).document()
        recipientMessageDocument.setData(messageData) { error in
            if let error = error {
                self.errorMessage = "Failed to save message into Firestore: \(error.localizedDescription)"
                return
            }
        }
        self.chatText = ""
        self.count += 1
    }
    
    private func persistRecentMessage() {
        guard let chatUser = chatUser else { return }
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = self.chatUser?.uid else { return }
        let document = FirebaseManager.shared.firestore.collection("recent_messages").document(uid).collection("messages").document(toId)
        let document2 = FirebaseManager.shared.firestore.collection("recent_messages").document(toId).collection("messages").document(uid)
        
        let data = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageURL: chatUser.profileImageURL,
            FirebaseConstants.email: chatUser.email,
            "status": true
        ] as [String : Any]
        
        document.setData(data) { error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                print("Failed to save recent message \(error.localizedDescription)")
                return
            }
        }
        document2.setData(data) { error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                print("Failed to save recent message \(error.localizedDescription)")
                return
            }
        }

    }
}

struct ChatLogView: View {
    
    @ObservedObject var vm: ChatLogViewModel
    let chatUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        self.vm = .init(chatUser: chatUser)
    }
    
    var body: some View {
        ZStack {
            messageView
        }
        .navigationTitle("\(chatUser?.email ?? "")")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var messageView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack {
                    ForEach(vm.chatMessage) { message in
                        MessageView(message: message, chatUser: chatUser)
                    }
                    HStack { Spacer() }
                        .id(FirebaseConstants.emptyScrollToString)
                }
                .onReceive(vm.$count) { _ in
                    withAnimation {
                        proxy.scrollTo(FirebaseConstants.emptyScrollToString, anchor: .bottom)
                    }
                }
            }
        }.background(Color(UIColor.label).opacity(0.05))
            .safeAreaInset(edge: .bottom) {
                chatBottomBar
                    .background(Color(UIColor.systemBackground).ignoresSafeArea())
            }
    }
    
    private var chatBottomBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .foregroundColor(.gray)
                .font(.system(size: 24))
            
            ZStack {
                TextEditor(text: $vm.chatText)
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .stroke(Color(.gray), lineWidth: 1)
                    )
                    .cornerRadius(3)
            }
            .frame(height: 50)
            
            Button {
                vm.handleSend()
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(.blue)
            .cornerRadius(5.0)
            
        }
        .padding(8)
        
    }
}

#Preview {
    NavigationView(content: {
        ChatLogView(chatUser: .init(data: ["uid":"47Uryy6Q3hfT0w2PK5dKBalo3xr2", "email":"fake@gmail.com"]))
    })
}

struct MessageView: View {
    
    let message: ChatMessage
    let chatUser: ChatUser?
    
    var body: some View {
        VStack {
            if FirebaseManager.shared.auth.currentUser?.uid == message.fromId {
                ChatBubble(direction: .right) {
                    Text(message.text)
                        .font(.caption)
                        .padding(.all, 12)
                        .background(Color.blue.opacity(0.5))
                }
                .padding(-16)
            } else {
                HStack {
                    VStack {
                        Spacer()
                        WebImage(url: URL(string: chatUser?.profileImageURL ?? ""))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 25, height: 25)
                            .cornerRadius(25)
                            .padding(2)
                            .overlay(RoundedRectangle(cornerRadius: 25)
                                .stroke(Color(.gray), lineWidth: 1)
                            )
                            .padding(.leading, 8)
                    }
                    ChatBubble(direction: .left) {
                        Text(message.text)
                            .font(.caption)
                            .padding(.all, 12)
                            .background(Color(UIColor.label).opacity(0.1))
                    }
                    .padding(-16)
                    .padding(.leading, -12)
                }
                
            }
        }
    }
}


struct ChatBubble<Content>: View where Content: View {
    let direction: ChatBubbleShape.Direction
    let content: () -> Content
    init(direction: ChatBubbleShape.Direction, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.direction = direction
    }
    
    var body: some View {
        HStack {
            if direction == .right {
                Spacer()
            }
            content().clipShape(ChatBubbleShape(direction: direction))
            if direction == .left {
                Spacer()
            }
        }.padding([(direction == .left) ? .leading : .trailing, .top, .bottom], 20)
            .padding((direction == .right) ? .leading : .trailing, 50)
    }
}

struct ChatBubbleShape: Shape {
    enum Direction {
        case left
        case right
    }
    
    let direction: Direction
    
    func path(in rect: CGRect) -> Path {
        return (direction == .left) ? getLeftBubblePath(in: rect) : getRightBubblePath(in: rect)
    }
    
    private func getLeftBubblePath(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let path = Path { p in
            p.move(to: CGPoint(x: 25, y: height))
            p.addLine(to: CGPoint(x: width - 20, y: height))
            p.addCurve(to: CGPoint(x: width, y: height - 20),
                       control1: CGPoint(x: width - 8, y: height),
                       control2: CGPoint(x: width, y: height - 8))
            p.addLine(to: CGPoint(x: width, y: 20))
            p.addCurve(to: CGPoint(x: width - 20, y: 0),
                       control1: CGPoint(x: width, y: 8),
                       control2: CGPoint(x: width - 8, y: 0))
            p.addLine(to: CGPoint(x: 21, y: 0))
            p.addCurve(to: CGPoint(x: 4, y: 20),
                       control1: CGPoint(x: 12, y: 0),
                       control2: CGPoint(x: 4, y: 8))
            p.addLine(to: CGPoint(x: 4, y: height - 11))
            p.addCurve(to: CGPoint(x: 0, y: height),
                       control1: CGPoint(x: 4, y: height - 1),
                       control2: CGPoint(x: 0, y: height))
            p.addLine(to: CGPoint(x: -0.05, y: height - 0.01))
            p.addCurve(to: CGPoint(x: 11.0, y: height - 4.0),
                       control1: CGPoint(x: 4.0, y: height + 0.5),
                       control2: CGPoint(x: 8, y: height - 1))
            p.addCurve(to: CGPoint(x: 25, y: height),
                       control1: CGPoint(x: 16, y: height),
                       control2: CGPoint(x: 20, y: height))
            
        }
        return path
    }
    
    private func getRightBubblePath(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let path = Path { p in
            p.move(to: CGPoint(x: 25, y: height))
            p.addLine(to: CGPoint(x:  20, y: height))
            p.addCurve(to: CGPoint(x: 0, y: height - 20),
                       control1: CGPoint(x: 8, y: height),
                       control2: CGPoint(x: 0, y: height - 8))
            p.addLine(to: CGPoint(x: 0, y: 20))
            p.addCurve(to: CGPoint(x: 20, y: 0),
                       control1: CGPoint(x: 0, y: 8),
                       control2: CGPoint(x: 8, y: 0))
            p.addLine(to: CGPoint(x: width - 21, y: 0))
            p.addCurve(to: CGPoint(x: width - 4, y: 20),
                       control1: CGPoint(x: width - 12, y: 0),
                       control2: CGPoint(x: width - 4, y: 8))
            p.addLine(to: CGPoint(x: width - 4, y: height - 11))
            p.addCurve(to: CGPoint(x: width, y: height),
                       control1: CGPoint(x: width - 4, y: height - 1),
                       control2: CGPoint(x: width, y: height))
            p.addLine(to: CGPoint(x: width + 0.05, y: height - 0.01))
            p.addCurve(to: CGPoint(x: width - 11, y: height - 4),
                       control1: CGPoint(x: width - 4, y: height + 0.5),
                       control2: CGPoint(x: width - 8, y: height - 1))
            p.addCurve(to: CGPoint(x: width - 25, y: height),
                       control1: CGPoint(x: width - 16, y: height),
                       control2: CGPoint(x: width - 20, y: height))
            
        }
        return path
    }
}
