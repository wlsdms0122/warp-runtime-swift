//
//  LoweredEnumTests.swift
//  WarpTests
//
//  Created by JSilver on 11/1/26.
//

import Foundation
import Testing
@testable import Warp

// An enum stays a row, its cases laid out under their spellings, and the
// table reads a value under a case's spelling as a value of the enum.
@Suite("An enum lowers to a row its cases' values read as")
struct LoweredEnumTests {
    // MARK: - Property
    private let types = TypeTable(
        types: [
            "App.Target": .enum(["local": [:], "remote": ["host": .string, "port": .int]]),
            "App.Result": .enum(
                ["ok": ["value": .parameter(name: "T")], "failed": ["error": .parameter(name: "E")]],
                typeParameters: ["T", "E"]
            ),
            "App.Goal": .alias(.named("App.Target")),
            "App.Point": .struct(["x": .int])
        ],
        of: Linkage()
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a case's spelling reads as its enum's row, and an alias gives the cases no second spelling")
    func aCaseSpellingReadsAsItsEnum() throws {
        // Given
        let table = types.loweredTypes
        let target = try #require(table.row(named: "App.Target"))
        let goal = try #require(table.row(named: "App.Goal"))

        // When / Then. The enum stays a row, and its alias stands for it
        #expect(table.declaresNominal(target))
        #expect(table.mention(of: goal) == .named(target))
        #expect(table.structRow(named: "App.Target.remote") == target)
        #expect(table.structRow(named: "App.Goal.remote") == nil)
        #expect(table.declaresCase("App.Target.local"))
        #expect(!table.declaresCase("App.Target"))
        #expect(!table.declaresCase("App.Goal.local"))
        #expect(table.layout(named: "App.Target.remote")?.names == ["host", "port"])
    }

    @Test("a value of a case reads as its enum, applied to what its fields read, and to Never where none does")
    func aCaseValueReadsAsItsEnumApplied() throws {
        // Given
        let table = types.loweredTypes
        let result = try #require(table.row(named: "App.Result"))
        let value = Value.struct(Struct(name: "App.Result.ok", ["value": .int(1)]))

        // When
        let read = LoweredType(of: value, in: table)

        // Then
        #expect(read == .named(result, arguments: [.int, .never]))
        #expect(read.nominal(in: table) == "App.Result")
    }

    @Test("a mention applying an enum applies every case")
    func aMentionAppliesEveryCase() throws {
        // Given
        let table = types.loweredTypes
        let result = try #require(table.row(named: "App.Result"))

        // When
        let applied = table.declared(result, applied: [.int, .string])

        // Then
        guard case let .enum(held) = applied else {
            Issue.record("App.Result applied reads \(applied)")

            return
        }

        #expect(held[case: "ok"]?["value"] == .int)
        #expect(held[case: "failed"]?["error"] == .string)
        #expect(held[case: "ok"]?.name == "App.Result.ok")
    }

    @Test("an enum slot holds a value under one of its cases' spellings, and no other struct, a dot reaching nothing")
    func anEnumSlotHoldsItsCases() throws {
        // Given
        let table = types.loweredTypes
        let target = LoweredType.named(try #require(table.row(named: "App.Target")))
        let remote = Value.struct(Struct(name: "App.Target.remote", ["host": .string("a"), "port": .int(1)]))
        let point = Value.struct(Struct(name: "App.Point", ["x": .int(1)]))

        // When
        let settled = try target.settling(remote, at: "target", in: table)

        // Then
        #expect(settled == remote)
        #expect(throws: DoorRefused.self) {
            try target.settling(point, at: "target", in: table)
        }
        #expect(target.dotted("port", in: table) == nil)
        #expect(target.element == nil)
    }

    @Test("a case from outside is refused by the case for a field it lacks, and a spelling no enum declares by its name")
    func aCaseFromOutsideIsRefusedByItsCase() throws {
        // Given
        let table = types.loweredTypes
        let target = LoweredType.named(try #require(table.row(named: "App.Target")))
        let short = Value.struct(Struct(name: "App.Target.remote", ["host": .string("a")]))
        let undeclared = Value.struct(Struct(name: "App.Target.wide", [:]))

        // When / Then
        #expect {
            try target.settling(short, at: "target", in: table)
        } throws: { error in
            "\(error)".contains("target.port: required by App.Target.remote, and nothing was given")
        }
        #expect {
            try table.admitting(undeclared, under: .any, at: "target")
        } throws: { error in
            "\(error)".contains("target: is a App.Target.wide, which no document declares as a struct or a case")
        }
    }

    @Test("a case from outside keeps its spelling, a field the case never named left out, whatever its place declares")
    func aCaseFromOutsideIsFittedToItsCase() throws {
        // Given
        let table = types.loweredTypes
        let remote = Value.struct(
            Struct(name: "App.Target.remote", ["host": .string("a"), "port": .int(1), "scheme": .string("tcp")])
        )

        // When
        let fitted = try table.admitting(remote, under: .any, at: "target")

        // Then
        #expect(fitted == .struct(Struct(name: "App.Target.remote", ["host": .string("a"), "port": .int(1)])))
    }

    @Test("a case from outside taking type parameters reads them off its fields at Any, and as its place applies the enum")
    func aGenericCaseFromOutsideIsApplied() throws {
        // Given
        let table = types.loweredTypes
        let result = try #require(table.row(named: "App.Result"))
        let ok = Value.struct(Struct(name: "App.Result.ok", ["value": .int(1)]))

        // When / Then
        #expect(try table.admitting(ok, under: .any, at: "result") == ok)
        #expect(try table.admitting(ok, under: .named(result, arguments: [.int, .string]), at: "result") == ok)
        #expect(throws: DoorRefused.self) {
            try table.admitting(ok, under: .named(result, arguments: [.string, .string]), at: "result")
        }
    }

    @Test(
        "a struct from outside under the enum's own name, a spelling no enum declares a case under, or an alias's spelling refuses",
        arguments: [
            ("App.Target", "an enum's name declares no struct"),
            ("App.Target.ftp", "which no document declares"),
            ("App.Goal.local", "which no document declares")
        ]
    )
    func aStructUnderNoCasesSpellingRefuses(name: Name, reason: String) throws {
        // Given
        let table = types.loweredTypes
        let value = Value.struct(Struct(name: name, [:]))

        // When / Then
        #expect {
            try table.admitting(value, under: .any, at: "target")
        } throws: { error in
            "\(error)".contains(reason)
        }
    }

    @Test("a refused cast names a value of an enum by the enum, never by its case's spelling")
    func aRefusedCastNamesTheEnum() throws {
        // Given
        let table = types.loweredTypes
        let target = LoweredType.named(try #require(table.row(named: "App.Target")))
        let ok = Value.struct(Struct(name: "App.Result.ok", ["value": .int(1)]))

        // When / Then
        #expect {
            try target.reading(ok, optional: false, in: table)
        } throws: { error in
            (error as? CastRefused)?.actual == "App.Result"
        }
        #expect(try target.reading(ok, optional: true, in: table) == .null)
    }

    // MARK: - Public
    // MARK: - Private
}
