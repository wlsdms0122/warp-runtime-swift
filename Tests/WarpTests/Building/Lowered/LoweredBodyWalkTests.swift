//
//  LoweredBodyWalkTests.swift
//  WarpTests
//
//  Created by JSilver on 9/18/26.
//

import Testing
@testable import Warp

// The two traversals every reading and rewriting of lowered code stands on:
// which nodes a walk reaches, in what order, and what a rewrite hands its
// caller.
@Suite("A body walked and rewritten")
struct LoweredBodyWalkTests {
    // MARK: - Property
    // A distinctive leaf, so a test can tell whether a case's children were
    // reached at all.
    private let leaf = Operation.literal(.int(7))

    private var address: Address { Address(slot: 3, steps: [.at(Address(slot: 4, steps: []), optional: false)]) }

    // Every case of `Operation` that holds another operation, each holding
    // the leaf where it holds one.
    private var holders: [(name: String, operation: Operation)] {
        get throws {
            let body = LoweredBody(instructions: [Instruction(binding: nil, code: leaf, label: "leaf")], result: nil)
            let call = CallOperation(procedure: 1, arguments: [leaf, nil], handed: [])

            return [
                ("array", .array([leaf])),
                ("record", .record(RecordOperation(layout: try Layout(fields: ["a"]), fields: [leaf]))),
                ("apply", .apply(leaf, arguments: [])),
                ("cast", .cast(leaf, as: .int, optional: false)),
                ("block", .block(body)),
                ("conditional", .conditional(leaf, then: [], else: nil)),
                ("loop", .loop(while: leaf, body: LoweredBody(instructions: [], result: nil), round: 0, keeps: nil)),
                ("attempt", .attempt(body, rescue: LoweredBody(instructions: [], result: nil), failure: 0)),
                ("call", .call(call)),
                ("dispatch", .dispatch(DispatchOperation(contract: "c", procedure: "p", first: leaf, arguments: []))),
                ("dispatch argument", .dispatch(DispatchOperation(contract: "c", procedure: "p", first: .literal(.null), arguments: [.value(leaf)]))),
                ("leave", .leave(.procedure, target: nil, leaf))
            ]
        }
    }

    // Every case `kind(of:)` spells, so a case added there is held to being a
    // leaf or having a holder.
    private let kinds: Set<String> = [
        "literal", "local", "array", "record", "closure", "apply", "cast", "block",
        "conditional", "loop", "attempt", "call", "dispatch", "leave"
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("every case that holds an operation has a holder here")
    func everyHoldingCaseIsAHolder() throws {
        // Given. The cases that hold no operation, and every other case is held
        // to having a holder above
        let leaves: Set<String> = ["literal", "local", "closure"]
        let holding = Set(try holders.map { _, operation in kind(of: operation) })

        // When / Then
        #expect(holding.isDisjoint(with: leaves))
        #expect(holding.union(leaves) == kinds)
    }

    @Test("every case that holds an operation walks into it")
    func everyHolderIsWalkedInto() throws {
        // When / Then
        for (name, operation) in try holders {
            var reached = false

            operation.walk { node in
                if case let .operation(inner) = node, case .literal(.int(7)) = inner { reached = true }

                return true
            }

            #expect(reached, "\(name)")
        }
    }

    @Test("every case that holds an operation hands it to a rewrite first")
    func everyHolderIsRewrittenInsideFirst() throws {
        // When / Then
        for (name, operation) in try holders {
            var seen: [String] = []

            let rewritten = operation.rewritten(
                operation: { inner in
                    if case .literal(.int(7)) = inner {
                        seen.append("leaf")

                        return .literal(.int(8))
                    }

                    seen.append("holder")

                    return inner
                },
                type: { type in type }
            )

            // The leaf is handed over before the case holding it, which comes
            // last, and the case arrives holding the rewritten leaf.
            let leafAt = try #require(seen.firstIndex(of: "leaf"), "\(name)")

            #expect(seen.last == "holder" && leafAt < seen.count - 1, "\(name)")
            #expect(rewritten.contains { node in
                if case let .operation(inner) = node, case .literal(.int(8)) = inner { return true }

                return false
            }, "\(name)")
        }
    }

    @Test("a walk reaches a node before what nests in it, and stops where a visit says")
    func aWalkIsOutermostFirstAndStops() {
        // Given
        let inner = Operation.array([leaf])
        let sut = Operation.array([inner])
        var order: [String] = []

        let whole = sut.walk { node in

        // When / Then
            guard case let .operation(operation) = node else { return true }

            switch operation {
            case .array: order.append("array")
            case .literal: order.append("leaf")
            default: order.append("other")
            }

            return true
        }

        #expect(whole)
        #expect(order == ["array", "array", "leaf"])

        var visited = 0
        let stopped = sut.walk { _ in
            visited += 1

            return false
        }

        #expect(!stopped)
        #expect(visited == 1)
    }

    @Test("an instruction is a node of its own, and its binding is what the node reads")
    func anInstructionIsANode() {
        // Given
        let sut = LoweredBody(
            instructions: [Instruction(binding: .assign(address, settling: nil), code: leaf, label: "write")],
            result: nil
        )
        var instructions = 0

        sut.walk { node in
            if case .instruction = node { instructions += 1 }

            return true
        }

        // When / Then
        #expect(instructions == 1)
        #expect(sut.reads(4..<5))
        #expect(!sut.reads(9..<10))
    }

    @Test("an argument handed in place is the dispatch's own to read")
    func aReferenceArgumentIsReadByItsNode() {
        // Given
        let sut = Operation.dispatch(
            DispatchOperation(contract: "c", procedure: "p", first: .literal(.null), arguments: [.reference(address)])
        )
        var locals = 0

        sut.walk { node in
            if case let .operation(inner) = node, case .local = inner { locals += 1 }

            return true
        }

        // When / Then. The place is not walked as an operation, and the reads
        // and the standing both count it.
        #expect(locals == 0)
        #expect(sut.reads(3..<4))
        #expect(sut.reads(4..<5))

        let standing = LoweredBody(instructions: [], result: sut).standing

        #expect(standing.slots.contains(3))
        #expect(standing.slots.contains(4))
    }

    @Test("the calls beside a dispatch are neither walked nor rewritten")
    func aDispatchsCallsAreTheLinks() {
        // Given
        let beside = CallOperation(procedure: 5, arguments: [leaf], handed: [])
        let sut = Operation.dispatch(
            DispatchOperation(contract: "c", procedure: "p", first: .literal(.null), arguments: [], calls: ["t": beside])
        )
        var leaves = 0

        sut.walk { node in
            if case let .operation(inner) = node, case .literal(.int(7)) = inner { leaves += 1 }

            return true
        }

        let rewritten = sut.rewritten(operation: { operation in
            if case .literal(.int(7)) = operation { return .literal(.int(8)) }

            return operation
        }, type: { type in type })

        // When / Then
        #expect(leaves == 0)

        guard case let .dispatch(dispatch) = rewritten, case .literal(.int(7))?? = dispatch.calls["t"]?.arguments.first else {
            Issue.record("the calls beside the dispatch stand as the link laid them")

            return
        }
    }

    @Test("a rewrite hands a cast's type and a binding's settling to the type door")
    func aRewriteHandsTypesOver() {
        // Given
        let sut = LoweredBody(
            instructions: [Instruction(binding: .bind(0, settling: .int), code: .cast(leaf, as: .string, optional: false), label: "cast")],
            result: nil
        )
        var types: [LoweredType] = []

        _ = sut.rewritten(operation: { operation in operation }, type: { type in
            types.append(type)

            return type
        })

        // When / Then
        #expect(types.count == 2 && types.contains(.string) && types.contains(.int))
    }

    // MARK: - Public
    // MARK: - Private
    // Which case an operation is, spelled. Exhaustive, so a case added to
    // `Operation` lands here as a compile error.
    private func kind(of operation: Operation) -> String {
        switch operation {
        case .literal: return "literal"
        case .local: return "local"
        case .array: return "array"
        case .record: return "record"
        case .closure: return "closure"
        case .apply: return "apply"
        case .cast: return "cast"
        case .block: return "block"
        case .conditional: return "conditional"
        case .loop: return "loop"
        case .attempt: return "attempt"
        case .call: return "call"
        case .dispatch: return "dispatch"
        case .leave: return "leave"
        }
    }
}
