//
//  ParameterSet.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// The parameters one native word declares: every name it takes, what each is
// declared as, and where each stands among them.
//
// A word reads an argument by naming a case, so a name it never declared is
// a name that does not compile. The place is the case's raw value, which is
// what lets the run read a place where it read a name.
//
// The run keeps parameters in name order, so the cases stand in that order
// too. `Signature.init(of:receiver:returns:)` is the door that says so.
public protocol ParameterSet: CaseIterable, Hashable, Sendable {
    // What a document writes to fill this.
    var name: Name { get }

    // What it takes, defaulted, and the members it must be one of.
    var declared: Parameter { get }

    // Where it stands among the word's parameters.
    var position: Int { get }
}

public extension ParameterSet where Self: RawRepresentable, RawValue == Int {
    var position: Int { rawValue }
}

// A word that declares nothing. Its one case is never reached, which is what
// having no parameters means.
public enum NoParameters: Int, ParameterSet {
    case none

    public static var allCases: [NoParameters] { [] }

    public var name: Name { "" }

    public var declared: Parameter { Parameter() }
}
