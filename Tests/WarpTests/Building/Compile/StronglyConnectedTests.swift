//
//  StronglyConnectedTests.swift
//  WarpTests
//
//  Created by JSilver
//

import Foundation
import Testing
@testable import Warp

// The order unwritten answers are read in, asked of the graph alone.
//
// The walk is a plain strongly-connected-components walk and knows nothing
// about linking, so this is what it is tested on. It also carries its own
// stack, because written as recursion a chain of calls descends once per link
// and a chain is as long as a program. A fact only a graph this size states.
@Suite("The call graph is walked callee first, and a cycle is one component")
struct StronglyConnectedTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("everything a name reaches is closed before the name is")
    func calleesComeFirst() {
        // Given. A line of three, and a fourth nobody calls.
        let found = StronglyConnected(among: [
            "a": ["b"],
            "b": ["c"],
            "c": [],
            "loner": []
        ]).components()

        #expect(found.map(\.count).allSatisfy { count in count == 1 })

        let order = found.flatMap { cycle in cycle }

        #expect(order.firstIndex(of: "c")! < order.firstIndex(of: "b")!)
        #expect(order.firstIndex(of: "b")! < order.firstIndex(of: "a")!)
        #expect(order.contains("loner"))
    }

    @Test("names that reach one another are one component, a self-call included")
    func cyclesAreOneComponent() {
        let mutual = StronglyConnected(among: ["ping": ["pong"], "pong": ["ping"]]).components()

        #expect(mutual.count == 1)
        #expect(Set(mutual[0]) == ["ping", "pong"])

        // A name that reaches itself is its own cycle. One member, and the
        // caller tells it from a plain singleton by asking whether it sends to
        // itself.
        let alone = StronglyConnected(among: ["self": ["self"]]).components()

        #expect(alone == [["self"]])
    }

    @Test("an edge to a name outside the graph is not an edge")
    func unknownNamesAreNotWalked() {
        // Every selector a body sends is gathered, and most of them name
        // declarations that said what they answer. Those are not in here.
        let found = StronglyConnected(among: ["a": ["declared", "b"], "b": []]).components()

        #expect(found.flatMap { cycle in cycle }.sorted() == ["a", "b"])
    }

    @Test("a chain as long as a program is walked without the host's stack")
    func aLongChainIsWalked() throws {
        // Given. Three hundred declarations calling one another in a line,
        // which is an ordinary program and was enough to end the process when
        // this walk was written as recursion.
        let names = try (0..<300).map { position in try Name("p\(position)") }
        let edges = Dictionary(
            uniqueKeysWithValues: names.enumerated().map { position, name in
                (name, position + 1 < names.count ? [names[position + 1]] : [])
            }
        )

        let found = StronglyConnected(among: edges).components()

        #expect(found.count == names.count)
        #expect(found.flatMap { cycle in cycle }.first == names.last)
    }

    // MARK: - Public
    // MARK: - Private
}
