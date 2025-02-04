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
            if navigationState.isCheckingAuth {
                ProgressView("Checking authentication...")
                    .progressViewStyle(.circular)
            } else if navigationState.isLoggedIn {
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
        ZStack {
            // Background gradient for a modern look.
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // App title
                Text("Clipr")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
                
                // Email input
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .foregroundColor(.black)
                
                // Password input
                SecureField("Password", text: $viewModel.password)
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .foregroundColor(.black)
                
                // Register button
                Button(action: {
                    Task {
                        do {
                            try await appwrite.onRegister(viewModel.email, viewModel.password)
                            await navigationState.checkAuthStatus()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    Text("Register")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                }
                
                // Login button
                Button(action: {
                    Task {
                        do {
                            try await appwrite.onLogin(viewModel.email, viewModel.password)
                            await navigationState.checkAuthStatus()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .padding(.top, 80)
        }
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
