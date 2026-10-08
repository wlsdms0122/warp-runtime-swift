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
// `Place` carries a slot and a construct as themselves, because the language
// has no opinion about what a text calls them. This is the side that does: the
// keys are the readers' own, taken from where they are declared rather than
// spelled again here, and the key for a construct is asked of the registry. A
// notation may have respelled one, and then that is the key its author is
// looking at.
//
// Every step answers on its own. A slot whose key depends on the construct
// holding it says which one, so nothing here reads the steps around it and
// there is no step this can be handed without an answer.
public extension Place {
    // The same address, walkable in the text. What a slot is written under
    // becomes a key; what a construct is written under becomes a landmark,
    // since a document may nest it under `value` or write it bare and both are
    // the same type by the time anything here sees one.
    func written(by registry: ConstructRegistry) -> Place {
        Place(
            steps.flatMap { step -> [Place.Step] in
                switch step {
                case let .part(part): Self.keys(of: part)
                case let .construct(construct): [.landmark(Self.key(of: construct, by: registry))]
                default: [step]
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
        case .satisfies: [.key(ModuleReader.CodingKeys.satisfies.stringValue)]
        case .imports: [.key(ModuleReader.CodingKeys.imports.stringValue)]

        case .parameters: [.key(ProcedureReader.CodingKeys.parameters.stringValue)]
        case .returns: [.key(ProcedureReader.CodingKeys.returns.stringValue)]
        case .body: [.key(BlockReader.CodingKeys.body.stringValue)]
        case .result: [.key(BlockReader.CodingKeys.result.stringValue)]

        // A cast's subject stands inside the cast's own mapping, under the tag
        // that says how the cast reads a mismatch.
        case let .subject(optional):
            [
                .key((optional ? ExpressionTag.optionalCast : ExpressionTag.cast).rawValue),
                .key(ExpressionReader.subjectKey.spelling)
            ]

        case .fields: [.key(ExpressionTag.record.rawValue)]

        case .callee: [.key(CallForm.CodingKeys.procedure.stringValue)]
        case .arguments: [.key(CallForm.CodingKeys.arguments.stringValue)]

        // A closure is written wherever data is, so its key is the expression
        // grammar's rather than any form's.
        case .closure: [.key(ExpressionTag.closure.rawValue)]

        case .then: [.key(ConditionalForm.CodingKeys.then.stringValue)]
        case .otherwise: [.key(ConditionalForm.CodingKeys.else.stringValue)]
        case .rescue: [.key(AttemptForm.CodingKeys.rescue.stringValue)]

        // The one part two constructs write differently, which is why the part
        // says which one holds it. Answered by name and not by a default, so a
        // third construct that holds a condition arrives here as a compiler
        // error rather than as a key nobody chose.
        case let .condition(construct):
            switch construct {
            case .conditional: [.key(ConditionalForm.CodingKeys.when.stringValue)]
            case .loop: [.key(LoopForm.CodingKeys.while.stringValue)]
            }
        }
    }

    // The key this notation writes a type under. Asked of the registry
    // because a host registers the forms it likes under the spellings it
    // likes, and a type whose key was given up has none to offer. The
    // language's own name stands in there, which is what a place said before
    // anybody asked a document.
    private static func key(of construct: Construct, by registry: ConstructRegistry) -> String {
        let form: any ConstructForm.Type

        switch construct {
        // A call is a tag, and every table reads it under that one key.
        case .call: return ExpressionTag.call.rawValue
        case .literal, .reference, .array, .record, .closure, .cast: return StatementReader.valueKey.spelling
        case .block: form = BlockForm.self
        case .conditional: form = ConditionalForm.self
        case .loop: form = LoopForm.self
        case .attempt: form = AttemptForm.self
        case .leave(.procedure): form = ReturnForm.self
        case .leave(.construct): form = BreakForm.self
        case .leave(.round): form = ContinueForm.self
        }

        return registry.key(for: form)?.spelling ?? construct.rendered
    }
}
