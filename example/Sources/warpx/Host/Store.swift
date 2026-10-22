//
//  Store.swift
//  warpx
//

import Foundation
import Warp

// What the host lends a run: a place to keep values by key, a log to append
// lines to, and the tickets it issued and has not seen redeemed. A ticket is
// the host's to keep: a document holds its id, and the host says whether it
// is still open. An effect reaches it through the environment.
actor Store: Environment {
    // MARK: - Property
    private(set) var kept: [String: Value] = [:]
    private(set) var log: [String] = []
    private var issued = 0
    private var open: Set<Int> = []

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    func put(_ key: String, _ value: Value) {
        kept[key] = value
    }

    func get(_ key: String) -> Value {
        kept[key] ?? .null
    }

    func note(_ line: String) {
        log.append(line)
    }

    func issue() -> Int {
        issued += 1
        open.insert(issued)

        return issued
    }

    // Whether the ticket was open, ending it if it was.
    func redeem(_ id: Int) -> Bool {
        open.remove(id) != nil
    }

    static func of<P: NativeProcedure>(_ invocation: Invocation<P>) throws -> Store {
        guard let store = invocation.environment as? Store else {
            throw ExecutionError("'\(invocation.selector)' reaches a store, and this run was handed none")
        }

        return store
    }

    // MARK: - Private
}
