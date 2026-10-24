//
//  HitTarget.swift
//  TalkMVP
//

import SwiftUI

extension View {
    /// Grows the area that answers a touch to at least 44 × 44 points around a control drawn
    /// smaller, as the Human Interface Guidelines ask, without changing its size in the layout.
    func minimumHitTarget(visibleSize: CGFloat) -> some View {
        let extra = max(0, (44 - visibleSize) / 2)
        return padding(extra)
            .contentShape(.rect)
            .padding(-extra)
    }
}
