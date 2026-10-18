//
//  TypingContext.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What the type check needs beyond the body it is reading: what every declaration in
// the link answers with, and what every name in it stands for.
//
// One value rather than two arguments threaded through every walk, because they
// are one fact (the build's answer to "what does this name mean") read from two
// sides.
struct TypingContext: Sendable {
    // MARK: - Property
    // The declared types as the documents wrote them, for the surfaces a
    // document's own spelling is owed to.
    let types: TypeTable

    // The rows the build laid, and which row each declared spelling stands
    // on. What a declaration takes and answers is read off its row: the row
    // is the declaration lowered, and a second table of the same facts would
    // hash every declared name to say what the row already says.
    let linked: [Linked]
    let rows: [Name: Int]

    // The declarations of the document being read, by row, private ones
    // included. Read before the link's spellings.
    let own: [Name: Int]

    // The spellings only another document's private declarations wear.
    let concealed: Set<Name>

    // The same declarations as the run reads them, lowered once. Every
    // judgement the walk asks goes here, so the walk and the run judge by one
    // table and by one language.
    var loweredTypes: LoweredTypeTable { types.loweredTypes }

    // Every contract's procedures, under the spelling a call writes to reach one.
    // Beside the symbols rather than in them: a name here answers with no
    // declaration, and which declaration runs is the first argument's to say.
    let contractProcedures: [Name: LoweredContractProcedure]

    // The variables of the document being read, by name. A body reading one
    // answers by the run's state, so constness is read against these.
    let variables: Set<Name>

    // What the procedure being read holds its type parameters to. A closure
    // written in its body reads the same names, so a `some T` inside is the
    // `T` the caller filled, bound the way the declaration bound it.
    var bounds: [Name: Set<Name>] = [:]

    // The associated types of its type parameters it says are a type, and
    // each one it names as the procedure reads it, by label: what one a call
    // fills from one of its parameters reads as here.
    var sameTypes: [Name: TypeExpression] = [:]
    var associatedTypes: [Name: LoweredType] = [:]

    // MARK: - Initializer
    // MARK: - Public
    // The same context, reading the body of a procedure declared this way.
    func reading(_ signature: Signature) -> TypingContext {
        var held = self
        held.bounds = signature.bounds
        held.sameTypes = signature.sameTypes
        held.associatedTypes = signature.loweredAssociatedTypes(in: loweredTypes)

        return held
    }

    // What a call is written against: the whole signature rather than what it
    // answers, because a declaration with a type parameter in it does not
    // answer anything until a call site fills it, and what fills it is read
    // from the arguments. A contract's procedure answers with what the
    // contract wrote.
    func signature(of selector: Name) -> Signature? {
        declared(selector)?.signature ?? contractProcedures[selector]?.signature
    }

    // The row a selector names.
    func declared(_ selector: Name) -> Linked? {
        row(of: selector).map { row in linked[row] }
    }

    // What a selector takes: the slots of the row it stands on, or the ones a
    // contract lowered for its procedure, which stands on no row.
    func slots(of selector: Name) -> [Slot] {
        declared(selector)?.slots ?? contractProcedures[selector]?.slots ?? []
    }

    // What it answers, as the declaration wrote it.
    func answer(of selector: Name) -> LoweredType? {
        declared(selector)?.returns ?? contractProcedures[selector]?.answers
    }

    // The type written for the value this reads, and nil where nothing was
    // written. A closure literal writes its signature, a cast the type it
    // names, a call the answer its callee declares and a call of a value the
    // answer the value's written type says, and the value is held to that
    // type where it is made, cast or answered. A path follows the type
    // written for its head, which `given` says, past it: brackets read an
    // element of a list or an entry of a map, and a dot reads a field a
    // struct type declares. A list or a map of them says it about every
    // element or entry, and the value was judged against that type when it
    // was handed over, so what the type says of the part is what the slot
    // said.
    func declaredType(of expression: Expression, given declared: (Name) -> LoweredType?) -> LoweredType? {
        switch expression {
        case let .closure(procedure):
            return procedure.signature.procedureType.lowered(in: loweredTypes)

        case let .cast(_, type, optional):
            let named = type.lowered(in: loweredTypes)

            return optional ? .nullable(named) : named

        case let .call(call):
            return signature(of: call.selector).map { signature in
                signature.returns.lowered(in: loweredTypes, bounds: signature.bounds, sameTypes: signature.sameTypes)
            }

        case let .apply(callee, _):
            return declaredType(of: callee, given: declared)?.procedureReturns

        default:
            break
        }

        guard case let .reference(path) = expression, let head = path.head else { return nil }

        return path.segments.dropFirst().reduce(declared(head)) { reached, segment in
            switch segment {
            case .index, .indexRef:
                return reached?.element

            case let .name(name, _):
                return reached?.dotted(name, in: loweredTypes)
            }
        }
    }

    // The type written for what the name a statement binds holds. A name
    // that wrote its type holds that. A fixed name that wrote none holds the
    // one written for the value it is bound to. A variable that wrote none
    // holds whatever its writes leave, which nothing wrote, so it holds none.
    func declaredType(
        of binding: Statement.Binding,
        reading expression: Expression,
        given declared: (Name) -> LoweredType?
    ) -> LoweredType? {
        switch binding {
        case let .constant(_, written):
            return written?.lowered(in: loweredTypes) ?? declaredType(of: expression, given: declared)

        case let .variable(_, written):
            return written?.lowered(in: loweredTypes)

        case .assignment:
            return nil
        }
    }

    // A named type stands for what it was declared as. The type check walks into
    // types, so it has to look through a name to find one. The table lowered
    // every declaration once, so following a name is reading a row.
    func resolve(_ type: LoweredType) -> LoweredType {
        guard case let .named(row, arguments) = type else { return type }

        return resolve(loweredTypes.declared(row, applied: arguments))
    }

    // MARK: - Private
    // The document's own declaration first, then the link's spelling.
    private func row(of selector: Name) -> Int? {
        own[selector] ?? rows[selector]
    }
}
