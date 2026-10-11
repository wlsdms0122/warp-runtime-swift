//
//  Supplying.swift
//  Warp
//
//  Created by JSilver on 9/10/26.
//

import Foundation

// The native code a host brings to a link, by the spelling each procedure was
// declared under.
//
// A compiled document names the procedures it left to native code and carries none
// of it. What runs is a Swift value the host built, and a document has no way
// to say what that value is, so the code arrives beside the objects and a
// link joins the two by name.
//
// Held by the host rather than read out of the modules at every call. The
// procedures a host brings are the same procedures every run, and joining them up is
// what a link would otherwise pay for again each time.
public struct Supplying: Sendable {
    // A procedure a host brought, beside what it declares about itself. Read
    // once when the supply is built: a link asks the same questions of the
    // same procedures every time it joins them up.
    struct Brought: Sendable {
        // MARK: - Property
        let native: Native

        // What the module bringing it declared it takes and answers. A row
        // stands on the declaration it was compiled against, so this is what
        // says the two are one procedure.
        let signature: Signature
        let sending: [Native.Send]

        // Whether the module bringing it is one the specification names. What
        // a constant settles from is read off this.
        let builtin: Bool

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // A host bringing no native code at all. What a document left to its
    // host is then refused wherever it stands.
    public static let none = Supplying()

    private let procedures: [Name: Brought]

    // What a module brings under a private spelling, by the document that
    // declares it: named by that document alone, so two modules may each bring
    // one. A module that is no document brings none; the validator refuses one
    // that tries.
    private let hidden: [Identity: [Name: Brought]]

    // MARK: - Initializer
    private init() {
        self.procedures = [:]
        self.hidden = [:]
    }

    // A spelling two of them bring is refused here, in the words a link
    // refuses a name two documents declare in: a table with two answers for
    // one name has no answer, and which of the two a run would get is the
    // order the host happened to write.
    public init(_ modules: [Module]) throws {
        var procedures: [Name: Brought] = [:]
        var hidden: [Identity: [Name: Brought]] = [:]
        var bringing: [Name: String] = [:]
        var bringingHidden: [Identity: [Name: String]] = [:]

        for (position, module) in modules.enumerated() {
            for (name, procedure) in module.procedures.sorted(by: { $0.key < $1.key }) {
                guard let native = procedure.implementation.native else { continue }

                let declaration = Placed(procedure, at: .procedure(name.spelling, in: .of(module)), of: position)

                let brought = Brought(
                    native: native,
                    signature: procedure.signature,
                    sending: native.sending,
                    builtin: module.builtin
                )

                // Named by its document alone, so it is kept by its document.
                guard procedure.access.reachesOtherDocuments else {
                    guard let identity = module.identity else {
                        assertionFailure("a module that is no document brings '\(name)' privately")
                        continue
                    }

                    if let first = bringingHidden[identity]?[name] {
                        throw BuildError.declaredTwice(name, by: first, and: declaration.spelled, at: declaration.place)
                    }

                    hidden[identity, default: [:]][name] = brought
                    bringingHidden[identity, default: [:]][name] = declaration.spelled

                    continue
                }

                if let first = bringing[name] {
                    throw BuildError.declaredTwice(name, by: first, and: declaration.spelled, at: declaration.place)
                }

                procedures[name] = brought
                bringing[name] = declaration.spelled
            }
        }

        self.procedures = procedures
        self.hidden = hidden
    }

    // MARK: - Public
    // What was brought under a spelling for the document at hand: its own
    // private procedure first, then what any document may name. Nil where the
    // host brought none, and what a row does about that is the row's.
    subscript(_ name: Name, at document: Place.Document) -> Brought? {
        document.identity.flatMap { identity in hidden[identity]?[name] } ?? procedures[name]
    }

    // MARK: - Private
}
