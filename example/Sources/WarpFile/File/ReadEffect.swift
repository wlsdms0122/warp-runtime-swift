//
//  ReadEffect.swift
//  WarpFile
//

import Foundation
import Warp

struct ReadEffect: Effect {
    typealias Parameters = PathParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        let file = try File(invocation, at: .path)

        guard FileManager.default.fileExists(atPath: file.url.path) else { return .null }

        do {
            return .string(try String(contentsOf: file.url, encoding: .utf8))
        } catch {
            throw FileFailed("'\(file.path)' does not read as text: \(error.localizedDescription)", path: file.path)
        }
    }

    // MARK: - Private
}
