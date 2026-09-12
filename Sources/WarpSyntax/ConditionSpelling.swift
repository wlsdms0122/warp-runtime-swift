//
//  ConditionSpelling.swift
//  WarpSyntax
//
//  Created by JSilver
//

import Foundation
import Warp

// How a notation writes a condition, for a notation that writes one specially.
//
// In a document a condition slot holds an expression. A `when` that must answer
// a bool, and nothing more is said about it. Everything else a condition slot
// has ever looked like is a notation's: the record of an operator key and its
// subject, which keys count as operators, whether one takes its expression
// directly, which procedure each reaches, and which side of the send the subject
// lands on. None of that is in this package, and this is the hole where it
// goes.
//
// So a reader here can lower a spelling it was never told about by name, and a
// document (read with no notation at all) has nothing to lower.
//
// It is a reader rather than a table because the lowering is a reading: a
// connective holds conditions, which are read the same way recursively, and the
// pieces report where they are through the same coding path everything else
// does. A table of keys and procedures could not say that, and the type of the
// record is exactly the part that varies.
public protocol ConditionSpelling: Sendable {
    // The keys that make a record one of this notation's conditions. A record
    // carrying none of them is read as the expression it is, which is what keeps
    // these spellings optional wherever a condition is asked for.
    //
    // A key named here is answered by this spelling or refused by it. Never
    // read as a record that happens to have that field. Giving up a spelling
    // says a document may not write it; it does not hand the procedure back to mean
    // something else, which would make the same document mean two things in two
    // notations.
    var keys: Set<Name> { get }

    // Procedures these spellings reach, which a link has to declare for them to reach
    // anything. A condition slot spends them on the notation's behalf, so the
    // forms that read one ask for them here rather than knowing any of them.
    var vocabulary: Set<Name> { get }

    // The condition a record spells. Reached only for a record carrying one of
    // `keys`, and free to refuse. A key this notation names but does not
    // offer is refused here, and so is one written in a type it does not
    // have.
    func condition(from decoder: Decoder) throws -> Expression
}
