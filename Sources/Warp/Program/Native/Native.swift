//
//  Native.swift
//  Warp
//
//  Created by JSilver on 9/10/26.
//

import Foundation

// A procedure implemented in native code: one that touches nothing outside
// the run, or one that reaches outside it. What it reads and sends is
// its own type's to say, and read here; what a call may expect of it is its
// declaration's.
enum Native: Sendable {
    case query(any Query)
    case effect(any Effect)

    // One of the procedures it declared it sends: the spelling it reaches,
    // where it stands among them, and how many arguments it hands over there.
    struct Send: Hashable, Sendable {
        // MARK: - Property
        let position: Int
        let selector: Name
        let handing: Int

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The places it reads its arguments at, with the name each place stands
    // under. Its own, so a declaration whose parameters stand elsewhere is a
    // procedure reading an argument nobody sent it.
    var parameters: [(position: Int, name: Name)] {
        switch self {
        case let .query(query):
            return places(of: query)

        case let .effect(effect):
            return places(of: effect)
        }
    }

    // The procedures it sends, in the places it names them at.
    var imports: [Send] {
        switch self {
        case let .query(query):
            return sends(of: query)

        case let .effect(effect):
            return sends(of: effect)
        }
    }

    // The procedures it sends as a link compares them: in position order. A row
    // records these where it was compiled, and a procedure brought later naming
    // others, or handing others over, sends where the row does not stand.
    var sending: [Send] {
        imports.sorted { left, right in left.position < right.position }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    // Generic, so the procedure's own parameter type has a name here. Handing an
    // existential to a generic function opens it.
    private func places<P: NativeProcedure>(of procedure: P) -> [(position: Int, name: Name)] {
        P.Parameters.allCases.map { key in (position: key.position, name: key.name) }
    }

    private func sends<P: NativeProcedure>(of procedure: P) -> [Send] {
        P.Imports.allCases.map { key in
            Send(position: key.position, selector: key.selector, handing: key.handing)
        }
    }
}
