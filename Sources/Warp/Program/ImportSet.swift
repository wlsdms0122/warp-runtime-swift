//
//  ImportSet.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// The procedures one native procedure sends: every selector it names, where each
// stands among them, and the names it hands over at each.
//
// A procedure sends by naming a case, so a procedure it never declared is a procedure that
// does not compile. The place is the case's raw value, and the link fills a
// row per place, so the run reads a row where the procedure wrote a spelling.
//
// The names it hands are said here for the same reason the selector is. A body
// writes its arguments under names the link can read; a Swift body is not text,
// so the procedure says them and the build works out where each one stands
// among the callee's parameters. What a run then hands over is a list standing
// in this order.
//
// This is what a document's `imports` is for a body.
public protocol ImportSet: CaseIterable, Hashable, Sendable {
    // The declared spelling this reaches, as a link resolves it.
    var selector: Name { get }

    // Where it stands among the procedure's imports.
    var position: Int { get }

    // The arguments handed over at this send, in the order the procedure hands
    // them.
    var offers: [Name] { get }
}

public extension ImportSet {
    // A send that says nothing about what it hands over hands nothing, which is
    // what most of them do.
    var offers: [Name] { [] }
}

public extension ImportSet where Self: RawRepresentable, RawValue == Int {
    var position: Int { rawValue }
}

// A procedure that sends nothing. Its one case is never reached, which is what
// sending nothing means.
public enum NoImports: Int, ImportSet {
    case none

    public static var allCases: [NoImports] { [] }

    public var selector: Name { "" }
}
