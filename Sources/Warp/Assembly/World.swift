//
//  World.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// The modules of one link, standing in the order each one's needs stand
// before it.
//
// A module is compiled against what it needs, so what it needs has to be
// compiled first: the words it sends answer with types, the facts nobody
// declared (purity, isolation, failure) are read off what a body reaches, and
// a constant settles by running the words it calls. All three are answers a
// module asks its neighbours for, and asking for one that is not ready yet
// has no answer to give.
//
// Two modules that need each other have no such order, so this refuses them.
// The names each side needs of the other are what makes the ring, and neither
// can be the one that goes first.
//
// What a module needs is read the way a link reads it: the words it calls, the
// bare spellings its paths step to, and the shapes its signatures name. A name
// nothing here declares is left alone, and a name two modules declare takes
// whichever declared it first. Both are the link's to refuse, and refusing
// here would be a second copy of a rule that has to be right once.
public struct World: Sendable {
    // MARK: - Property
    // In the order each module's needs stand before it.
    public let modules: [Module]

    // MARK: - Initializer
    public init(_ modules: [Module]) throws {
        // Which module declares each name, by the spelling that reaches it.
        // Three tables because a name is looked up three ways, the same three
        // a catalogue closes a world on.
        var words: [Name: Int] = [:]
        var walked: [Name: [Int]] = [:]
        var shapes: [Name: Int] = [:]

        for (position, module) in modules.enumerated() {
            let draft = module.draft
            let walkable = draft.walkableWords

            for name in draft.declaredWords.sorted() {
                guard words[name] == nil else { continue }

                words[name] = position

                guard walkable.contains(name) else { continue }

                walked[name.unqualified, default: []].append(position)
            }

            for name in draft.declaredShapes.sorted() where shapes[name] == nil {
                shapes[name] = position
            }
        }

        // What each module needs of another, and under which name, so a
        // refusal can name the step rather than the ring.
        let needs = modules.enumerated().map { position, module in
            let draft = module.draft
            var reached: [(position: Int, name: Name)] = []

            func need(_ name: Name, of declaring: Int?) {
                guard let declaring, declaring != position else { return }

                reached.append((declaring, name))
            }

            for name in draft.sends.sorted() {
                need(name, of: words[name])
            }

            for name in draft.walks.sorted() {
                for declaring in walked[name] ?? [] {
                    need(name, of: declaring)
                }
            }

            for name in draft.mentions.sorted() {
                need(name, of: shapes[name])
            }

            return reached
        }

        // Depth first, so the ring a refusal names is the one path that closed
        // it rather than every module the walk had open. Roots in the order the
        // caller handed the modules over, and needs in name order, so which
        // ring is found first is a fact of the world and not of a hash seed.
        var standing: [Module] = []
        var settled = [Bool](repeating: false, count: modules.count)
        var walking = [Bool](repeating: false, count: modules.count)
        var route: [(position: Int, name: Name)] = []

        func stand(_ position: Int) throws {
            if settled[position] { return }

            guard !walking[position] else {
                let ring = route.drop { step in step.position != position }

                throw WorldError(
                    "these modules need each other, so there is no order to compile them in:"
                        + " \(ring.map { step in "\(Place.Document.of(modules[step.position]).spelled(at: step.position)) needs '\(step.name)'" }.joined(separator: ", then "))."
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

            standing.append(modules[position])
        }

        for position in modules.indices {
            try stand(position)
        }

        self.modules = standing
    }

    // MARK: - Public
    // MARK: - Private
}
