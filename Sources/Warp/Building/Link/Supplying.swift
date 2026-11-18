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
// A compiled document names the procedures it left to native code and carries
// none of it. What runs is a Swift value the host built, and a document has no
// way to say what that value is, so the code arrives beside the objects and a
// link joins the two by name.
//
// Held by the host rather than read out of the modules at every call. The
// procedures a host brings are the same procedures every run, and joining them
// up is what a link would otherwise pay for again each time.
//
// The modules' text is what a link reads one more fact off: where each closure
// literal a declaration wrote stands, which an object does not say, so that a
// run refusing inside a closure names where its body stands.
public struct Supplying: Sendable {
    // A procedure a host brought, beside what it declares about itself. Read
    // once when the supply is built: a link asks the same questions of the
    // same procedures every time it joins them up.
    struct Brought: Sendable {
        // MARK: - Property
        let native: Native

        // What the module bringing it declared it takes and returns. A row
        // stands on the declaration it was compiled against, so this is what
        // says the two are one procedure.
        let signature: Signature
        let sending: [Native.Send]

        // Whether the module bringing it is one the specification names. What
        // a constant folds from is read off this.
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

    // Where the body of each closure literal a declaration wrote stands, by
    // the document's identity and the declaration, in the order its document
    // numbers them. A module that is no document has no place to give.
    private let closures: [Identity: [Closure.Declaration: [Place]]]

    // MARK: - Initializer
    private init() {
        self.procedures = [:]
        self.hidden = [:]
        self.closures = [:]
    }

    // A spelling two of them bring is refused here, in the words a link
    // refuses a name two documents declare in: a table with two entries for
    // one name gives neither, and which of the two a run would get is the
    // order the host happened to write.
    public init(_ modules: [Module]) throws {
        self = try BuildRefused.refusing { try Supplying(bringing: modules) }
    }

    private init(bringing modules: [Module]) throws {
        var procedures: [Name: Brought] = [:]
        var hidden: [Identity: [Name: Brought]] = [:]
        var bringing: [Name: String] = [:]
        var bringingHidden: [Identity: [Name: String]] = [:]
        var closures: [Identity: [Closure.Declaration: [Place]]] = [:]

        for (position, module) in modules.enumerated() {
            if let identity = module.identity {
                closures[identity] = Self.closures(writtenBy: module)
            }

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
        self.closures = closures
    }

    // MARK: - Public
    // What was brought under a spelling for a row of the document at hand: a
    // private row's from that document's own module alone, any other's from
    // what any document may name. Nil where the host brought none, and what a
    // row does about that is the row's.
    subscript(_ name: Name, at document: Place.Document, access access: Access) -> Brought? {
        guard access.reachesOtherDocuments else {
            return document.identity.flatMap { identity in hidden[identity]?[name] }
        }

        return procedures[name]
    }

    // Where the body of the nth closure literal a declaration wrote stands in
    // a document, or nil where no module handed over is that document.
    func body(ofClosure nth: Int, by writer: Closure.Declaration, at document: Place.Document) -> Place? {
        guard
            let identity = document.identity,
            let written = closures[identity]?[writer],
            written.indices.contains(nth)
        else { return nil }

        return written[nth]
    }

    // MARK: - Private
    // Where the body of every closure literal a module's declarations wrote
    // stands, by declaration: a procedure's body, a constant's expression and
    // a variable's start, each where the build reads it.
    private static func closures(writtenBy module: Module) -> [Closure.Declaration: [Place]] {
        let document = Place.Document.of(module)
        var closures: [Closure.Declaration: [Place]] = [:]

        for (name, procedure) in module.procedures {
            guard let body = procedure.implementation.body else { continue }

            closures[.procedure(name)] = bodies(in: body, at: Place.procedure(name.spelling, in: document).part(.body))
        }

        for (name, expression) in module.constants {
            closures[.binding(name)] = bodies(in: expression, at: .constant(name.spelling, in: document))
        }

        for (name, variable) in module.variables {
            closures[.binding(name)] = bodies(
                in: variable.start,
                at: variable.start(at: .variable(name.spelling, in: document))
            )
        }

        return closures.filter { _, bodies in !bodies.isEmpty }
    }

    // Where the body of each closure literal in here stands, in the order a
    // build numbers them: a closure after every closure written inside it,
    // since its number is taken once its own body is lowered. The walk finds a
    // closure before what it holds, so one found inside the last one still
    // open waits on it, and one found anywhere else closes it.
    private static func bodies(in held: some Traversable, at place: Place) -> [Place] {
        var numbered: [Place] = []
        var open: [Place] = []

        for (found, expression) in held.subexpressions(at: place) {
            guard case .closure = expression else { continue }

            while let last = open.last, !found.steps.starts(with: last.steps) {
                numbered.append(open.removeLast())
            }

            open.append(found)
        }

        numbered.append(contentsOf: open.reversed())

        return numbered.map { literal in literal.part(.body) }
    }
}
