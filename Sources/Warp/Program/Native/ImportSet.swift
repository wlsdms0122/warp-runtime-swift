//
//  ImportSet.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// The procedures one native procedure sends: every selector it names, where each
// stands among them, and how many arguments it hands over at each.
//
// A procedure sends by naming a case, so a procedure it never declared is a procedure that
// does not compile. The place is the case's raw value, and the link fills a
// row per place, so the run reads a row where the procedure wrote a spelling.
//
// How many it hands is said here for the same reason the selector is. A body
// writes its arguments where the link can count them; a Swift body is not text,
// so the procedure says how many and the build holds that against the
// callee's parameters. What a run then hands over is a list standing at the
// callee's positions, the way every call's arguments stand.
//
// This is what a document's `imports` is for a body.
public protocol ImportSet: CaseIterable, Hashable, Sendable {
    // The declared spelling this reaches, as a link resolves it.
    var selector: Name { get }

    // Where it stands among the procedure's imports.
    var position: Int { get }

    // How many arguments this send hands over.
    var handing: Int { get }
}

public extension ImportSet {
    // A send that says nothing about what it hands over hands nothing.
    var handing: Int { 0 }
}

public extension ImportSet where Self: RawRepresentable, RawValue == Int {
    var position: Int { rawValue }
}
