//
//  InterfaceTests.swift
//  WarpStandardTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
import Warp
import WarpStandard
import WarpSyntax

// `Standard`'s interface is the IR's contract for the vocabulary, and the
// runtime's `Standard`, its native bundles and `lib/standard` together, is
// held to it declaration by declaration.
@Suite("Standard's interface")
struct InterfaceTests {
    // MARK: - Property
    private let sut = Module.standard

    // MARK: - Initializer
    // MARK: - Test
    @Test("Standard declares what its interface declares")
    func standardDeclaresItsInterface() throws {
        // Given
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Standard
            .deletingLastPathComponent()   // WarpStandardTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // the repository
            .appendingPathComponent("warp/lib/standard/interface/standard.interface.warpt")
        let interface = try Loader().interface(
            try TextEncoding().value(from: String(contentsOf: file, encoding: .utf8))
        )

        // When
        var types: [Name: TypeDeclaration] = [:]
        var contracts: [Name: Contract] = [:]
        var claims: [Head: Set<Name>] = [:]
        var members: [Head: Set<Name>] = [:]
        var typeMembers: [Head: [Name: TypeExpression]] = [:]
        var signatures: [Name: Signature] = [:]

        for module in sut {
            types.merge(module.types) { declared, _ in declared }
            contracts.merge(module.contracts) { declared, _ in declared }
            claims.merge(module.claims) { declared, more in declared.union(more) }
            members.merge(module.members) { declared, more in declared.union(more) }
            typeMembers.merge(module.typeMembers) { declared, more in declared.merging(more) { given, _ in given } }
            signatures.merge(
                module.procedures
                    .filter { _, procedure in procedure.access.reachesOtherDocuments }
                    .mapValues(\.signature)
            ) { declared, _ in declared }
        }

        // Then
        hold(types, to: interface.types, as: "type", spelled: \.self)
        hold(contracts, to: interface.contracts, as: "contract", spelled: \.self)
        hold(claims, to: interface.claims, as: "claims of", spelled: \.spelling)
        hold(members, to: interface.members, as: "members of", spelled: \.spelling)
        hold(typeMembers, to: interface.typeMembers, as: "member types of", spelled: \.spelling)
        hold(signatures, to: interface.procedures.mapValues(\.signature), as: "procedure", spelled: \.self)
    }

    // MARK: - Public
    // MARK: - Private
    // Each declaration the interface or the runtime makes, missing from the
    // other or differing, is an issue of its own.
    private func hold<Key: Hashable & Comparable, Declared: Equatable>(
        _ implemented: [Key: Declared],
        to declared: [Key: Declared],
        as kind: String,
        spelled: (Key) -> Name
    ) {
        for key in Set(implemented.keys).union(declared.keys).sorted() {
            switch (implemented[key], declared[key]) {
            case (nil, _):
                Issue.record("\(kind) \(spelled(key)): the interface declares it and Standard does not")

            case (_, nil):
                Issue.record("\(kind) \(spelled(key)): Standard declares it and the interface does not")

            case let (implementation?, declaration?):
                #expect(implementation == declaration, "\(kind) \(spelled(key)) differs from the interface")
            }
        }
    }
}
