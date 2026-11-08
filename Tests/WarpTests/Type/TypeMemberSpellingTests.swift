//
//  TypeMemberSpellingTests.swift
//  WarpTests
//
//  Created by JSilver on 11/2/26.
//

import Foundation
import Testing
@testable import Warp

// A type member's spelling named by a declaration, which the table reads
// while it is being made. A program's slots and casts name one after the
// table is made, which the specification's cases reach.
@Suite("A type member's spelling a declaration names")
struct TypeMemberSpellingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("an alias and a field naming a type member's spelling read as the type it gives, through another alias")
    func aDeclarationNamingASpellingReadsThrough() throws {
        // Given. `App.Count` an alias of `App.Box.Item`, `App.Pair` one of
        // `App.Wrapper<App.Count>.Item`, which reads `App.Count` first, and
        // `App.Holder` a field of `App.Pair`
        let sut = TypeTable(
            types: [
                "App.Box": .struct(["item": .int]),
                "App.Wrapper": .struct(["item": .parameter(name: "T")], typeParameters: ["T"]),
                "App.Count": .alias(.named("App.Box.Item")),
                "App.Pair": .alias(.typeMember(.named("App.Wrapper", arguments: [.named("App.Count")]), name: "Item")),
                "App.Holder": .struct(["value": .named("App.Pair")])
            ],
            typeMembers: [
                TypeMember(head: Head("App.Box"), name: "Item", type: .int),
                TypeMember(head: Head("App.Wrapper"), name: "Item", type: .parameter(name: "T"))
            ],
            of: Linkage()
        )

        // When
        let count = TypeExpression.named("App.Count").lowered(in: sut.loweredTypes)
        let pair = TypeExpression.named("App.Pair").lowered(in: sut.loweredTypes)
        let field = sut.loweredTypes.layout(named: "App.Holder")?["value"]

        // Then
        #expect(count == .int)
        #expect(pair == .int)
        #expect(field == .int)
    }

    @Test("a type member whose type names another type member's spelling reads as the type that one gives")
    func aSpellingReadsThroughAnotherSpelling() {
        // Given. `App.Box.Item` is `App.Wrapper<String>.Item`, `App.Pair.Item`
        // is `App.Box.Item` written alone, and `App.Holder` a field of
        // `App.Pair.Item`
        let sut = TypeTable(
            types: [
                "App.Box": .struct(["item": .int]),
                "App.Pair": .struct(["item": .int]),
                "App.Wrapper": .struct(["item": .parameter(name: "T")], typeParameters: ["T"]),
                "App.Holder": .struct(["value": .named("App.Pair.Item")])
            ],
            typeMembers: [
                TypeMember(
                    head: Head("App.Box"),
                    name: "Item",
                    type: .typeMember(.named("App.Wrapper", arguments: [.string]), name: "Item")
                ),
                TypeMember(head: Head("App.Pair"), name: "Item", type: .named("App.Box.Item")),
                TypeMember(head: Head("App.Wrapper"), name: "Item", type: .parameter(name: "T"))
            ],
            of: Linkage()
        )

        // When
        let box = TypeExpression.named("App.Box.Item").lowered(in: sut.loweredTypes)
        let pair = TypeExpression.named("App.Pair.Item").lowered(in: sut.loweredTypes)
        let field = sut.loweredTypes.layout(named: "App.Holder")?["value"]

        // Then
        #expect(box == .string)
        #expect(pair == .string)
        #expect(field == .string)
    }

    @Test("a type member read under a head that does not take the type stands for no type")
    func aReadingTheHeadDoesNotTakeIsNoType() {
        // Given. `App.Wrapper` given `Item` under `App.Wrapper<Int>` alone
        let sut = TypeTable(
            types: ["App.Wrapper": .struct(["item": .parameter(name: "T")], typeParameters: ["T"])],
            typeMembers: [TypeMember(head: Head("App.Wrapper", arguments: [.int]), name: "Item", type: .string)],
            of: Linkage()
        )

        // When
        let taken = TypeExpression.typeMember(.named("App.Wrapper", arguments: [.int]), name: "Item")
            .lowered(in: sut.loweredTypes)
        let untaken = TypeExpression.typeMember(.named("App.Wrapper", arguments: [.string]), name: "Item")
            .lowered(in: sut.loweredTypes)

        // Then
        #expect(taken == .string)
        #expect(untaken == .never)
    }

    @Test("a type member under a bounded head reads through in a table holding no claim")
    func aBoundedHeadIsReadWithoutClaims() {
        // Given. `App.Wrapper` given `Item` under `App.Wrapper<some T: App.Marked>`,
        // `App.Y` an alias of `App.Wrapper<Int>.Item`, and no claim that Int
        // conforms to `App.Marked`, which is the build's to judge
        let sut = TypeTable(
            types: [
                "App.Wrapper": .struct(["item": .parameter(name: "T")], typeParameters: ["T"]),
                "App.Y": .alias(.typeMember(.named("App.Wrapper", arguments: [.int]), name: "Item")),
                "App.Holder": .struct(["value": .named("App.Y")])
            ],
            contracts: ["App.Marked": [:]],
            typeMembers: [
                TypeMember(
                    head: Head("App.Wrapper", arguments: [.parameter(name: "T")], bounds: ["T": ["App.Marked"]]),
                    name: "Item",
                    type: .parameter(name: "T")
                )
            ],
            of: Linkage()
        )

        // When
        let alias = TypeExpression.named("App.Y").lowered(in: sut.loweredTypes)
        let field = sut.loweredTypes.layout(named: "App.Holder")?["value"]

        // Then
        #expect(alias == .int)
        #expect(field == .int)
    }

    @Test("a type member whose head names a type member's spelling is read once the head reads through")
    func aHeadNamingASpellingReadsThrough() {
        // Given. `App.Wrapper` given `X` under `App.Wrapper<App.Box.Item>`,
        // which is `App.Wrapper<Int>`, `App.Y` an alias of
        // `App.Wrapper<Int>.X`, and `App.Holder` a field of the same
        let sut = TypeTable(
            types: [
                "App.Box": .struct(["item": .int]),
                "App.Wrapper": .struct(["item": .parameter(name: "T")], typeParameters: ["T"]),
                "App.Y": .alias(.typeMember(.named("App.Wrapper", arguments: [.int]), name: "X")),
                "App.Holder": .struct(["value": .typeMember(.named("App.Wrapper", arguments: [.int]), name: "X")])
            ],
            typeMembers: [
                TypeMember(head: Head("App.Box"), name: "Item", type: .int),
                TypeMember(head: Head("App.Wrapper", arguments: [.named("App.Box.Item")]), name: "X", type: .string)
            ],
            of: Linkage()
        )

        // When
        let alias = TypeExpression.named("App.Y").lowered(in: sut.loweredTypes)
        let field = sut.loweredTypes.layout(named: "App.Holder")?["value"]

        // Then
        #expect(alias == .string)
        #expect(field == .string)
    }

    @Test("a type member's spelling under a type the language names reads as the type it gives")
    func aLanguageTypesSpellingReadsThrough() {
        // Given. `Int` given `Kind`, a `String`
        let sut = TypeTable(
            types: [:],
            typeMembers: [TypeMember(head: Head("Int"), name: "Kind", type: .string)],
            of: Linkage()
        )

        // When
        let spelled = sut.loweredTypes.typeMember(spelled: "Int.Kind")
        let lowered = TypeExpression.named("Int.Kind").lowered(in: sut.loweredTypes)

        // Then
        #expect(spelled == .typeMember(.int, name: "Kind"))
        #expect(lowered == .string)
    }

    // MARK: - Public
    // MARK: - Private
}
