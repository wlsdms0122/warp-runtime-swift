//
//  Ordered.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

extension Collection where Element: Comparable {
    // Whether these stand in order, none of them twice. The two are one
    // question: a list that never goes back is a list that never repeats.
    //
    // Every place that reads a written list of keys asks this, and every place
    // that judges a layout or a numbering asks it too, so it is one sentence
    // rather than one for each kind of key.
    var ordered: Bool {
        zip(self, dropFirst()).allSatisfy { one, other in one < other }
    }
}
