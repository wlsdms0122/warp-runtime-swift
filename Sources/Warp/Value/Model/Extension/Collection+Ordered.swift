//
//  Collection+Ordered.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

extension Collection where Element: Comparable {
    // Whether these stand in order, none of them twice. The two are one
    // question: a list that never goes back is a list that never repeats.
    var ordered: Bool {
        zip(self, dropFirst()).allSatisfy { one, other in one < other }
    }
}
