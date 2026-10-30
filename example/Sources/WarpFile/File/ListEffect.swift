//
//  ListEffect.swift
//  WarpFile
//

import Foundation
import Warp

struct ListEffect: Effect {
    typealias Parameters = PathParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        let file = try File(invocation, at: .path)

        do {
            return .array(try FileManager.default.contentsOfDirectory(atPath: file.url.path).sorted().map(Value.string))
        } catch {
            throw FileFailed("'\(file.path)' does not list: \(error.localizedDescription)", path: file.path)
        }
    }

    // MARK: - Private
}
