//
//  ConstructRegistry.swift
//  WarpSyntax
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp

// The keyword table: which key a document may write, and which form reads it.
// The language's constructs are anonymous, so this is the only place that
// admits they have names. A form's `key` is the spelling it proposes; the
// composer of the table has the last say, registering a form under another
// spelling or dropping a built-in one.
public struct ConstructRegistry: Sendable {
    // MARK: - Property
    public static let standard = ConstructRegistry(unchecked: [
        ConditionalForm.self,
        LoopForm.self,
        BlockForm.self,
        AttemptForm.self,
        ReturnForm.self,
        BreakForm.self,
        ContinueForm.self
    ])

    public var keys: [Name] { forms.keys.sorted() }

    private var forms: [Name: any ConstructForm.Type]

    // MARK: - Initializer
    public init(forms: [any ConstructForm.Type] = []) throws {
        self.forms = [:]

        for form in forms {
            try insert(form, as: form.key)
        }
    }

    // The same table keyed by the spellings a notation chose, for a notation
    // that is spelling most of it itself.
    public init(forms: [String: any ConstructForm.Type]) throws {
        self.forms = [:]

        // A key a construct is registered under is a key a document writes,
        // so it comes through the door every name a document writes does.
        for (written, form) in forms {
            do {
                try insert(form, as: try Name(written))
            } catch let refusal as NameRefused {
                throw ConstructRegistryError("construct key '\(written)' cannot be a name: \(refusal)")
            }
        }
    }

    // The language's own forms, each under the key it proposes. Nothing from
    // outside reaches this, so a key `insert` would refuse is a mistake in the
    // list `standard` writes, and the assertion is where it shows.
    private init(unchecked forms: [any ConstructForm.Type]) {
        assert((try? ConstructRegistry(forms: forms)) != nil, "the language's own forms register")

        self.forms = Dictionary(forms.map { form in (form.key, form) }) { first, _ in first }
    }

    // MARK: - Public
    // What the registered forms send. Dropping a form drops what it required,
    // which is the point of the table being a value.
    public func vocabulary(with notation: Notation) -> Set<Name> {
        forms.values.reduce(into: Set<Name>()) { procedures, form in
            procedures.formUnion(form.vocabulary(with: notation))
        }
    }

    // Passing a key spells this form differently in this notation. Registering
    // one form twice is an alias rather than a mistake. The table maps keys to
    // forms, and nothing says two keys cannot mean the same thing.
    public func registering(
        _ form: any ConstructForm.Type,
        as key: Name? = nil
    ) throws -> ConstructRegistry {
        var registry = self

        try registry.insert(form, as: key ?? form.key)

        return registry
    }

    // Giving up a key. A notation that wants `conditional` to mean something
    // of its own has to be able to stop meaning ours by it, so respelling a
    // built-in is this followed by `registering(_:as:)`: a rename is a change to
    // a table here, and not to the language.
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
    // A form registered under two keys is spelled with whichever sorts first.
    // An alias says the keys mean the same thing and not which one is meant,
    // so there is nothing here to prefer, and a table is unordered anyway,
    // which makes "the one registered first" a thing this cannot know. What
    // matters is that the answer is the same every time, since a document
    // written twice has to come out the same both times.
    //
    // Nothing where the form is not registered: a notation that gave up a key
    // cannot write what that key said, and answering with the built-in spelling
    // would put a key in the document that reading it back would refuse.
    public func key(for form: any ConstructForm.Type) -> Name? {
        forms.filter { _, registered in
            ObjectIdentifier(registered) == ObjectIdentifier(form)
        }
        .keys
        .min()
    }

    // MARK: - Private
    // A key is claimed once. Silently replacing a form would let a host swap
    // out the language's own control structures without a trace. Deliberately
    // replacing one is `removing(_:)` first, which leaves the intent written
    // down.
    private mutating func insert(_ form: any ConstructForm.Type, as key: Name) throws {
        guard forms[key] == nil else {
            throw ConstructRegistryError("construct key '\(key)' is already registered")
        }

        // `value` is the key a statement writes what it runs under, so a
        // construct registered under it would never be reached.
        guard key != StatementReader.valueKey else {
            throw ConstructRegistryError(
                "construct key '\(key)' is the key a statement writes its expression under,"
                    + " and no construct sits under it"
            )
        }

        // A tag is read as its expression wherever one stands, a statement's
        // `value` included, so a construct under a tag would take a record, a
        // reference or a call for itself.
        guard ExpressionTag(key) == nil else {
            throw ConstructRegistryError(
                "construct key '\(key)' is an expression's tag, and an expression is read under it"
            )
        }

        forms[key] = form
    }
}
