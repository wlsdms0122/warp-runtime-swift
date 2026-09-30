//
//  FailurePayload.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// The type the sentence above promises, said once as a type so the link can
// hold the rescue's name to it.
//
// The envelope is the whole declaration: `type` and `message` are what every
// failure holds, and `details` is the box the failing procedure fills. Declaring
// the box as a dictionary of `any` is what lets a rescue reach what a failure
// carried by naming it, without the type of the box being part of what a
// runtime must implement.
public enum FailurePayload {
    // MARK: - Property
    public static let declared = TypeExpression.record([
        "type": .string,
        "message": .string,
        "details": .dictionary(.any)
    ])

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
