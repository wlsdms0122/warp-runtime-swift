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
        let (url, path) = try Lent.file(invocation, at: .path)

        guard FileManager.default.fileExists(atPath: url.path) else { return .null }

        do {
            return .string(try String(contentsOf: url, encoding: .utf8))
        } catch {
            throw FileFailed("'\(path)' does not read as text: \(error.localizedDescription)", path: path)
        }
    }

    // MARK: - Private
}
