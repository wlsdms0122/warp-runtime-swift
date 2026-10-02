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
                throw ExecutionError(
                    "entry '\(entry)' is private to the document that declares it, and a run"
                        + " starts only from a public declaration"
                )
            }

            throw ExecutionError(
                "entry '\(entry)' is not declared by any module in this link."
                    + " A name is its declared spelling. Declared:"
                    + " \(image.rows.keys.sorted().map(\.spelling).joined(separator: ", "))"
            )
        }

        let entry = image.linked[start]

        // A run starts from outside the link, and only a public declaration
        // is named from there.
        guard entry.access.reachesHost else {
            throw ExecutionError(
                "entry '\(entry.label)' is \(entry.access.rawValue), and a run starts"
                    + " only from a public declaration"
            )
        }

        // A run hands its entry values, and a parameter handed in place takes
        // a variable.
        if let parameter = entry.signature.inPlace {
            throw ExecutionError(
                "entry '\(entry.label)' takes '\(parameter)' in place, and a run hands"
                    + " its entry values"
            )
        }

        return try await Evaluator(image, observer: observer, environment: environment)
            .run(entry, arguments: arguments)
    }

    // MARK: - Private
}
