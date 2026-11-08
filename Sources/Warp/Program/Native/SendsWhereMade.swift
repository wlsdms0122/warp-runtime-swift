//
//  SendsWhereMade.swift
//  Warp
//
//  Created by JSilver on 11/8/26.
//

import Foundation

// A native procedure whose sends are said where it is made rather than by its
// `Imports`: a conformance case declares a native's sends as data. It declares
// them and never sends them, so its `Imports` stays empty and `Invocation`
// lets it send nothing.
package protocol SendsWhereMade: NativeProcedure {
    // Each send in the place it stands at: the spelling it reaches and how
    // many arguments it hands there.
    var sends: [(position: Int, selector: Name, handing: Int)] { get }
}
