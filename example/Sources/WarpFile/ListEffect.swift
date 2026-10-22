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
        let (url, path) = try Lent.file(invocation, at: .path)

        do {
            return .array(try FileManager.default.contentsOfDirectory(atPath: url.path).sorted().map(Value.string))
        } catch {
            throw FileFailed("'\(path)' does not list: \(error.localizedDescription)", path: path)
        }
    }

    // MARK: - Private
}
