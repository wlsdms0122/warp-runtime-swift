//
//  NativeProcedure.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// A procedure implemented natively rather than written as a body. What every
// one of them says about itself, whichever protocol it answers through.
// What a call may expect of it, its answer, its failures, whether it is
// const or isolated, is its declaration's to say, as for any body.
//
// The parameters and the imports are here because they are the procedure's
// own: the names it declares are the names its body reads, the procedures it
// declares are the ones its body sends, and one type saying both is what keeps
// a procedure from reading a name or sending a procedure it never declared.
public protocol NativeProcedure: Sendable {
    associatedtype Parameters: ParameterSet

    // The procedures this sends. One that sends none says nothing, which is
    // the default, and one that sends some declares them so the link can
    // resolve the rows before anything runs.
    associatedtype Imports: ImportSet = NoImports
}
