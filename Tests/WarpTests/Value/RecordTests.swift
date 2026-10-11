//
//  RecordTests.swift
//  WarpTests
//
//  Created by JSilver on 9/4/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A record stands on the layout it was made with")
struct RecordTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a layout orders its fields by their names' bytes whichever way they were given")
    func aLayoutIsOrderedByBytes() throws {
        // Given
        let sut = try Layout(fields: ["b", "a", "c"])

        // When / Then
        #expect(sut.fields == ["a", "b", "c"])
        #expect(sut.position(of: "b") == 1)
        #expect(sut.position(of: "z") == nil)
    }

    @Test("a layout naming one field twice is refused rather than fatal")
    func aRepeatedFieldIsRefused() {
        // When / Then
        #expect(throws: ValueRefused.self) { try Layout(fields: ["a", "b", "a"]) }
    }

    @Test("a record built from fields holds them at their layout's places")
    func fieldsStandWhereTheLayoutPutsThem() {
        // Given
        let sut = Record(name: nil, ["b": .int(2), "a": .int(1), "c": .int(3)])

        // When / Then
        #expect(sut.names == ["a", "b", "c"])
        #expect(sut.values == [.int(1), .int(2), .int(3)])
        #expect(sut["b"] == .int(2))
        #expect(sut["z"] == nil)
    }

    @Test("a layout handed the wrong number of values is refused")
    func aLayoutIsFilledExactly() throws {
        // Given
        let layout = try Layout(fields: ["a", "b"])

        // When / Then
        #expect(try Record(layout: layout, checking: [.int(1), .int(2)]).values == [.int(1), .int(2)])
        #expect(throws: ValueRefused.self) { try Record(layout: layout, checking: [.int(1)]) }
        #expect(throws: ValueRefused.self) { try Record(layout: layout, checking: [.int(1), .int(2), .int(3)]) }
    }

    @Test("a field the layout does not name is refused rather than made")
    func aFieldOutsideTheLayoutIsRefused() throws {
        // Given
        let sut = Record(name: "App.Point", ["a": .int(1), "c": .int(3)])

        // When / Then
        #expect(try sut.writing("c", with: .int(30)).values == [.int(1), .int(30)])
        #expect(throws: ValueRefused.self) { try sut.writing("b", with: .int(2)) }
    }

    @Test("a value that settled to a name keeps it, and is refused a field that name does not declare")
    func writingHoldsARecordNameToItsDeclaration() throws {
        // Given
        let sut = Value.record(Record(name: "App.Point", ["a": .int(1)]))

        // When / Then. A declared field is written where it stands
        #expect(try sut.writing("a", with: .int(9)) == .record(Record(name: "App.Point", ["a": .int(9)])))

        // A name the declaration never had would make this something other
        // than the type it settled to
        #expect(throws: ValueRefused.self) { try sut.writing("b", with: .int(2)) }
        #expect(throws: ValueRefused.self) { try Value.int(1).writing("a", with: .int(2)) }
    }

    @Test("a value that settled to no name holds a new one as data")
    func writingOutsideALayoutWithNoNameAnswersData() throws {
        // Given
        let sut = Value.record(Record(name: nil, ["a": .int(1)]))

        // When / Then
        #expect(try sut.writing("b", with: .int(2)) == .dictionary(["a": .int(1), "b": .int(2)]))
    }

    @Test("a nameless record and the dictionary it equals are written the same way")
    func equalValuesAreWrittenAlike() throws {
        // Given. The contract says these are one value, so a door on top of it
        // cannot tell them apart
        let laid = Value.record(Record(name: nil, ["a": .int(1)]))
        let held = Value.dictionary(["a": .int(1)])

        // When / Then
        #expect(laid == held)
        #expect(try laid.writing("b", with: .int(2)) == (try held.writing("b", with: .int(2))))
        #expect(try laid.writing("a", with: .int(9)) == (try held.writing("a", with: .int(9))))
    }

    @Test("a record's name is part of its layout")
    func aNameIsPartOfTheLayout() {
        // Given
        let sut = Record(name: "App.Point", ["a": .int(1)])

        // When / Then
        #expect(sut.name == "App.Point")
        #expect(sut.named(nil).name == nil)
        #expect(sut != Record(name: nil, ["a": .int(1)]))
        #expect(sut != Record(name: "App.Vault", ["a": .int(1)]))
    }

    @Test("mapping values changes every value and nothing else")
    func mappingValuesKeepsTheLayout() throws {
        // Given
        let sut = Record(name: "App.Point", ["y": .int(2), "x": .int(1)])

        // When
        let doubled = try sut.mapValues { _, value in
            guard case let .int(number) = value else { throw ArgumentError("not a number") }

            return .int(number * 2)
        }

        // Then
        #expect(doubled.layout == sut.layout)
        #expect(doubled.values == [.int(2), .int(4)])
    }

    @Test("a nameless record and a dictionary of the same fields are one value")
    func aNamelessRecordEqualsADictionary() {
        // Given
        let record = Value.record(Record(name: nil, ["a": .int(1), "b": .string("x")]))
        let named = Value.record(Record(name: "App.T", ["a": .int(1), "b": .string("x")]))
        let dictionary = Value.dictionary(["a": .int(1), "b": .string("x")])

        // When / Then
        #expect(record == dictionary)
        #expect(named != dictionary)
        #expect(record.matches(.dictionary(["a": .double(1), "b": .string("x")])))
        #expect(record["a"] == .int(1))
    }

    @Test("a path write reaches a nameless record and the dictionary it equals the same way")
    func aPathWriteReadsEitherSpelling() throws {
        // Given. The contract says these are one value
        let laid = Value.record(Record(name: nil, ["a": .int(1)]))
        let held = Value.dictionary(["a": .int(1)])
        let path: [Projection] = [.key("b")]

        // When / Then
        #expect(laid == held)
        #expect(
            try laid.writing(.int(2), at: path, under: "x.b")
                == (try held.writing(.int(2), at: path, under: "x.b"))
        )
    }

    @Test("a write lands on the place the link put the field at, whatever spelling stands beside it")
    func aWriteLandsOnItsPlace() throws {
        // Given
        let point = Value.record(Record(name: nil, ["x": .int(1), "y": .int(2)]))

        // When
        let written = try point.writing(.int(9), at: [.field(1, "z")], under: "point.z")

        // Then
        #expect(written == .record(Record(name: nil, ["x": .int(1), "y": .int(9)])))
    }

    @Test("a layout a host builds carries no name of its own")
    func aHostBuiltLayoutHasNoName() throws {
        // Given. A name says a declaration, and a declaration is the build's
        let layout = try Layout(fields: ["balance"])

        // When
        let built = try Record(layout: layout, checking: [.int(1)])

        // Then
        #expect(built.name == nil)
        #expect(Value.record(built) == .dictionary(["balance": .int(1)]))
    }

    // MARK: - Public
    // MARK: - Private
}
