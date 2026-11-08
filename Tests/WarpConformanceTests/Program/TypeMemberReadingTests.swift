//
//  TypeMemberReadingTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 11/2/26.
//

import Foundation
import Testing
import Warp
import WarpSyntax

// A type member written after a type, read in a program through `Runner`:
// what a declaration naming one reads as, and where the build refuses one
// whose reading its head does not take.
@Suite("A type member written after a type, in a program")
struct TypeMemberReadingTests {
    // MARK: - Property
    private let runner = Runner()

    // A contract `App.Marked` no claim puts `App.Other<Int>` under, and
    // `App.Wrapper` given `X` under `App.Wrapper<some T: App.Marked>`.
    private static let unclaimed = """
        (contract App.Marked)
        (struct App.Other (typeParameter U) (field item (some U)))
        (struct App.Wrapper (typeParameter T) (field item (some T)))
        (extension (head (named App.Wrapper (some T App.Marked))) (type X String))
        """

    // `App.Wrapper<App.Other<Int>>.X`, which `App.Wrapper`'s head does not
    // take where nothing claims `App.Other<Int>` conforms to `App.Marked`.
    private static let unboundMember = "(member (named App.Wrapper (named App.Other Int)) X)"

    // MARK: - Initializer
    // MARK: - Test
    @Test("an alias of a type member under a bounded head reads as the type it gives")
    func anAliasUnderABoundedHead() async throws {
        // Given. `App.Wrapper` bounds `T` by Hashable, which Int conforms to
        let sut = try Self.program("""
            (struct App.Wrapper (typeParameter T Hashable) (field item (some T)) (type Item (some T)))
            (type App.Y (member (named App.Wrapper Int) Item))
            (procedure App.echo (parameter x (type App.Y)) (returns Int) (body (return x)))
            (procedure entry (access public) (returns Int) (body (let e (call App.echo 7)) (return e)))
            """)

        // When
        let returned = try await runner.run(sut)

        // Then
        #expect(returned == .int(7))
    }

    @Test("an alias of a type member under a head bounded by a claimed contract reads as the type it gives")
    func anAliasUnderAClaimedBound() async throws {
        // Given. A claim puts `App.Other<Int>` under `App.Marked`
        let sut = try Self.program("""
            \(Self.unclaimed)
            (extension (head (named App.Other Int)) (satisfies App.Marked))
            (type App.Y \(Self.unboundMember))
            (procedure App.echo (parameter x (type App.Y)) (returns String) (body (return x)))
            (procedure entry (access public) (returns String) (body (let e (call App.echo "b")) (return e)))
            """)

        // When
        let returned = try await runner.run(sut)

        // Then
        #expect(returned == .string("b"))
    }

    @Test("a field of a type member under a bounded head reads as the type it gives")
    func aFieldUnderABoundedHead() async throws {
        // Given
        let sut = try Self.program("""
            (struct App.Wrapper (typeParameter T Hashable) (field item (some T)) (type Item (some T)))
            (struct App.Holder (field value (member (named App.Wrapper Int) Item)))
            (procedure entry (access public) (returns Int)
              (body (let h (type App.Holder) (struct (field value 7))) (return (path h (field value)))))
            """)

        // When
        let returned = try await runner.run(sut)

        // Then
        #expect(returned == .int(7))
    }

    @Test("a reading the head's bound does not take refuses at the build wherever the type is written", arguments: [
        "(type App.Y \(unboundMember))",
        "(struct App.Holder (field value \(unboundMember)))",
        "(struct App.Box (field item Int) (type Item \(unboundMember)))",
        "(procedure App.take (parameter x (type \(unboundMember))) (returns Int) (body (return 1)))",
        "(procedure App.cast (parameter value) (returns (optional String)) (body (return (as? value \(unboundMember)))))"
    ])
    func aReadingFailingTheBoundRefuses(written: String) async throws {
        // Given
        let sut = try Self.program("""
            \(Self.unclaimed)
            \(written)
            (procedure entry (access public) (returns Int) (body (return 1)))
            """)

        // When
        let refusal = try #require(try await runner.reached(sut))

        // Then
        #expect(refusal.stage == .build)
        #expect("\(refusal.error)".contains(
            "under App.Wrapper<some T: App.Marked>, which does not take App.Wrapper<App.Other<Int>>"
        ))
        #expect("\(refusal.error)".contains("'App.Other' conforms to 'App.Marked'"))
    }

    @Test("a type member written as an associated type reads as the type member the reading's type gives", arguments: [
        """
        (type App.Y (member (named App.Wrapper App.Foo) X))
        (procedure App.echo (parameter x (type App.Y)) (returns String) (body (return x)))
        (procedure entry (access public) (returns String) (body (let e (call App.echo "i")) (return e)))
        """,
        """
        (struct App.Holder (field value (member (named App.Wrapper App.Foo) X)))
        (procedure entry (access public) (returns String)
          (body (let h (type App.Holder) (struct (field value "i"))) (return (path h (field value)))))
        """
    ])
    func anAssociatedTypeReadsTheTypesOwn(written: String) async throws {
        // Given. `App.Wrapper<App.Foo>.X` reads `T.Key` as `App.Foo.Key`,
        // which is String
        let sut = try Self.program("""
            \(Self.keyed("(satisfies App.Keyed)"))
            \(written)
            """)

        // When
        let returned = try await runner.run(sut)

        // Then
        #expect(returned == .string("i"))
    }

    @Test("a type member written as an associated type refuses at the build where the reading's type does not conform", arguments: [
        "(type App.Y (member (named App.Wrapper App.Foo) X))",
        "(struct App.Holder (field value (member (named App.Wrapper App.Foo) X)))"
    ])
    func anAssociatedTypeOfANonconformingTypeRefuses(written: String) async throws {
        // Given. No claim puts `App.Foo` under `App.Keyed`, though it is
        // given `Key`
        let sut = try Self.program("""
            \(Self.keyed(""))
            \(written)
            (procedure entry (access public) (returns Int) (body (return 1)))
            """)

        // When
        let refusal = try #require(try await runner.reached(sut))

        // Then
        #expect(refusal.stage == .build)
        #expect("\(refusal.error)".contains("no claim within reach says 'App.Foo' conforms to 'App.Keyed'"))
    }

    @Test("a reading the head does not take as written refuses at the build")
    func aReadingTheHeadDoesNotTakeRefuses() async throws {
        // Given. `App.Wrapper` given `Item` under `App.Wrapper<Int>` alone
        let sut = try Self.program("""
            (struct App.Wrapper (typeParameter T) (field item (some T)))
            (extension (head (named App.Wrapper Int)) (type Item String))
            (type App.Y (member (named App.Wrapper String) Item))
            (procedure entry (access public) (returns Int) (body (return 1)))
            """)

        // When
        let refusal = try #require(try await runner.reached(sut))

        // Then
        #expect(refusal.stage == .build)
        #expect("\(refusal.error)".contains("App.Wrapper<String> is no App.Wrapper<Int>"))
    }

    @Test("a type member given under a head naming a type member's spelling reads as the type it gives", arguments: [
        """
        (type App.Y (member (named App.Wrapper Int) X))
        (procedure App.echo (parameter x (type App.Y)) (returns String) (body (return x)))
        (procedure entry (access public) (returns String) (body (let e (call App.echo "a")) (return e)))
        """,
        """
        (struct App.Holder (field value (member (named App.Wrapper Int) X)))
        (procedure entry (access public) (returns String)
          (body (let h (type App.Holder) (struct (field value "a"))) (return (path h (field value)))))
        """
    ])
    func aHeadNamingASpelling(written: String) async throws {
        // Given. `App.Wrapper` given `X` under `App.Wrapper<App.Box.Item>`,
        // which is `App.Wrapper<Int>`
        let sut = try Self.program("""
            (struct App.Box (field item Int) (type Item Int))
            (struct App.Wrapper (typeParameter T) (field item (some T)))
            (extension (head (named App.Wrapper App.Box.Item)) (type X String))
            \(written)
            """)

        // When
        let returned = try await runner.run(sut)

        // Then
        #expect(returned == .string("a"))
    }

    @Test("a type member given to a type the language names is named by its spelling")
    func aLanguageTypesSpellingInASlot() async throws {
        // Given
        let sut = try Self.program("""
            (extension (head Int) (type Kind String))
            (procedure App.take (parameter x (type Int.Kind)) (returns String) (body (return x)))
            (procedure entry (access public) (returns String) (body (let t (call App.take "z")) (return t)))
            """)

        // When
        let returned = try await runner.run(sut)

        // Then
        #expect(returned == .string("z"))
    }

    @Test("a cast to a type member's spelling under a type the language names casts to the type it gives")
    func aLanguageTypesSpellingInACast() async throws {
        // Given
        let sut = try Self.program(
            """
            (extension (head Int) (type Kind String))
            (procedure entry (access public) (parameter value) (returns (optional String))
              (body (return (as? value Int.Kind))))
            """,
            arguments: "(arguments (argument value \"a\"))"
        )

        // When
        let returned = try await runner.run(sut)

        // Then
        #expect(returned == .string("a"))
    }

    @Test("an Optional's type member named by a spelling refuses at the build")
    func anOptionalsSpellingRefuses() async throws {
        // Given. A head writes an Optional by its `?`, so no spelling names
        // one's type member
        let sut = try Self.program("""
            (extension (head (optional (some W))) (type Kind String))
            (procedure App.take (parameter x (type Optional.Kind)) (returns String) (body (return x)))
            (procedure entry (access public) (returns String) (body (return "z")))
            """)

        // When
        let refusal = try await runner.reached(sut)

        // Then
        #expect(refusal?.stage == .build)
    }

    // MARK: - Public
    // MARK: - Private
    // A case's program declaring `declarations`, handed `arguments`.
    private static func program(_ declarations: String, arguments: String = "") throws -> Case.Program {
        let sut = try Case(from: try TextEncoding().value(from: """
            (test 1)
            (name "type-member-reading")
            (note "a type member written after a type")
            (program (warp 1)
            \(declarations))
            \(arguments)
            (expect (refuses build))
            """), in: "type-member-reading")

        guard case let .program(program) = sut.asked else {
            throw ConformanceError("a case with a program asks about a program")
        }

        return program
    }

    // `App.Wrapper` given `X` as `some T.Key`, the associated type `Key` of
    // its parameter `T`, which `App.Keyed` bounds, beside `App.Foo`, given
    // `Key` as String. `satisfies` is what `App.Foo` claims, empty or
    // `(satisfies App.Keyed)`.
    private static func keyed(_ satisfies: String) -> String {
        """
        (contract App.Keyed (type Key))
        (struct App.Foo \(satisfies) (field item Int) (type Key String))
        (struct App.Wrapper (typeParameter T App.Keyed) (field item (some T)) (type X (some T.Key)))
        """
    }
}
