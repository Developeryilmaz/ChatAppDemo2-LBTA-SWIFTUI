//
//  MainMessagesView.swift
//  LBTASwiftUIFirebaseChat
//
//  Created by YILMAZ ER on 19.06.2023.
//

import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseFirestoreSwift

struct RecentMessage: Codable, Identifiable {
    @DocumentID var id: String?
    let text, email: String
    let fromId, toId: String
    let profileImageURL: String
    let timestamp: Date
    let status: Bool
}

class MainMessagesViewModel: ObservableObject {
    
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    @Published var isUserCurrentlyLoggedOut = false
    @Published var recentMessages = [RecentMessage]()
    
    init() {
        DispatchQueue.main.async {
            self.isUserCurrentlyLoggedOut = FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurrentUser()
        fetchRecentMessages()
    }
    
    func fetchRecentMessages() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        FirebaseManager.shared.firestore.collection("recent_messages").document(uid).collection("messages").order(by: "timestamp").addSnapshotListener { querySnapshot, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                print("Failed to listen for recent messages \(error.localizedDescription)")
                return
            }
            querySnapshot?.documentChanges.forEach({ change in
                let documentId = change.document.documentID
                if let index = self.recentMessages.firstIndex(where: { $0.id == documentId }) {
                    self.recentMessages.remove(at: index)
                }
                if let rm = try? change.document.data(as: RecentMessage.self) {
                    self.recentMessages.insert(rm, at: 0)
                }
            })
        }
    }
    
    func fetchCurrentUser() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("🚨 Failed to fetch current user: \(error.localizedDescription)")
                self.errorMessage = "🚨 Failed to fetch current user: \(error.localizedDescription)."
                return
            }
            guard let data = snapshot?.data() else {
                self.errorMessage = "No data found."
                return
            }
            self.chatUser = .init(data: data)
        }
    }
    
    func handleSignOut() {
        isUserCurrentlyLoggedOut.toggle()
        try? FirebaseManager.shared.auth.signOut()
    }
}

struct MainMessagesView: View {
    
    @ObservedObject private var vm = MainMessagesViewModel()
    @State var shouldShowLogOutOptions = false
    @State var shouldShownNewMessageScreen = false
    @State var chatUser: ChatUser?
    @State var shouldNavigationToChatLogView = false
    
    
    var body: some View {
        NavigationView {
            VStack {
                customNavBar
                Divider()
                messagesView
                NavigationLink("", isActive: $shouldNavigationToChatLogView) {
                    ChatLogView(chatUser: self.chatUser)
                }
            }
            .overlay(
                newMessageButton, alignment: .bottom)
            .navigationBarHidden(true)
        }
    }
    
    private var customNavBar: some View {
        HStack(spacing: 16) {
            WebImage(url: URL(string: vm.chatUser?.profileImageURL ?? ""))
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .cornerRadius(25)
                .padding(2)
                .overlay(RoundedRectangle(cornerRadius: 44)
                    .stroke(Color(.gray), lineWidth: 1)
                )
                .shadow(radius: 5)
            
            VStack(alignment: .leading, spacing: 4) {
                let email = vm.chatUser?.email.replacingOccurrences(of: "@gmail.com", with: "") ?? ""
                Text(email)
                    .font(.system(size: 24, weight: .bold))
                
                HStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: 14, height: 14)
                    Text("online")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.lightGray))
                }
                
            }
            
            Spacer()
            Button {
                shouldShowLogOutOptions.toggle()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(.label))
            }
        }
        .padding()
        .actionSheet(isPresented: $shouldShowLogOutOptions) {
            .init(title: Text("Settings"), message: Text("What do you want to do?"), buttons: [
                .destructive(Text("Sign Out"), action: {
                    print("handle sign out")
                    vm.handleSignOut()
                }),
                .cancel()
            ])
        }
        .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut) {
            LoginView(didCompleteLoginProgress: {
                self.vm.isUserCurrentlyLoggedOut = false
                self.vm.fetchCurrentUser()
            })
        }
    }
    
    private var messagesView: some View {
        ScrollView {
            ForEach(vm.recentMessages) { recentMessage in
                VStack {
                    HStack(spacing: 16) {
                        WebImage(url: URL(string: recentMessage.profileImageURL))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .cornerRadius(25)
                            .padding(2)
                            .overlay(RoundedRectangle(cornerRadius: 44)
                                .stroke(Color(.gray), lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recentMessage.email)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(UIColor.label))
                                .multilineTextAlignment(.leading)
                            Text(recentMessage.text)
                                .font(.system(size: 14))
                                .foregroundColor(Color(.lightGray))
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        
                        Text(recentMessage.timestamp.description)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Divider()
                        .padding(.vertical, 8)
                }.padding(.horizontal)
                    .containerShape(Rectangle())
                
                
            }.padding(.bottom, 50)
        }
    }
    
    private var newMessageButton: some View {
        Button {
            shouldShownNewMessageScreen.toggle()
        } label: {
            HStack {
                Spacer()
                Text("+ New Message")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical)
            .background(Color.blue)
            .cornerRadius(32)
            .padding(.horizontal)
            .shadow(radius: 15)
        }
        .fullScreenCover(isPresented: $shouldShownNewMessageScreen) {
            CreateNewMessageView { user in
                print(user.email)
                self.shouldNavigationToChatLogView.toggle()
                self.chatUser = user
            }
        }
    }
}

#Preview {
    MainMessagesView()
}
