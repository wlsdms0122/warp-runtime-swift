//
//  Circles.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// A graph's strongly connected components, each after everything it reaches —
// Tarjan's, which finds them in exactly that order.
//
// A vocabulary of its own because nothing in here is about what the graph was
// built from. The link builds one out of which declaration could read its
// answer from which, and reads them back in this order; that is the caller's
// sentence, and this is the walk. A walk this delicate — see below — is one
// that should stand on a graph alone.
//
// It carries its own stack. Written as recursion it descends once per edge in
// a chain, and a chain is as long as the graph is — three hundred declarations
// calling one another in a line is an ordinary program and was enough to end
// the process on the host's stack. Nesting depth is a document's own fact and
// the walks over expressions may lean on it; call depth is not.
enum Circles {
    // MARK: - Internal
    static func among(_ edges: [Name: [Name]]) -> [[Name]] {
        // Where each was met, and the earliest any way on from it can reach
        // back to — a component closes where the two agree.
        var met: [Name: Int] = [:]
        var reaches: [Name: Int] = [:]
        var standing: Set<Name> = []
        var path: [Name] = []
        var next = 0
        var found: [[Name]] = []

        // One name being walked, and how far along its sends the walk is.
        struct Step {
            let name: Name
            let sends: [Name]
            var position = 0
        }

        func meet(_ name: Name) {
            met[name] = next
            reaches[name] = next
            next += 1
            path.append(name)
            standing.insert(name)
        }

        func carry(_ reach: Int?, to name: Name) {
            guard let reach, let held = reaches[name] else { return }

            reaches[name] = min(held, reach)
        }

        // In name order, so which component comes first is a fact of the text
        // rather than of a hash seed.
        for root in edges.keys.sorted() where met[root] == nil {
            meet(root)

            var work = [Step(name: root, sends: edges[root] ?? [])]

            while var step = work.popLast() {
                if step.position < step.sends.count {
                    let sent = step.sends[step.position]

                    step.position += 1
                    work.append(step)

                    guard let sends = edges[sent] else { continue }

                    if met[sent] == nil {
                        meet(sent)
                        work.append(Step(name: sent, sends: sends))
                    } else if standing.contains(sent) {
                        carry(met[sent], to: step.name)
                    }

                    continue
                }

                // Every way on from this one has been walked. Where nothing it
                // reached got back to anything met before it, everything still
                // standing above it is one component.
                if reaches[step.name] == met[step.name] {
                    var circle: [Name] = []

                    while let last = path.popLast() {
                        standing.remove(last)
                        circle.append(last)

                        if last == step.name { break }
                    }

                    found.append(circle)
                }

                if let asked = work.last?.name {
                    carry(reaches[step.name], to: asked)
                }
            }
        }

        return found
    }
}
