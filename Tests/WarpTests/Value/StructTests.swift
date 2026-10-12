//
//  StructTests.swift
//  WarpTests
//
//  Created by JSilver on 9/4/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A struct stands on the layout it was made with")
struct StructTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a layout holds its fields in their names' byte order, and a field is found there")
    func aLayoutIsOrderedByBytes() throws {
        // Given
        let sut = try Layout(name: "App.T", judging: ["a", "b", "c"])

        // When / Then
        #expect(sut.fields == ["a", "b", "c"])
        #expect(sut.position(of: "b") == 1)
        #expect(sut.position(of: "z") == nil)
    }

    @Test("a layout read out of order or naming one field twice is refused rather than fatal")
    func aRepeatedFieldIsRefused() {
        // When / Then
        #expect(throws: ValueRefused.self) { try Layout(name: "App.T", judging: ["b", "a"]) }
        #expect(throws: ValueRefused.self) { try Layout(name: "App.T", judging: ["a", "a"]) }
    }

    @Test("a struct built from fields holds them at their layout's places")
    func fieldsStandWhereTheLayoutPutsThem() {
        // Given
        let sut = Struct(name: "App.T", ["b": .int(2), "a": .int(1), "c": .int(3)])

        // When / Then
        #expect(sut.names == ["a", "b", "c"])
        #expect(sut.values == [.int(1), .int(2), .int(3)])
        #expect(sut["b"] == .int(2))
        #expect(sut["z"] == nil)
    }

    @Test("a layout handed the wrong number of values is refused")
    func aLayoutIsFilledExactly() throws {
        // Given
        let layout = Layout(name: "App.T", ordered: ["a", "b"])

        // When / Then
        #expect(try Struct(layout: layout, checking: [.int(1), .int(2)]).values == [.int(1), .int(2)])
        #expect(throws: ValueRefused.self) { try Struct(layout: layout, checking: [.int(1)]) }
        #expect(throws: ValueRefused.self) { try Struct(layout: layout, checking: [.int(1), .int(2), .int(3)]) }
    }

    @Test("a field the layout does not name is refused rather than made")
    func aFieldOutsideTheLayoutIsRefused() throws {
        // Given
        let sut = Struct(name: "App.Point", ["a": .int(1), "c": .int(3)])

        // When / Then
        #expect(try sut.writing("c", with: .int(30)).values == [.int(1), .int(30)])
        #expect(throws: ValueRefused.self) { try sut.writing("b", with: .int(2)) }
    }

    @Test("a value under a name keeps it, and is refused a field that name does not declare")
    func writingHoldsAStructNameToItsDeclaration() throws {
        // Given
        let sut = Value.struct(Struct(name: "App.Point", ["a": .int(1)]))

        // When / Then. A declared field is written where it stands
        #expect(try sut.writing("a", with: .int(9)) == .struct(Struct(name: "App.Point", ["a": .int(9)])))

        // A name the declaration never had would make this something other
        // than the type it names, and what is no struct, a map included,
        // holds no fields
        #expect(throws: ValueRefused.self) { try sut.writing("b", with: .int(2)) }
        #expect(throws: ValueRefused.self) { try Value.int(1).writing("a", with: .int(2)) }
        #expect(throws: ValueRefused.self) { try Value.dictionary(["a": .int(1)]).writing("a", with: .int(2)) }
    }

    @Test("a struct's name is part of its layout")
    func aNameIsPartOfTheLayout() {
        // Given
        let sut = Struct(name: "App.Point", ["a": .int(1)])

        // When / Then
        #expect(sut.name == "App.Point")
        #expect(sut != Struct(name: "App.Vault", ["a": .int(1)]))
    }

    @Test("mapping values changes every value and nothing else")
    func mappingValuesKeepsTheLayout() throws {
        // Given
        let sut = Struct(name: "App.Point", ["y": .int(2), "x": .int(1)])

        // When
        let doubled = try sut.mapValues { _, value in
            guard case let .int(number) = value else { throw ArgumentError("not a number") }

            return .int(number * 2)
        }

        // Then
        #expect(doubled.layout == sut.layout)
        #expect(doubled.values == [.int(2), .int(4)])
    }

    @Test("a struct and a map of the same fields are two values")
    func aStructIsNoMap() {
        // Given
        let instance = Value.struct(Struct(name: "App.T", ["a": .int(1), "b": .string("x")]))
        let dictionary = Value.dictionary(["a": .int(1), "b": .string("x")])

        // When / Then
        #expect(instance != dictionary)
        #expect(!instance.matches(dictionary))
        #expect(instance["a"] == .int(1))
        #expect(dictionary["a"] == nil)
    }

    @Test("a write lands on the place the link put the field at, whatever spelling stands beside it")
    func aWriteLandsOnItsPlace() throws {
        // Given
        let point = Value.struct(Struct(name: "App.Point", ["x": .int(1), "y": .int(2)]))

        // When
        let written = try point.writing(.int(9), at: [.field(1, "z")], under: "point.z")

        // Then
        #expect(written == .struct(Struct(name: "App.Point", ["x": .int(1), "y": .int(9)])))
    }

    // MARK: - Public
    // MARK: - Private
}
