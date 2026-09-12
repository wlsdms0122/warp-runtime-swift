//
//  CallForm.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// Calling a procedure by name.
//
// A call names a symbol, never a document. Naming the document would write a
// linkage fact into the call site; which module declared it is the builder's
// business.
//
// It is a construct key rather than the bare name a native procedure is written
// under, because a construct key is read at decode time and a procedure's name
// is not in the registry then. It is not known until the link. A name only
// known after linking cannot be a construct key, and this procedure is what that
// costs.
//
// A body a procedure is to run travels as a closure argument like any other value. A
// call carries no body of its own kind. One channel, one rule: what crosses
// into a procedure is isolated.
public struct CallForm: ConstructForm {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case procedure
        case of
        case arguments
    }

    // MARK: - Property
    public static let key: Name = "call"

    private let procedure: Name
    private let receiver: Expression?
    private let arguments: [Name: Expression]

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "call")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.procedure = try Name.read(
            try container.decode(String.self, forKey: .procedure),
            at: decoder.steps
        )
        self.receiver = try container.decodeIfPresent(ExpressionReader.self, forKey: .of)?
            .expression
        self.arguments = try container.decodeIfPresent(
            [String: ExpressionReader].self,
            forKey: .arguments
        )?
        .mapValues(\.expression)
        .named(at: decoder.steps) ?? [:]
    }

    // MARK: - Public
    public func expression(boundTo id: String?) -> Expression {
        .call(
            Call(
                receiver: receiver,
                selector: procedure,
                arguments: arguments
            )
        )
    }

    // MARK: - Private
}
