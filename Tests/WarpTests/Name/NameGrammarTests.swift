//
//  NameGrammarTests.swift
//  WarpTests
//
//  Created by JSilver on 10/9/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A name holds the grammar of where it is written")
struct NameGrammarTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a type's name is identifiers joined by dots, and no word the language writes", arguments: [
        ("Account", true), ("Bank.Account", true), ("_x1", true), ("Int.Range", true), ("Bank.null", true),
        ("true", false), ("", false), ("a..b", false), ("foo-bar", false), ("café", false), ("a b", false),
        ("Int", false), ("Array", false), ("Optional", false), ("Self", false), ("Some", false), ("some", false),
        ("const", false), ("isolated", false), ("inout", false), ("var", false)
    ])
    func aTypeNameIsIdentifiersJoinedByDots(name: String, holds: Bool) {
        // When / Then
        #expect(((try? Name(name)).map(NameGrammar.type.holds) ?? false) == holds)
    }

    @Test("a mention is a type's name or a name the language declares, save the marker", arguments: [
        ("Bank.Account", true), ("Failure", true), ("Round", true), ("Hashable", true),
        ("Some", false), ("Optional", false), ("Int", false)
    ])
    func aMentionIsNoMarker(name: String, holds: Bool) {
        // When / Then
        #expect(((try? Name(name)).map(NameGrammar.mention.holds) ?? false) == holds)
    }

    @Test("a struct's name is a type's name or any name the language declares", arguments: [
        ("Bank.Account", true), ("Failure", true), ("Round", true), ("Some", true),
        ("Optional", false), ("Int", false), ("a b", false)
    ])
    func aStructNameMayBeTheMarker(name: String, holds: Bool) {
        // When / Then
        #expect(((try? Name(name)).map(NameGrammar.structName.holds) ?? false) == holds)
    }

    @Test("a contract a bound or a claim names is a type's name or the contract the language declares", arguments: [
        ("Describable", true), ("Bank.Describable", true), ("Hashable", true),
        ("Failure", false), ("Round", false), ("Int", false), ("Any", false), ("some", false)
    ])
    func aContractMentionIsATypeNameOrHashable(name: String, holds: Bool) {
        // When / Then
        #expect(((try? Name(name)).map(NameGrammar.contractMention.holds) ?? false) == holds)
    }

    @Test("the type a claim is about is a mention or a type the language names a value an instance of", arguments: [
        ("Bank.Account", true), ("Failure", true), ("Round", true), ("Hashable", true), ("Int", true),
        ("Null", true), ("Array", true), ("Dictionary", true), ("Optional", true),
        ("Any", false), ("Never", false), ("Procedure", false), ("Self", false), ("Some", false), ("Array<Int>", false)
    ])
    func aClaimedTypeIsAMentionOrANominalType(name: String, holds: Bool) {
        // When / Then
        #expect(((try? Name(name)).map(NameGrammar.claimedType.holds) ?? false) == holds)
    }

    @Test("a type parameter's name is one identifier, and no word the language writes", arguments: [
        ("T", true), ("Element", true), ("_x1", true),
        ("A.B", false), ("a b", false), ("Self", false), ("Int", false), ("Any", false), ("some", false),
        ("null", false)
    ])
    func aTypeParameterNameIsOneIdentifier(name: String, holds: Bool) {
        // When / Then
        #expect(((try? Name(name)).map(NameGrammar.typeParameter.holds) ?? false) == holds)
    }

    @Test("a value's name is one a path reads back as its key", arguments: [
        ("total", true), ("a b", true), ("café", true), ("x-y", true), ("Int", true),
        ("a.b", false), ("a[0]", false), ("a]", false), ("a?", false), (" a", false), ("a ", false),
        ("a\n", false), ("\ra", false)
    ])
    func aValueNameIsAPathKey(name: String, holds: Bool) {
        // When / Then
        #expect(((try? Name(name)).map(NameGrammar.value.holds) ?? false) == holds)
    }

    @Test("a contract's procedure is named by one identifier", arguments: [
        ("describe", true), ("_x1", true), ("Int", true),
        ("a.b", false), ("a b", false), ("café", false), ("", false)
    ])
    func aContractProcedureNameIsOneIdentifier(name: String, holds: Bool) {
        // When / Then
        #expect(((try? Name(name)).map(NameGrammar.contractProcedure.holds) ?? false) == holds)
    }

    // MARK: - Public
    // MARK: - Private
}
