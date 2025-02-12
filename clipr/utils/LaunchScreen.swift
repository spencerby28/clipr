//
//  LaunchScreen.swift
//  clipr
//
//  Created by Spencer Byrne on 2/10/25.
//

import SwiftUI

struct LaunchScreen: View {
    @State private var isOpening = false
    @Binding var isFinished: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ApertureView(isOpening: $isOpening) {
                withAnimation {
                    isFinished = true
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isOpening = true
            }
        }
    }
}

