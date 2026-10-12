//
//  ExpressionSpelling.swift
//  WarpSyntax
//
//  Created by JSilver on 9/22/26.
//

import Foundation
import Warp

// How a notation writes an expression specially, for a notation that writes
// one. In a document a value slot holds an expression: a literal, a reference,
// a call, a cast, a closure, a struct, a map or an array of these. Everything
// else a slot is written as is a notation's: the mapping of an operator key and
// its subject, which keys count as operators, whether one takes its expression
// directly, which procedure each reaches, and which side of the send the
// subject lands on.
//
// A spelling is read wherever an expression is: a condition under `when`, an
// operand of a call, an element of an array, so a reader here spends a
// spelling it was never told about by name, and a document, read with no
// notation at all, has nothing to spend. It is a reader because spending one
// is a reading: a connective holds expressions, read the same way
// recursively, and the pieces report where they are through the same coding
// path everything else does.
public protocol ExpressionSpelling: Sendable {
    // Whether a mapping with these keys is one of this notation's spellings.
    // A mapping it does not claim is read as the expression it is, which is
    // what keeps these spellings optional wherever an expression is asked
    // for, and a mapping it claims is answered by this spelling or refused by
    // it. Giving up a spelling says a document may not write it; it does not
    // hand the keys back to mean something else, which would make the same
    // document mean two things in two notations.
    //
    // Asked of the names and the notation they are read in, since what a
    // text declares is the notation's to know.
    func claims(_ names: Set<Name>, in notation: Notation) -> Bool

    // Procedures these spellings reach, which a link has to declare for them to
    // reach anything. A slot spends them on the notation's behalf.
    var vocabulary: Set<Name> { get }

    // The expression a mapping spells, read in the notation that claimed it.
    // Reached only for a mapping this notation claims that is not a tag's, and
    // free to refuse. A key this notation names but does not offer is refused
    // here, and so is one written in a form it does not have.
    func expression(from decoder: Decoder, in notation: Notation) throws -> Warp.Expression
}
