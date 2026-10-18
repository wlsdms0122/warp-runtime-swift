//
//  NativeProcedure.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// A procedure implemented natively rather than written as a body. What every
// one of them says about itself, whichever protocol it answers through.
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

    // Whether this touches no name another body could touch at the same time.
    // A procedure holding state between calls says false, and the link stops
    // deriving isolation through it and through whatever calls it.
    var isolated: Bool { get }

    // What may come out of this when the work goes wrong, by the types its
    // failures name themselves. One that only ever throws at an author mistake
    // fails nothing, which is the default, so a procedure that can fail says
    // so and one that could fail with anything says `anything`.
    var failing: Failing { get }
}

public extension NativeProcedure {
    var isolated: Bool { true }

    var failing: Failing { .these([]) }
}
