//
//  Query.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A procedure implemented natively that answers without running anything.
// `count`, `contains`, whatever a module ships. Const, which is what lets it
// be asked inside a condition and while a constant settles.
//
// It carries no name and no signature. Both belong to the `Procedure` that has
// this as its implementation. The name is the key its module declares it under,
// the same as any other declaration, and the signature is what a call site is
// checked against whichever way the body is written.
//
// Answering nil means the procedure does not apply to the types it was handed. It is
// not a failure, and it reads as absent the same as a field that was never
// set.
public protocol Query: NativeProcedure {
    // Checks arguments that are already constant, at the build. Type is the
    // signature's business; this is for what a type cannot say, such as
    // whether a string a host parses is well formed. An author typo surfaces
    // before any run.
    //
    // Asked through the door the procedure reads its arguments through, so a procedure
    // names a key here the way it names one when it answers. There is no run
    // behind this one, so a procedure it was handed cannot be called.
    func validate(_ question: Question<Self>) throws

    func evaluate(_ question: Question<Self>) async throws -> Value?
}

public extension Query {
    func validate(_ question: Question<Self>) throws {
    }
}
