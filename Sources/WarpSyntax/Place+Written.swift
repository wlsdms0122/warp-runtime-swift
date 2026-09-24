//
//  Place+Written.swift
//  WarpSyntax
//
//  Created by JSilver
//

import Foundation
import Warp

// A place in the procedures a document writes it with.
//
// `Place` carries a slot and a construct as themselves, because the language
// has no opinion about what a text calls them. This is the side that does: the
// keys are the readers' own, taken from where they are declared rather than
// spelled again here, and the key for a construct is asked of the registry. A
// notation may have respelled one, and then that is the key its author is
// looking at.
//
// Every step answers on its own. A slot whose procedure depends on the construct
// holding it says which one, so nothing here reads the steps around it and
// there is no step this can be handed without an answer.
public extension Place {
    // The same address, walkable in the text. What a slot is written under
    // becomes a key; what a construct is written under becomes a landmark,
    // since a document may nest it under `value` or write it bare and both are
    // the same type by the time anything here sees one.
    func written(by registry: ConstructRegistry) -> Place {
        Place(
            steps.map { step in
                switch step {
                case let .part(part): .key(Self.key(of: part))
                case let .construct(construct): .landmark(Self.key(of: construct, by: registry))
                default: step
                }
            },
            in: document
        )
    }

    // MARK: - Private
    // The key a document writes a part under, from the reader that reads it
    // there. A procedure spelled here as well would be the second of two places
    // deciding what a document says, and the two meet only in stored text.
    private static func key(of part: Place.Part) -> String {
        switch part {
        case .procedures: ModuleReader.CodingKeys.procedures.stringValue
        case .constants: ModuleReader.CodingKeys.const.stringValue
        case .variables: ModuleReader.CodingKeys.variables.stringValue
        case .types: ModuleReader.CodingKeys.types.stringValue
        case .constraints: ModuleReader.CodingKeys.constraints.stringValue
        case .contracts: ModuleReader.CodingKeys.contracts.stringValue
        case .satisfies: ModuleReader.CodingKeys.satisfies.stringValue
        case .imports: ModuleReader.CodingKeys.imports.stringValue

        case .parameters: ProcedureReader.CodingKeys.parameters.stringValue
        case .returns: ProcedureReader.CodingKeys.returns.stringValue
        case .body: BlockReader.CodingKeys.body.stringValue
        case .result: BlockReader.CodingKeys.result.stringValue

        // What a cast reads is written under the expression grammar's subject
        // key.
        case .subject: ExpressionReader.subjectKey.spelling

        case .callee: CallForm.CodingKeys.procedure.stringValue
        case .arguments: CallForm.CodingKeys.arguments.stringValue

        // A closure is written wherever data is, so its key is the expression
        // grammar's rather than any form's.
        case .closure: ExpressionTag.closure.rawValue

        case .then: ConditionalForm.CodingKeys.then.stringValue
        case .otherwise: ConditionalForm.CodingKeys.else.stringValue
        case .rescue: AttemptForm.CodingKeys.rescue.stringValue

        // The one part two constructs write differently, which is why the part
        // says which one holds it. Answered by name and not by a default, so a
        // third construct that holds a condition arrives here as a compiler
        // error rather than as a procedure nobody chose.
        case let .condition(construct):
            switch construct {
            case .conditional: ConditionalForm.CodingKeys.when.stringValue
            case .loop: LoopForm.CodingKeys.while.stringValue
            }
        }
    }

    // The key this notation writes a type under. Asked of the registry
    // because a caller registers the forms it likes under the spellings it
    // likes, and a type whose key was given up has none to offer. The
    // language's own name stands in there, which is what a place said before
    // anybody asked a document.
    private static func key(of construct: Construct, by registry: ConstructRegistry) -> String {
        let form: (any ConstructForm.Type)? = switch construct {
        case .block: BlockForm.self
        case .conditional: ConditionalForm.self
        case .loop: LoopForm.self
        case .attempt: AttemptForm.self
        case .call: CallForm.self
        case let .leave(reach):
            switch reach {
            case .procedure: ReturnForm.self
            case .construct: BreakForm.self
            case .round: ContinueForm.self
            }
        case .literal, .reference, .array, .record, .closure, .cast: nil
        }

        guard let form else { return StatementReader.valueKey.spelling }

        return registry.key(for: form)?.spelling ?? construct.rendered
    }
}
