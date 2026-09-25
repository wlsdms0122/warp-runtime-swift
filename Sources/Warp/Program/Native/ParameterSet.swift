//
//  ParameterSet.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// The parameters one native procedure declares: what each is declared as,
// and where each stands among them.
//
// A procedure reads an argument by naming a case, so a name it never declared is
// a name that does not compile. The place is the case's raw value, which is
// what lets the run read a place where it read a name.
//
// The case order is the declaration order, the order the run keeps the
// arguments in, which is a fact of the wire.
// `Signature.init(of:returns:)` is the door that says so.
public protocol ParameterSet: CaseIterable, Hashable, Sendable {
    // What it takes: the name a document writes to fill this, the type, and
    // the members it must be one of.
    var declared: Parameter { get }

    // Where it stands among the procedure's parameters.
    var position: Int { get }
}

public extension ParameterSet {
    // What a document writes to fill this.
    var name: Name { declared.name }
}

public extension ParameterSet where Self: RawRepresentable, RawValue == Int {
    var position: Int { rawValue }
}
