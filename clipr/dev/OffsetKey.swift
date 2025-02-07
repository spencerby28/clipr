//
//  OffsetKey.swift
//  ReelsLayout
//
//  Created by Balaji Venkatesh on 14/11/23.
//

import SwiftUI

struct OffsetKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
