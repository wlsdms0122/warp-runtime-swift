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
// A program that stays where it was built needs none of this — the thing that
// built it is the thing that runs it. A program that travels does: it arrives at
// something that may be older than the program is, may not have the words the
// program calls, and cannot ask the sender anything. Both questions have to be
// answerable from the bytes alone, and both have to be answerable *before* the
// program runs, because half-running one is worse than refusing it.
public enum Envelope {
    // MARK: - Property
    // Which shapes a reader has to understand. It goes up when a shape is added
    // or an existing one changes what it means, and does not move for a new word
    // — a word is vocabulary, and vocabulary is what `imports` is for.
    //
    // Every document says it. A reader that filled in a default would be reading
    // a document that never said which language it was written for, and a file
    // that is not a document at all would get as far as having its keys judged —
    // turned away for being a malformed module rather than for not being one.
    //
    // The reading range is one number: nothing has shipped, so no document
    // written for an earlier number is one a reader is asked to hold, and
    // the earliest moves with the current. The number moved when a
    // statement's spelling did.
    public static let version = 2
    public static let earliest = 2

    public static let versionKey = "warp"
    public static let importsKey = "imports"

    // MARK: - Public
    // Whether a document declares what it imports.
    //
    // Written and not null. A key holding nothing is not a claim, and the two
    // who ask have to agree about that: the door turns away a document that
    // declares nothing, and the reader takes a key holding nothing as a list
    // of no words. Answering differently is how `imports: null` passes the
    // door as a claim while the module behind it says it takes nothing.
    //
    // Asked twice because the two are in different places. The door holds the
    // document and reads the value; the reader is inside it and has a
    // container. One rule, said here in both of their words.
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
