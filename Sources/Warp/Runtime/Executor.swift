//
//  Executor.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Runs an image. What a host holds and hands every run: who watches, and what
// the run may reach outside itself.
public struct Executor: Sendable {
    // MARK: - Property
    public let observer: (any ExecutionObserver)?
    public let environment: (any Environment)?

    // MARK: - Initializer
    public init(
        observer: (any ExecutionObserver)? = nil,
        environment: (any Environment)? = nil
    ) {
        self.observer = observer
        self.environment = environment
    }

    // MARK: - Public
    // Running takes an image, not a procedure, so "ran something that was never
    // linked" is not a state this type can be put in. Which declaration it
    // starts from is named here: an image is every declaration the link
    // judged, and a run starts from any public one.
    public func run(
        _ image: Image,
        entry: Name,
        arguments: [Name: Value] = [:]
    ) async throws -> Value {
        // A name is its declared spelling and nothing else, so the entry is
        // looked up as the host wrote it.
        guard let start = image.rows[entry] else {
            // A spelling only a private declaration wears is declared, and by
            // nothing the host may name.
            guard !image.concealed.contains(entry) else {
                throw refusal(entry: entry, access: .private)
            }

            throw ExecutionError(
                "entry '\(entry)' is not declared by any module in this link."
                    + " A name is its declared spelling. Declared:"
                    + " \(image.rows.keys.sorted().map(\.spelling).joined(separator: ", "))"
            )
        }

        let entry = image.linked[start]

        guard entry.access.reachesHost else {
            throw refusal(entry: entry.label, access: entry.access)
        }

        return try await Evaluator(image, observer: observer, environment: environment)
            .run(entry, arguments: arguments)
    }

    // MARK: - Private
    // A run starts from outside the link, and only a public declaration is
    // named from there.
    private func refusal(entry: Name, access: Access) -> ExecutionError {
        ExecutionError("entry '\(entry)' is \(access.rawValue), and a run starts only from a public declaration")
    }
}
