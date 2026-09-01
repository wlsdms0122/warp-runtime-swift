//
//  Place+Written.swift
//  WarpSyntax
//
//  Created by JSilver
//

import Foundation
import Warp

// A place in the words a document writes it with.
//
// `Place` carries a slot and a construct as themselves, because the language
// has no opinion about what a text calls them. This is the side that does: the
// keys are the readers' own, taken from where they are declared rather than
// spelled again here, and the word for a construct is asked of the registry —
// a notation may have respelled one, and then that is the word its author is
// looking at.
public extension Place {
    // The same address, walkable in the text. What a slot is written under
    // becomes a key; what a construct is written under becomes a landmark,
    // since a document may nest it under `value` or write it bare and both are
    // the same shape by the time anything here sees one.
    func written(by registry: ConstructRegistry) -> Place {
        var written: [Step] = []

        // Which construct the walk is inside, because one slot is not written
        // under one key: a branch holds its condition under `when` and a loop
        // under `where`, and the language calls both a condition.
        var construct: Construct?

        for step in steps {
            switch step {
            case let .slot(slot):
                written.append(.key(Self.key(of: slot, in: construct)))

            case let .construct(shape):
                construct = shape
                written.append(.landmark(Self.key(of: shape, by: registry)))

            default:
                written.append(step)
            }
        }

        return Place(written, in: document)
    }

    // MARK: - Private
    // The key a document writes a slot under, from the reader that reads it
    // there. A word spelled here as well would be the second of two places
    // deciding what a document says, and the two meet only in stored text.
    private static func key(of slot: Slot, in construct: Construct?) -> String {
        switch slot {
        case .procedures: ModuleReader.CodingKeys.procedures.stringValue
        case .constants: ModuleReader.CodingKeys.const.stringValue
        case .types: ModuleReader.CodingKeys.types.stringValue
        case .constraints: ModuleReader.CodingKeys.constraints.stringValue
        case .namespace: ModuleReader.CodingKeys.name.stringValue
        case .imports: ModuleReader.CodingKeys.imports.stringValue

        case .parameters: ProcedureReader.CodingKeys.parameters.stringValue
        case .returns: ProcedureReader.CodingKeys.returns.stringValue
        case .body: BlockReader.CodingKeys.body.stringValue
        case .result: BlockReader.CodingKeys.result.stringValue

        case .receiver: CallForm.CodingKeys.of.stringValue
        case .callee: CallForm.CodingKeys.procedure.stringValue
        case .arguments: CallForm.CodingKeys.arguments.stringValue

        // A closure is written wherever data is, so its key is the expression
        // grammar's rather than any form's.
        case .closure: ExpressionReader.closureKey

        case .then: BranchForm.CodingKeys.then.stringValue
        case .otherwise: BranchForm.CodingKeys.else.stringValue
        case .material: EachForm.CodingKeys.in.stringValue
        case .rescue: AttemptForm.CodingKeys.rescue.stringValue

        // The one slot two constructs write differently. Outside either — a
        // caller asking about a condition on its own — the branch's word is
        // the one a reader meets first.
        case .condition:
            if case .loop = construct {
                LoopForm.CodingKeys.where.stringValue
            } else {
                BranchForm.CodingKeys.when.stringValue
            }
        }
    }

    // The word this notation writes a shape under. Asked of the registry
    // because a caller registers the forms it likes under the spellings it
    // likes, and a shape whose word was given up has none to offer — the
    // language's own name stands in there, which is what a place said before
    // anybody asked a document.
    private static func key(of construct: Construct, by registry: ConstructRegistry) -> String {
        let form: any ConstructForm.Type = switch construct {
        case .literal, .reference, .array, .record, .closure, .cast: ValueForm.self
        case .invoke: InvokeForm.self
        case .block: GroupForm.self
        case .conditional: BranchForm.self
        case .loop: LoopForm.self
        case .iteration: EachForm.self
        case .attempt: AttemptForm.self
        case .dispatch: CallForm.self
        case let .leave(reach):
            switch reach {
            case .procedure: ReturnForm.self
            case .construct: BreakForm.self
            case .round: ContinueForm.self
            }
        }

        return registry.key(for: form) ?? construct.rendered
    }
}
