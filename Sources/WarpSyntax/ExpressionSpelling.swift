//
//  ExpressionSpelling.swift
//  WarpSyntax
//
//  Created by JSilver
//

import Foundation
import Warp

// How a notation writes an expression specially, for a notation that writes
// one. In a document a value slot holds an expression: a literal, a reference,
// a message, a cast, a closure, a record or an array of these, and nothing
// more is said about it. Everything else a slot has ever looked like is a
// notation's: the record of an operator key and its subject, which keys count
// as operators, whether one takes its expression directly, which procedure
// each reaches, and which side of the send the subject lands on. None of that
// is in this package, and this is the hole where it goes.
//
// A spelling is read wherever an expression is: a condition under `when`, an
// operand of a message, an element of an array. So a reader here can lower a
// spelling it was never told about by name, and a document, read with no
// notation at all, has nothing to lower.
//
// It is a reader rather than a table because the lowering is a reading: a
// connective holds expressions, which are read the same way recursively, and
// the pieces report where they are through the same coding path everything
// else does. A table of keys and procedures could not say that, and the form
// of the record is exactly the part that varies.
public protocol ExpressionSpelling: Sendable {
    // Whether a record with these field names is one of this notation's
    // spellings. A record it does not claim is read as the expression it is,
    // which is what keeps these spellings optional wherever an expression is
    // asked for, and a record it claims is answered by this spelling or
    // refused by it. Never read as a record that happens to have those
    // fields. Giving up a spelling says a document may not write it; it does
    // not hand the procedure back to mean something else, which would make the
    // same document mean two things in two notations.
    //
    // Asked of the names and the notation they are read in, so the writer
    // can ask the same question of data before writing it plainly: what the
    // reading side would take for a spelling, the writing side quotes. The
    // notation is handed in because a spelling is held by one and cannot see
    // it, and what a text declares is the notation's to know.
    func claims(_ names: Set<Name>, in notation: Notation) -> Bool

    // Procedures these spellings reach, which a link has to declare for them to
    // reach anything. A slot spends them on the notation's behalf.
    var vocabulary: Set<Name> { get }

    // The expression a record spells. Reached only for a record this notation
    // claims that carries none of the form keys, and free to refuse. A key
    // this notation names but does not offer is refused here, and so is one
    // written in a form it does not have.
    func expression(from decoder: Decoder) throws -> Expression

    // How a record of expressions this notation would claim is written so
    // that it reads back as that record, or nothing where the notation has no
    // way to write one. The writer asks before refusing: a record whose field
    // names happen to be this notation's operators still has to travel.
    func quoting(record fields: Value.Dictionary) -> Value?
}
