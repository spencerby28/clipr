//
//  Home.swift
//  ReelsLayout
//
//  Created by Balaji Venkatesh on 13/11/23.
//

import SwiftUI

struct Home: View {
    var size: CGSize
    var safeArea: EdgeInsets
    /// View Properties
    @StateObject private var reelLoader = ReelLoader()
    @State private var likedCounter: [devLike] = []
    
    var body: some View {
        ZStack {
            switch reelLoader.loadingState {
            case .idle, .loading where reelLoader.reels.isEmpty:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
            
            case .error(let message):
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                    Text(message)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await reelLoader.loadReels(refresh: true)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                
            case .loading, .loaded:
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(reelLoader.reels.indices, id: \.self) { index in
                            ReelView(
                                reel: $reelLoader.reels[index],
                                likedCounter: $likedCounter,
                                size: size,
                                safeArea: safeArea,
                                currentIndex: index,
                                allReels: $reelLoader.reels
                            )
                            .frame(maxWidth: .infinity)
                            .containerRelativeFrame(.vertical)
                            .onAppear {
                                if index == reelLoader.reels.count - 2 {
                                    Task {
                                        await reelLoader.loadReels()
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .background(.black)
                /// Like Animation View
                .overlay(alignment: .topLeading, content: {
                    ZStack {
                        ForEach(likedCounter) { like in
                            Image(systemName: "suit.heart.fill")
                                .font(.system(size: 75))
                                .foregroundStyle(.red.gradient)
                                .frame(width: 100, height: 100)
                                .animation(.smooth, body: { view in
                                    view
                                        .scaleEffect(like.isAnimated ? 1 : 1.8)
                                        .rotationEffect(.init(degrees: like.isAnimated ? 0 : .random(in: -30...30)))
                                })
                                .offset(x: like.tappedRect.x - 50, y: like.tappedRect.y - 50)
                                .offset(y: like.isAnimated ? -(like.tappedRect.y + safeArea.top) : 0)
                        }
                    }
                })
            }
        }
        .overlay(alignment: .top, content: {
            Text("Reels")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    Button("", systemImage: "camera") {
                        
                    }
                    .font(.title2)
                }
                .foregroundStyle(.white)
                .padding(.top, safeArea.top + 15)
                .padding(.horizontal, 15)
        })
        .environment(\.colorScheme, .dark)
        .task {
            await reelLoader.loadReels()
        }
    }
}

#Preview {
    ContentView()
}
