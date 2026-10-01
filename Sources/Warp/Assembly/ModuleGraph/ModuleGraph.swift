//
//  ModuleGraph.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// The modules of one link, standing in the order each one's needs stand
// before it.
//
// A module is compiled against what it needs, so what it needs has to be
// compiled first: the procedures it sends answer with types, the facts nobody
// declared (constness, isolation, failure) are read off what a body reaches, and
// a constant settles by running the procedures it calls. All three are answers a
// module asks its neighbours for, and asking for one that is not ready yet
// has no answer to give.
//
// Two modules that need each other have no such order, so this refuses them.
// The names each side needs of the other are what makes the cycle, and neither
// can be the one that goes first.
//
// What a module needs is read the way a link reads it: the procedures it calls and
// the types its signatures name. A name nothing here declares is left alone:
// the build refuses it, and refusing here would be a second copy of a rule that
// has to be right once.
//
// A name two modules declare is answered by whichever declared it first, which
// is arbitrary and can put a module in its own reach. Standing a graph is
// therefore worth asking only of modules already held to declaring each name
// once, and a caller that asks before that can be told about a cycle the
// doubled name made.
public struct ModuleGraph: Sendable {
    // MARK: - Property
    // Where each module stands in the list it was given in, in the order each
    // one's needs stand before it. Positions rather than the modules, because
    // everything else a link builds is keyed by where the host put a module
    // and a second numbering would be a second answer to that.
    public let standing: [Int]

    private let given: [Module]

    // The modules themselves, in that order.
    public var modules: [Module] {
        standing.map { position in given[position] }
    }

    // MARK: - Initializer
    // `held` is how many documents stand in the link before these, so a
    // refusal counts the list the host handed over rather than this array.
    public init(_ modules: [Module], after held: Int = 0) throws {
        // Which module declares each reference. One table, since every one of
        // them answers the same question; the kind rides on the reference, so
        // a procedure and a type spelled alike stay two rows.
        var declares: [Reference: Int] = [:]

        for (position, module) in modules.enumerated() {
            // In no order. Which module answers a reference is the order the
            // host handed the modules over, and inside one module no two of
            // these are the same reference, so nothing here reads an order.
            for reference in module.supplies {
                guard declares[reference] == nil else { continue }

                declares[reference] = position
            }
        }

        // What each module needs of another, and under which name, so a
        // refusal can name the step rather than the cycle.
        let needs = modules.enumerated().map { position, module in
            var reached: [(position: Int, name: Name)] = []

            func need(_ name: Name, of declaring: Int?) {
                guard let declaring, declaring != position else { return }

                reached.append((declaring, name))
            }

            for used in module.references.sorted() {
                need(used.name, of: declares[used])
            }

            return reached
        }

        // Depth first, so the cycle a refusal names is the one path that closed
        // it rather than every module the walk had open. Roots in the order the
        // host handed the modules over, and needs in name order, so which
        // cycle is found first is a fact of the modules and not of a hash seed.
        var standing: [Int] = []
        var settled = [Bool](repeating: false, count: modules.count)
        var walking = [Bool](repeating: false, count: modules.count)
        var route: [(position: Int, name: Name)] = []

        func stand(_ position: Int) throws {
            if settled[position] { return }

            guard !walking[position] else {
                let cycle = route.drop { step in step.position != position }.map { step in
                    let document = Place.Document.of(modules[step.position]).spelled(at: held + step.position)

                    return "\(document) needs '\(step.name)'"
                }

                throw ModuleGraphError(
                    "these modules need each other, so there is no order to compile them in:"
                        + " \(cycle.joined(separator: ", then "))."
                        + " A module is compiled against what it needs, so what it needs stands first",
                    at: Place(in: .of(modules[position]))
                )
            }

            walking[position] = true

            for need in needs[position] {
                route.append((position, need.name))

                try stand(need.position)

                route.removeLast()
            }

            walking[position] = false
            settled[position] = true

            standing.append(position)
        }

        for position in modules.indices {
            try stand(position)
        }

        self.given = modules
        self.standing = standing
    }

    // MARK: - Public
    // MARK: - Private
}
