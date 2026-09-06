//
//  ConstructRegistry.swift
//  WarpSyntax
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp

// The keyword table: which word a document may write, and which form reads it.
// The language's constructs are anonymous, so this is the only place that
// admits they have names.
//
// A form's `key` is the spelling it proposes, not the one it gets. The table is
// what a notation *is*, so the composer of the table has the last word: the
// same form can be registered under another spelling, and a built-in spelling
// can be dropped. Otherwise a form type would be its own name forever, and two
// notations that wanted the same word could never both exist, which is a fact
// about a `static let`, not about the language.
public struct ConstructRegistry: Sendable {
    // MARK: - Property
    // The built-in set is a compile-time constant with unique keys. A throw
    // here would be a kernel bug, so the forced try is the honest reaction.
    public static let standard = try! ConstructRegistry(forms: [
        BranchForm.self,
        LoopForm.self,
        EachForm.self,
        GroupForm.self,
        AttemptForm.self,
        CallForm.self,
        InvokeForm.self,
        ReturnForm.self,
        BreakForm.self,
        ContinueForm.self
    ])

    public var keys: [Name] { forms.keys.sorted() }


    // What the registered forms send, and what their slots spend on their
    // behalf. Dropping a form drops what it required, which is the point of the
    // table being a value.
    //
    // The second half is added here rather than by each form. A form that reads
    // a condition says so and nothing else. What a condition costs is between
    // the notation and this table.
    public func vocabulary(with notation: Notation) -> Set<Name> {
        forms.values.reduce(into: Set<Name>()) { words, form in
            words.formUnion(form.vocabulary(with: notation))

            if form.readsCondition {
                words.formUnion(notation.conditionVocabulary)
            }
        }
    }

    private var forms: [Name: any ConstructForm.Type]

    // MARK: - Initializer
    public init(forms: [any ConstructForm.Type] = []) throws {
        self.forms = [:]

        for form in forms {
            try insert(form, as: form.key)
        }
    }

    // The same table written as words rather than forms, for a notation that is
    // spelling most of it itself.
    public init(forms: [String: any ConstructForm.Type]) throws {
        self.forms = [:]

        // A word a construct is registered under is a key a document writes,
        // so it comes through the door every name a document writes does.
        for (written, form) in forms {
            do {
                try insert(form, as: try Name(written))
            } catch let refusal as NameRefused {
                throw ValidationError("construct key '\(written)' cannot be a word: \(refusal)", at: nil)
            }
        }
    }

    // MARK: - Public
    // Passing a key spells this form differently in this notation. Registering
    // one form twice is an alias rather than a mistake. The table maps words to
    // forms, and nothing says two words cannot mean the same thing.
    public func registering(
        _ form: any ConstructForm.Type,
        as key: Name? = nil
    ) throws -> ConstructRegistry {
        var registry = self

        try registry.insert(form, as: key ?? form.key)

        return registry
    }

    // Giving up a word. A notation that wants `branch` to mean something of its
    // own has to be able to stop meaning ours by it, and respelling a built-in
    // is this followed by `registering(_:as:)`. The reason a rename is a change
    // to a table here rather than a change to the language.
    public func removing(_ key: Name) -> ConstructRegistry {
        var registry = self

        registry.forms[key] = nil

        return registry
    }

    public func form(for key: Name) -> (any ConstructForm.Type)? {
        forms[key]
    }

    // The table read backwards, for writing a document rather than reading one.
    //
    // A form registered under two words is spelled with whichever sorts first.
    // An alias says the words mean the same thing and not which one is meant,
    // so there is nothing here to prefer, and a table is unordered anyway,
    // which makes "the one registered first" a thing this cannot know. What
    // matters is that the answer is the same every time, since a document
    // written twice has to come out the same both times.
    //
    // Nothing where the form is not registered: a notation that gave up a word
    // cannot write what that word said, and answering with the built-in spelling
    // would put a key in the document that reading it back would refuse.
    public func key(for form: any ConstructForm.Type) -> Name? {
        forms.filter { _, registered in
            ObjectIdentifier(registered) == ObjectIdentifier(form)
        }
        .keys
        .min()
    }

    // MARK: - Private
    // A key is claimed once. Silently replacing a form would let a caller swap
    // out the language's own control structures without a trace. Deliberately
    // replacing one is `removing(_:)` first, which leaves the intent written
    // down.
    private mutating func insert(_ form: any ConstructForm.Type, as key: Name) throws {
        guard forms[key] == nil else {
            // A registry is assembled by a caller and not read out of a
            // document, so there is no place in one to point at.
            throw ValidationError("construct key '\(key)' is already registered", at: nil)
        }

        // `value` is the word an expression quotes a literal under, read
        // wherever an expression is, so a construct registered under it would
        // never be reached: the statement reader passes that word by.
        guard key != StatementReader.valueKey else {
            throw ValidationError(
                "construct key '\(key)' is the word a statement writes its expression under,"
                    + " and no construct sits under it",
                at: nil
            )
        }

        forms[key] = form
    }
}
