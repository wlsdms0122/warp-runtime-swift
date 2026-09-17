//
//  Envelope.swift
//  WarpSyntax
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// What a document says about itself before anything reads what it says.
//
// A program that stays where it was built needs none of this. The thing that
// built it is the thing that runs it. A program that travels does: it arrives
// at something that may be older than the program is, may not have the procedures
// the program calls, and cannot ask the sender anything. Both questions have to
// be answerable from the bytes alone, and both have to be answerable *before*
// the program runs, because half-running one is worse than refusing it.
public enum Envelope {
    // MARK: - Property
    // Which types a reader has to understand. It goes up when a type is added
    // or an existing one changes what it means, and does not move for a new
    // procedure. A procedure is vocabulary, and vocabulary is what `imports` is for.
    //
    // Every document says it. A reader that filled in a default would be
    // reading a document that never said which language it was written for, and
    // a file that is not a document at all would get as far as having its keys
    // judged. Turned away for being a malformed module rather than for not
    // being one.
    //
    // Nothing has shipped, so there is nothing old to hold a number for. Every
    // change before the first release folds into this one. The counter starts
    // moving when a document exists somewhere this code does not control.
    public static let version = 1
    public static let earliest = 1

    public static let versionKey: Name = "warp"
    public static let importsKey: Name = "imports"

    // How deep a document may nest. The bound is exact: every reader takes
    // a document within it and refuses the first container past it, and a
    // value a caller built is held to it at the door a document is read at.
    public static let nesting = 128

    // MARK: - Public
    // Whether a document declares what it imports.
    //
    // Written and not null. A key holding nothing is not a claim, and the two
    // who ask have to agree about that: the door turns away a document that
    // declares nothing, and the reader takes a key holding nothing as a list
    // of no procedures. Answering differently is how `imports: null` passes the
    // door as a claim while the module behind it says it takes nothing.
    //
    // Asked twice because the two are in different places. The door holds the
    // document and reads the value; the reader is inside it and has a
    // container. One rule, said here in both of their procedures.
    public static func declaresImports(_ written: Value?) -> Bool {
        guard let written else { return false }

        return written != .null
    }

    public static func declaresImports<Key: CodingKey>(
        in container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Bool {
        try container.contains(key) && !container.decodeNil(forKey: key)
    }

    // MARK: - Private
}
