//
//  Place+Written.swift
//  WarpSyntax
//
//  Created by JSilver on 9/1/26.
//

import Foundation
import Warp

// A place in the keys a document writes it with.
//
// `Place` carries a part, a construct and a statement as themselves, because
// the language has no opinion about what a document calls them. This is the
// side that does: the keys are the readers' own, taken from where they are
// declared rather than spelled again here.
//
// Every step gives its keys on its own. A part whose key depends on the
// construct holding it says which one, so nothing here reads the steps around
// it and there is no step this can be handed without a key to give.
public extension Place {
    // The place as `CHECKING.md` names it: the document's identity and its
    // steps from the root, each a key the document writes, a string, or a
    // position in a list it writes, an int. Nil for a place that is no spot
    // in a document: one with no identity, or one holding a body a host
    // assembled, which no document writes.
    //
    //     [<the identity's bytes>, ["procedures", "App.g", "body", 2, "value", "call", "arguments", 0]]
    var value: Value? {
        guard let identity = document.identity else { return nil }

        var keys: [Value] = []

        for step in written().steps {
            switch step {
            case let .key(key): keys.append(.string(key))
            case let .index(position): keys.append(.int(position))
            case .part, .construct, .statement, .landmark: return nil
            }
        }

        return [.bytes(identity.bytes), .array(keys)]
    }
}

extension Place {
    // The same address, walkable in the document. What a part is written under
    // becomes its keys, a statement its position in the body, and the
    // construct a statement writes the `value` it stands under, then the key
    // of the construct where it is one of the seven. An expression's own key
    // comes with its part, since it is written there wherever the expression
    // stands. A landmark names a body a host assembled, which no document
    // writes, and stays one.
    func written() -> Place {
        Place(
            steps.flatMap { step -> [Place.Step] in
                switch step {
                case let .part(part): Self.keys(of: part)
                case let .construct(construct): Self.keys(of: construct)
                case let .statement(_, position): [.index(position)]
                case .key, .index, .landmark: [step]
                }
            },
            in: document
        )
    }

    // The keys a document writes a part under, from the reader that reads it
    // there. A key spelled here as well would be the second of two places
    // deciding what a document says, and the two meet only in stored text.
    private static func keys(of part: Place.Part) -> [Place.Step] {
        switch part {
        case .procedures: [.key(ModuleReader.CodingKeys.procedures.stringValue)]
        case .constants: [.key(ModuleReader.CodingKeys.const.stringValue)]
        case .variables: [.key(ModuleReader.CodingKeys.variables.stringValue)]
        case .types: [.key(ModuleReader.CodingKeys.types.stringValue)]
        case .contracts: [.key(ModuleReader.CodingKeys.contracts.stringValue)]
        case .satisfies: [.key(ExtensionReader.CodingKeys.satisfies.stringValue)]
        case .extensions: [.key(ModuleReader.CodingKeys.extensions.stringValue)]
        case .imports: [.key(ModuleReader.CodingKeys.imports.stringValue)]

        case .parameters: [.key(SignatureFieldsReader.CodingKeys.parameters.stringValue)]
        case .returns: [.key(SignatureFieldsReader.CodingKeys.returns.stringValue)]
        case .bounds: [.key(SignatureFieldsReader.CodingKeys.bounds.stringValue)]
        case .sameTypes: [.key(SignatureFieldsReader.CodingKeys.sameTypes.stringValue)]
        case .body: [.key(ProcedureReader.CodingKeys.body.stringValue)]


        // A cast's subject stands inside the cast's own mapping, under the tag
        // that says how the cast reads a mismatch.
        case let .subject(optional):
            [
                .key((optional ? ExpressionTag.optionalCast : ExpressionTag.cast).rawValue),
                .key(ExpressionReader.subjectKey.spelling)
            ]

        case .fields: [.key(ExpressionTag.struct.rawValue)]
        case .typeParameters: [.key(TypeDeclarationReader.typeParametersKey.spelling)]
        case .entries: [.key(ExpressionTag.dictionary.rawValue)]

        // A call's parts stand inside the call's own mapping, wherever the
        // call is written.
        case .callee: [.key(ExpressionTag.call.rawValue), .key(CallForm.CodingKeys.procedure.stringValue)]
        case .arguments: [.key(ExpressionTag.call.rawValue), .key(CallForm.CodingKeys.arguments.stringValue)]

        // A closure is written wherever data is, so its key is the expression
        // grammar's rather than any form's.
        case .closure: [.key(ExpressionTag.closure.rawValue)]

        case .then: [.key(ConditionalForm.CodingKeys.then.stringValue)]
        case .otherwise: [.key(ConditionalForm.CodingKeys.else.stringValue)]
        case .catch: [.key(TryForm.CodingKeys.catch.stringValue)]
        case .unwrapped: [.key(UnwrapForm.CodingKeys.of.stringValue)]

        // The one part two constructs write differently, which is why the part
        // says which one holds it. Matched by name and not by a default, so a
        // third construct that holds a condition arrives here as a compiler
        // error rather than as a key nobody chose.
        case let .condition(construct):
            switch construct {
            case .conditional: [.key(ConditionalForm.CodingKeys.when.stringValue)]
            case .loop: [.key(LoopForm.CodingKeys.while.stringValue)]
            }
        }
    }

    // The keys a statement writes its construct under: `value`, and inside it
    // the key of one of the seven. Any other expression stands under `value`
    // as it would anywhere else.
    private static func keys(of construct: Construct) -> [Place.Step] {
        let value = Place.Step.key(StatementReader.valueKey.spelling)

        return switch construct {
        case .literal, .reference, .array, .struct, .dictionary, .closure, .cast, .call: [value]
        case .conditional: [value, .key(ConditionalForm.key.spelling)]
        case .loop: [value, .key(LoopForm.key.spelling)]
        case .try: [value, .key(TryForm.key.spelling)]
        case .unwrap: [value, .key(UnwrapForm.key.spelling)]
        case .leave(.procedure): [value, .key(ReturnForm.key.spelling)]
        case .leave(.loop): [value, .key(BreakForm.key.spelling)]
        case .leave(.round): [value, .key(ContinueForm.key.spelling)]
        }
    }
}
