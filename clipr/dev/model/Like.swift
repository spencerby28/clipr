//
//  Like.swift
//  ReelsLayout
//
//  Created by Balaji Venkatesh on 13/11/23.
//

import SwiftUI

/// Like Animation Model
struct devLike: Identifiable {
    var id: UUID = .init()
    var tappedRect: CGPoint = .zero
    var isAnimated: Bool = false
}
