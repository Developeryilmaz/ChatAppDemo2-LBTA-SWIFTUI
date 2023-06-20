//
//  ContentView.swift
//  LBTASwiftUIFirebaseChat
//
//  Created by YILMAZ ER on 18.06.2023.
//

import SwiftUI
import Firebase
import FirebaseStorage


struct LoginView: View {
    
    let didCompleteLoginProgress: () -> ()
    
    @State private var isLoginMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var loginStatusMessage = ""
    @State private var shouldShowImagePicker = false
    @State private var image: UIImage?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Picker(selection: $isLoginMode) {
                        Text("Login")
                            .tag(true)
                        Text("Create Account")
                            .tag(false)
                    } label: {
                        Text("Picker here")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if !isLoginMode {
                        Button(action: {
                            shouldShowImagePicker.toggle()
                        }, label: {
                            Group {
                                if let image = self.image {
                                    Image(uiImage: image)
                                        .resizable()
                                } else {
                                    Image("Profile")
                                        .resizable()
                                }
                            }
                            .scaledToFill()
                            .frame(width: 128, height: 128)
                            .cornerRadius(64)
                            .overlay(RoundedRectangle(cornerRadius: 64).stroke(.gray, lineWidth: 2))
                            .padding()
                            
                        })
                    }
                    
                    Group {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        SecureField("Password", text: $password)
                    }
                    .padding(12)
                    .background(.white)
                    .cornerRadius(5)
                    
                    
                    Button(action: handleAction, label: {
                        HStack {
                            Spacer()
                            Text(isLoginMode ? "Log In" : "Create Account")
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        .background(Color.blue)
                        .cornerRadius(5)
                    })
                    
                    Text(loginStatusMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .fontWeight(.light)
                }
                .padding()
            }
            .navigationTitle(isLoginMode ? "Log In" : "Create Account")
            .background(Color(.init(white: 0, alpha: 0.05))
                .ignoresSafeArea())
            
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil, content: {
            ImagePicker(image: $image)
        })
    }
   
    private func handleAction() {
        //MARK: Should log into Firebase with existing creatials
        if isLoginMode {
            loginUser()
        }
        //MARK: Register a new account inside of Firebase Auth and then image in Storage somehow...
        else {
            createNewAccount()
        }
    }
    
    private func loginUser() {
        FirebaseManager.shared.auth.signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.loginStatusMessage = error.localizedDescription
                print("Failed to login user: \(error)")
                return
            }
            print("✅ Successfully log in user: \(result?.user.uid ?? "")")
            self.didCompleteLoginProgress()
        }
    }

    private func createNewAccount() {
        if self.image == nil {
            self.loginStatusMessage = "You must select an avatar image"
            return
        }
        FirebaseManager.shared.auth.createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.loginStatusMessage = error.localizedDescription
                print("Failed to create user", error.localizedDescription)
                return
            }
            print("✅ Successfully created user: \(result?.user.uid ?? "")")
            self.persistImageToStorage()
        }
    }
    
    private func persistImageToStorage() {
//        let filenanme = UUID().uuidString
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let imageData = image?.jpegData(compressionQuality: 0.5) else { return }
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        ref.putData(imageData) { metadata, error in
            if let error = error {
                self.loginStatusMessage = "Failed to push image to Storage: \(error.localizedDescription)"
                return
            }
            ref.downloadURL { url, error in
                if let error = error {
                    self.loginStatusMessage = "Failed to retrieve downloadURL: \(error.localizedDescription)"
                    return
                }
                print(url?.absoluteString ?? "image url nil")
                guard let url = url else { return }
                self.storeUserInformation(imageProfileURL: url)
            }
        }
    }
    
    private func storeUserInformation(imageProfileURL: URL) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let userData = ["email": self.email, "uid": uid, "profileImageURL": imageProfileURL.absoluteString]
        FirebaseManager.shared.firestore.collection("users").document(uid).setData(userData) { error in
            if let error = error {
                self.loginStatusMessage = error.localizedDescription
                return
            }
            print("✅ Success")
            self.didCompleteLoginProgress()
        }
    }

}

#Preview {
    LoginView(didCompleteLoginProgress: {})
}
