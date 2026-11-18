//
//  ProcedureConvertible.swift
//  Warp
//

import Foundation

// A procedure a host lends under a name of its own: the name a module
// declares it at and the procedure it is.
public protocol ProcedureConvertible {
    var name: Name { get }

    var procedure: Procedure { get }
}
