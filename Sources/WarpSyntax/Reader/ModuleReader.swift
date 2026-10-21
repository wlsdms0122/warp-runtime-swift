//
//  ModuleReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// A document, which is a module and not a procedure: what it imports and
// what it declares. Which procedure runs is named when a run starts.
public struct ModuleReader: Decodable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case imports
        case types
        case contracts
        case extensions
        case const
        case variables = "var"
        case procedures
    }

    // MARK: - Property
    // Which types a reader has to understand. It goes up when a type is added
    // or an existing one changes what it means, and does not move for a new
    // procedure, which is vocabulary. Every document says it.
    public static let version = 1

    // What the document declares, unjudged. Reading and checking are two
    // questions and only one of them is about the program: a text nobody can
    // run is still a text, and still that one, so the reading answers for it
    // and `Module` is where it is held to anything.
    let draft: Draft

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try Self.checkVersion(in: decoder)

        try KeyGate().rejectUnknownKeys(
            in: decoder,
            known: CodingKeys.self,
            extra: [Module.versionKey.spelling],
            context: "module"
        )

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let types = try Self.mapping(TypeDeclarationReader.self, in: container, forKey: .types)
        let written = try Self.mapping(ExtensionReader.self, in: container, forKey: .extensions)
        var procedures = try Self.mapping(ProcedureReader.self, in: container, forKey: .procedures)
            .mapValues(\.procedure)
        var claims: [Head: Set<Name>] = [:]
        var members: [Head: Set<Name>] = [:]
        var typeMembers: [Head: [Name: TypeExpression]] = [:]

        // An extension's key is a head: the type, and what it is applied to
        // where what it gives holds for some of the type's values. A struct
        // this document declares is given what every value of it has where
        // it is declared, so a bare extension of it would be a second way to
        // write one document, and two keys reading as one head are two ways
        // to write one extension.
        var extensions: [Head: (key: Name, extended: ExtensionReader)] = [:]

        for (key, extended) in written.sorted(by: { $0.key < $1.key }) {
            let steps: [Place.Step] = [.key(CodingKeys.extensions.rawValue), .key(key.spelling)]
            let head = try ExtensionReader.head(of: key, in: decoder.notation, at: steps)

            if let first = extensions[head] {
                throw ReadingError(
                    "reads as '\(head.spelling)', and so does '\(first.key)'. A document writes one extension"
                        + " under one head",
                    at: steps
                )
            }

            if head.isBare, case .struct? = types[head.type]?.declared {
                throw ReadingError(
                    "extends '\(head.type)', a struct this document declares. A document gives every value of"
                        + " a struct it declares what it gives it in the declaration",
                    at: steps
                )
            }

            extensions[head] = (key, extended)
        }

        // What the document gives each head, from where it gave it: a struct
        // it declares in its declaration, and the rest in an extension, an
        // alias it declares included, which the load refuses for what it is.
        // A member joins the procedures under its type's name and its own, so
        // a procedure the document declares under that spelling is a second
        // declaration of it.
        let given = types.map { name, declared in
            (
                Head(name),
                declared.satisfies,
                declared.types,
                declared.procedures,
                [Place.Step.key(CodingKeys.types.rawValue), .key(name.spelling)]
            )
        } + extensions.map { head, written in
            (
                head,
                written.extended.satisfies,
                written.extended.types,
                written.extended.procedures,
                [Place.Step.key(CodingKeys.extensions.rawValue), .key(written.key.spelling)]
            )
        }

        for (head, satisfies, memberTypes, memberProcedures, steps) in given.sorted(by: { $0.0 < $1.0 }) {
            if !satisfies.isEmpty {
                claims[head] = satisfies
            }

            if !memberTypes.isEmpty {
                typeMembers[head] = memberTypes
            }

            for (member, procedure) in memberProcedures.sorted(by: { $0.key < $1.key }) {
                let spelling = member.spelled(under: head.type)

                guard procedures[spelling] == nil else {
                    throw ReadingError(
                        "gives '\(head.spelling)' the member '\(member)', and '\(spelling)' is declared"
                            + " once already in this document",
                        at: steps + [
                            .key(ExtensionReader.CodingKeys.procedures.rawValue),
                            .key(member.spelling)
                        ]
                    )
                }

                procedures[spelling] = procedure
                members[head, default: []].insert(member)
            }
        }

        let imports = try Self.imports(in: container)

        self.draft = Draft(
            imports: imports?.names ?? nil,
            importedClaims: imports?.claims ?? [],
            types: types.mapValues(\.declared),
            contracts: try Self.mapping(ContractReader.self, in: container, forKey: .contracts)
                .mapValues(\.contract),
            claims: claims,
            members: members,
            typeMembers: typeMembers,
            constants: try Self.mapping(ExpressionReader.self, in: container, forKey: .const)
                .mapValues(\.expression),
            variables: try Self.mapping(VariableReader.self, in: container, forKey: .variables)
                .mapValues(\.variable),
            procedures: procedures
        )
    }

    // MARK: - Public
    // MARK: - Private
    // What the document says it takes from its link, read and not judged. What
    // it is held against is what the module sends, which is a fact about the
    // module rather than about the text, so the refusal is the module's.
    //
    // Nothing written is nothing claimed, and a slot written as null says the
    // same. Whether a document may leave it out at all is the load's, which
    // reads the claim off the draft this answers.
    //
    // A name, or a claim another document makes, written as the type and the
    // contract it is about, `T.Card: App.Describable`. A list writing claims
    // and no name claims no names: a notation's author never wrote the
    // spellings its shorthands were spent into, and the names are filled in
    // where a text is written out. A document is held to its whole list
    // where it is loaded, by being the one way its program is written.
    // What an import is read as: a name, or a claim's type and contract
    // either side of its `:`, each without the white space around it.
    static func parts(ofImport spelled: String) -> [String] {
        let parts = spelled.split(separator: ":", omittingEmptySubsequences: false)
            .map { part in part.trimmingCharacters(in: .whitespaces) }

        return parts.count == 1 ? [spelled] : parts
    }

    private static func imports(
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> (names: Set<Name>?, claims: Set<ClaimPair>)? {
        guard container.contains(.imports), try !container.decodeNil(forKey: .imports) else { return nil }

        let written = try container.superDecoder(forKey: .imports)
        var names: Set<Name> = []
        var claims: Set<ClaimPair> = []

        for (position, spelled) in try written.read([String].self).enumerated() {
            let steps = written.steps + [.index(position)]
            let parts = Self.parts(ofImport: spelled)

            switch parts.count {
            case 1:
                names.insert(try Name.read(parts[0], at: steps))

            // Written the one way where a document is loaded, which the
            // write-back holds a text to.
            case 2:
                claims.insert(ClaimPair(try Name.read(parts[0], at: steps), try Name.read(parts[1], at: steps)))

            default:
                throw ReadingError(
                    "imports '\(spelled)', which is neither a name nor a claim: a claim is written"
                        + " as the type and the contract it is about, `T.Card: App.Describable`",
                    at: steps
                )
            }
        }

        return (names.isEmpty && !claims.isEmpty ? nil : names, claims)
    }


    // One of the slots a module declares a mapping of things under, read
    // standing on the slot so that what is refused inside it is addressed
    // there. Nothing written is nothing declared, which is what an absent slot
    // is and what a slot written as null says.
    private static func mapping<T: Decodable>(
        _ type: T.Type,
        in container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> [Name: T] {
        guard container.contains(key), try !container.decodeNil(forKey: key) else { return [:] }

        let written = try container.superDecoder(forKey: key)

        return try written.read([Name: T].self)
    }

    // A document says which language it is written for, and one that does not
    // is not a document. Any version but this reader's is refused. Read
    // through its own container, before the keys are judged, so a reader too
    // old for a document says so rather than refusing its keys.
    private static func checkVersion(in decoder: Decoder) throws {
        let document = try decoder.container(keyedBy: AnyCodingKey.self)
        let key = AnyCodingKey(stringValue: Module.versionKey.spelling)

        // About the document and not about anything in it: what is missing is
        // the one thing that would have made this a document, and there is
        // nothing written here to stand on.
        guard document.contains(key), try !document.decodeNil(forKey: key) else {
            throw ReadingError(
                "this is not a warp document. It does not say"
                    + " which warp it is written for (`\(Module.versionKey)`)",
                at: decoder.steps
            )
        }

        // The rest is about the version that is written, so it is read standing on
        // it. Refusing from out here would put the answer at the document's
        // first character, which is a line the author has no reason to look at.
        let written = try document.superDecoder(forKey: key)
        let version = try written.read(Int.self)

        // One version, because a document is spelled one way: the way the
        // writer of this version writes it. An older document is written
        // again, and a later one is for a reader that knows it.
        guard version == Self.version else {
            throw ReadingError(
                "this document is written for warp \(version), and this reads warp \(Self.version)."
                    + " Write it again for \(Self.version)",
                at: written.steps
            )
        }
    }
}
