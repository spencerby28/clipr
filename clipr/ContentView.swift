//
//  ContentView.swift
//  clipr
//
//  Created by Spencer Byrne on 2/3/25.
//

import SwiftUI

class ViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
}

struct ContentView: View {
    @StateObject private var navigationState = NavigationState()
    
    var body: some View {
        Group {
            if navigationState.isLoggedIn {
                MainTabView()
                    .environmentObject(navigationState)
            } else {
                AuthView()
                    .environmentObject(navigationState)
            }
        }
    }
}

struct AuthView: View {
    @ObservedObject var viewModel = ViewModel()
    @EnvironmentObject var navigationState: NavigationState
    @State private var showError = false
    @State private var errorMessage = ""
    let appwrite = Appwrite()

    var body: some View {
        VStack {
            TextField(
                "Email",
                text: $viewModel.email
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.none)
            
            SecureField(
                "Password",
                text: $viewModel.password
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button(
                action: {
                    Task {
                        do {
                            try await appwrite.onRegister(
                                viewModel.email,
                                viewModel.password
                            )
                            await MainActor.run {
                                navigationState.isLoggedIn = true
                            }
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                },
                label: {
                    Text("Register")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            )
            
            Button(
                action: {
                    Task {
                        do {
                            try await appwrite.onLogin(
                                viewModel.email,
                                viewModel.password
                            )
                            await MainActor.run {
                                navigationState.isLoggedIn = true
                            }
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                },
                label: {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            )
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

#Preview {
    ContentView()
}
