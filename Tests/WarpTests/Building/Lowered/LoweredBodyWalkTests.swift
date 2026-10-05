//
//  LoweredBodyWalkTests.swift
//  WarpTests
//
//  Created by JSilver on 9/18/26.
//

import Foundation
import Testing
@testable import Warp

// The two traversals every reading and rewriting of lowered code stands on:
// which nodes a walk reaches, in what order, and what a rewrite hands its
// caller.
@Suite("A body walked and rewritten")
struct LoweredBodyWalkTests {
    private enum Kind: CaseIterable {
        case literal
        case local
        case array
        case record
        case closure
        case apply
        case cast
        case checked
        case block
        case conditional
        case loop
        case attempt
        case call
        case dispatch
        case leave

        // MARK: - Property
        // MARK: - Initializer
        init(_ operation: Warp.Operation) {
            switch operation {
            case .literal: self = .literal
            case .local: self = .local
            case .array: self = .array
            case .record: self = .record
            case .closure: self = .closure
            case .apply: self = .apply
            case .cast: self = .cast
            case .checked: self = .checked
            case .block: self = .block
            case .conditional: self = .conditional
            case .loop: self = .loop
            case .attempt: self = .attempt
            case .call: self = .call
            case .dispatch: self = .dispatch
            case .leave: self = .leave
            }
        }

        // MARK: - Public
        func operations(holding leaf: Warp.Operation) throws -> [Warp.Operation] {
            let body = LoweredBody(instructions: [Instruction(binding: nil, code: leaf, label: "leaf")], result: nil)
            let empty = LoweredBody(instructions: [], result: nil)

            switch self {
            case .literal, .local, .closure:
                return []

            case .array:
                return [.array([leaf])]

            case .record:
                return [.record(RecordOperation(layout: try Layout(fields: ["a"]), fields: [leaf]))]

            case .apply:
                return [.apply(leaf, arguments: [])]

            case .cast:
                return [.cast(leaf, as: .int, optional: false)]

            case .checked:
                return [.checked(leaf, try #require(CallJudgement(against: .int, handedBack: [], settlesTo: nil)))]

            case .block:
                return [.block(body)]

            case .conditional:
                return [.conditional(leaf, then: [], else: nil)]

            case .loop:
                return [.loop(while: leaf, body: empty, round: 0, keeps: nil)]

            case .attempt:
                return [.attempt(body, rescue: empty, failure: 0)]

            case .call:
                return [.call(CallOperation(procedure: 1, arguments: [leaf, nil], handed: []))]

            case .dispatch:
                return [
                    .dispatch(DispatchOperation(contract: "c", procedure: "p", first: leaf, arguments: [])),
                    .dispatch(DispatchOperation(contract: "c", procedure: "p", first: .literal(.null), arguments: [.value(leaf)]))
                ]

            case .leave:
                return [.leave(.procedure, target: nil, leaf)]
            }
        }

        // MARK: - Private
    }

    // MARK: - Property
    // A distinctive leaf, so a test can tell whether a case's children were
    // reached at all.
    private let leaf = Warp.Operation.literal(.int(7))

    private var address: Address { Address(slot: 3, steps: [.at(Address(slot: 4, steps: []), optional: false)]) }

    // Every case of `Operation` that holds another operation, each holding
    // the leaf where it holds one.
    private var holders: [(kind: Kind, operation: Warp.Operation)] {
        get throws {
            try Kind.allCases.flatMap { kind in
                try kind.operations(holding: leaf).map { operation in (kind: kind, operation: operation) }
            }
        }
    }

    // MARK: - Initializer
    // MARK: - Test
    @Test("every holder here is the case it stands for")
    func everyHolderIsItsKind() throws {
        // When / Then
        for (kind, operation) in try holders {
            #expect(Kind(operation) == kind, "\(kind)")
        }
    }

    @Test("every case that holds an operation walks into it")
    func everyHolderIsWalkedInto() throws {
        // When / Then
        for (kind, operation) in try holders {
            var reached = false

            operation.walk { node in
                if case let .operation(inner) = node, case .literal(.int(7)) = inner { reached = true }

                return true
            }

            #expect(reached, "\(kind)")
        }
    }

    @Test("every case that holds an operation hands it to a rewrite first")
    func everyHolderIsRewrittenInsideFirst() throws {
        // When / Then
        for (kind, operation) in try holders {
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
            let leafAt = try #require(seen.firstIndex(of: "leaf"), "\(kind)")

            #expect(seen.last == "holder" && leafAt < seen.count - 1, "\(kind)")
            #expect(rewritten.contains { node in
                if case let .operation(inner) = node, case .literal(.int(8)) = inner { return true }

                return false
            }, "\(kind)")
        }
    }

    @Test("a walk reaches a node before what nests in it, and stops where a visit says")
    func aWalkIsOutermostFirstAndStops() {
        // Given
        let inner = Warp.Operation.array([leaf])
        let sut = Warp.Operation.array([inner])
        var order: [String] = []

        // When
        let whole = sut.walk { node in
            guard case let .operation(operation) = node else { return true }

            switch operation {
            case .array: order.append("array")
            case .literal: order.append("leaf")
            default: order.append("other")
            }

            return true
        }

        var visited = 0
        let stopped = sut.walk { _ in
            visited += 1

            return false
        }

        // Then
        #expect(whole)
        #expect(order == ["array", "array", "leaf"])
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

        // When
        sut.walk { node in
            if case .instruction = node { instructions += 1 }

            return true
        }

        // Then
        #expect(instructions == 1)
        #expect(sut.reads(4..<5))
        #expect(!sut.reads(9..<10))
    }

    @Test("an argument handed in place is the dispatch's own to read")
    func aReferenceArgumentIsReadByItsNode() {
        // Given
        let sut = Warp.Operation.dispatch(
            DispatchOperation(contract: "c", procedure: "p", first: .literal(.null), arguments: [.reference(address)])
        )
        var locals = 0

        // When
        sut.walk { node in
            if case let .operation(inner) = node, case .local = inner { locals += 1 }

            return true
        }

        let standing = LoweredBody(instructions: [], result: sut).standing

        // Then. The place is not walked as an operation, and the reads and the
        // standing both count it.
        #expect(locals == 0)
        #expect(sut.reads(3..<4))
        #expect(sut.reads(4..<5))
        #expect(standing.slots.contains(3))
        #expect(standing.slots.contains(4))
    }

    @Test("the calls beside a dispatch are neither walked nor rewritten")
    func aDispatchsCallsAreTheLinks() {
        // Given
        let beside = CallOperation(procedure: 5, arguments: [leaf], handed: [])
        let sut = Warp.Operation.dispatch(
            DispatchOperation(contract: "c", procedure: "p", first: .literal(.null), arguments: [], calls: ["t": beside])
        )
        var leaves = 0

        // When
        sut.walk { node in
            if case let .operation(inner) = node, case .literal(.int(7)) = inner { leaves += 1 }

            return true
        }

        let rewritten = sut.rewritten(operation: { operation in
            if case .literal(.int(7)) = operation { return .literal(.int(8)) }

            return operation
        }, type: { type in type })

        // Then
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

        // When
        _ = sut.rewritten(operation: { operation in operation }, type: { type in
            types.append(type)

            return type
        })

        // Then
        #expect(types.count == 2 && types.contains(.string) && types.contains(.int))
    }

    // MARK: - Public
    // MARK: - Private
}
