//
//  Module+Host.swift
//  warpx
//

import Foundation
import Warp

extension Module {
    // What the runner's host lends a program: a log and a keyed store. All
    // three reach outside the run, so all three are effects.
    static func host() throws -> Module {
        try Module(
            types: [
                "Host.Ticket": .struct(["id": .int])
            ],
            procedures: [
                "Host.issue": Procedure(
                    signature: Signature(of: IssueEffect.self, returns: .named("Host.Ticket")),
                    implementation: .effect(IssueEffect())
                ),
                "Host.redeem": Procedure(
                    signature: Signature(of: RedeemEffect.self, returns: .int),
                    implementation: .effect(RedeemEffect())
                ),
                "Host.log": Procedure(
                    signature: Signature(of: LogEffect.self, returns: .null),
                    implementation: .effect(LogEffect())
                ),
                "Host.put": Procedure(
                    signature: Signature(of: PutEffect.self, returns: .null),
                    implementation: .effect(PutEffect())
                ),
                "Host.get": Procedure(
                    signature: Signature(of: GetEffect.self, returns: .any),
                    implementation: .effect(GetEffect())
                )
            ]
        )
    }
}

enum LogParameters: Int, ParameterSet {
    case of

    var declared: Parameter { Parameter(name: "of", type: .any) }
}

struct LogEffect: Effect {
    typealias Parameters = LogParameters


    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await Store.of(invocation).note("\(invocation[.of])")

        return .null
    }
}

enum PutParameters: Int, ParameterSet {
    case key
    case value

    var declared: Parameter {
        switch self {
        case .key:
            return Parameter(name: "key", type: .string)

        case .value:
            return Parameter(name: "value", type: .any)
        }
    }
}

struct PutEffect: Effect {
    typealias Parameters = PutParameters


    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard case let .string(key) = invocation[.key] else {
            throw ExecutionError("'\(invocation.selector)' keeps under a string key")
        }

        try await Store.of(invocation).put(key, invocation[.value])

        return .null
    }
}

enum GetParameters: Int, ParameterSet {
    case key

    var declared: Parameter { Parameter(name: "key", type: .string) }
}

struct GetEffect: Effect {
    typealias Parameters = GetParameters


    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard case let .string(key) = invocation[.key] else {
            throw ExecutionError("'\(invocation.selector)' reads under a string key")
        }

        return try await Store.of(invocation).get(key)
    }
}

struct IssueEffect: Effect {
    typealias Parameters = NoParameters


    func run(_ invocation: Invocation<Self>) async throws -> Value {
        let store = try Store.of(invocation)
        let id = await store.issue()

        return try Value.holding([(name: "id", value: .int(id))], named: "Host.Ticket")
    }
}

enum RedeemParameters: Int, ParameterSet {
    case of

    var declared: Parameter { Parameter(name: "of", type: .named("Host.Ticket")) }
}

struct RedeemEffect: Effect {
    typealias Parameters = RedeemParameters


    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard case let .struct(ticket) = invocation[.of], case let .int(id) = ticket["id"] else {
            throw ExecutionError("'\(invocation.selector)' redeems a ticket, and \(invocation[.of]) arrived")
        }

        let store = try Store.of(invocation)

        guard await store.redeem(id) else {
            throw ExecutionError("'\(invocation.selector)' redeems ticket \(id), which is not open")
        }

        await store.note("redeemed \(id)")

        return .int(id)
    }
}
