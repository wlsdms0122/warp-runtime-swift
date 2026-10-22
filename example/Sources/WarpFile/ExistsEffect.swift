//
//  ExistsEffect.swift
//  WarpFile
//

import Foundation
import Warp

struct ExistsEffect: Effect {
    typealias Parameters = PathParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        .bool(FileManager.default.fileExists(atPath: try Lent.file(invocation, at: .path).url.path))
    }

    // MARK: - Private
}
