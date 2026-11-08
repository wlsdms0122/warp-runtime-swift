//
//  BuildRefused.swift
//  Warp
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// What a build refuses with: every refusal it reached. A document's
// declarations refuse alone, since everything else in it stands on them.
// Once they stand, each body stands on its declaration alone, so each body
// of the document is judged and refuses apart. Each refusal holds its own
// place, so this holds none.
public struct BuildRefused: WarpError {
    // MARK: - Property
    // In the order the build judged what they refuse.
    public let refusals: [BuildError]

    // Each refusal as it reads, one to a line.
    public var message: String {
        refusals.map(\.description).joined(separator: "\n")
    }

    // MARK: - Initializer
    init(_ refusals: [BuildError]) {
        self.refusals = refusals
    }

    // MARK: - Public
    // What `building` returns, with a refusal it throws held as what a build
    // refuses with.
    static func refusing<Built>(_ building: () throws -> Built) throws -> Built {
        do {
            return try building()
        } catch let refusal as BuildError {
            throw BuildRefused([refusal])
        }
    }

    static func refusing<Built>(_ building: () async throws -> Built) async throws -> Built {
        do {
            return try await building()
        } catch let refusal as BuildError {
            throw BuildRefused([refusal])
        }
    }

    // MARK: - Private
}
