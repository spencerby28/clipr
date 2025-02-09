//
//  FeedSelectorBadge.swift
//  clipr
//
//  Created by Spencer Byrne on 2/6/25.
//

import SwiftUI

enum FeedType: String, CaseIterable {
    case friends = "Friends"
    case world = "World"
    case gauntlet = "Gauntlet"
}

struct FeedOptionView: View {
    let feedType: FeedType
    let isSelected: Bool
    let isExpanded: Bool
    
    var body: some View {
        Text(feedType.rawValue)
            .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundColor(.white)
            .background(
                Group {
                    if isSelected && !isExpanded {
                        Color.white.opacity(0)
                    } else {
                        Capsule()
                        .fill(.thinMaterial)
                        .preferredColorScheme(.dark)
                        
                            .opacity(isSelected ? 1.0 : 0.3)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

struct FeedSelectorBadge: View {
    @Binding var selectedFeed: FeedType
    @Binding var isExpanded: Bool
    
    private var leftOption: FeedType {
        let currentIndex = FeedType.allCases.firstIndex(of: selectedFeed)!
        let leftIndex = (currentIndex - 1 + FeedType.allCases.count) % FeedType.allCases.count
        return FeedType.allCases[leftIndex]
    }
    
    private var rightOption: FeedType {
        let currentIndex = FeedType.allCases.firstIndex(of: selectedFeed)!
        let rightIndex = (currentIndex + 1) % FeedType.allCases.count
        return FeedType.allCases[rightIndex]
    }
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedFeed = leftOption
                    isExpanded = false
                }
                HapticManager.shared.selectionChanged()
            }) {
                FeedOptionView(feedType: leftOption, isSelected: false, isExpanded: isExpanded)
                    .frame(width: 100)
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isExpanded ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
            .allowsHitTesting(isExpanded)
            
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                HapticManager.shared.lightImpact()
            }) {
                FeedOptionView(feedType: selectedFeed, isSelected: true, isExpanded: isExpanded)
                    .frame(width: 100)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedFeed = rightOption
                    isExpanded = false
                }
                HapticManager.shared.selectionChanged()
            }) {
                FeedOptionView(feedType: rightOption, isSelected: false, isExpanded: isExpanded)
                    .frame(width: 100)
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isExpanded ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
            .allowsHitTesting(isExpanded)
        }
    }
}

#Preview {
    ZStack {
        Color.blue
            .ignoresSafeArea()
        FeedSelectorBadge(selectedFeed: .constant(.friends), isExpanded: .constant(false))
    }
}
