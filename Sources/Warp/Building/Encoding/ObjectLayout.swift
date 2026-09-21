//
//  ObjectLayout.swift
//  Warp
//
//  Created by JSilver on 9/20/26.
//

import Foundation

// How an object is laid out as a value: the format under *objects* in the
// specification, the key it is said under, and the keys the record carries.
// What the writer lays down and the reader holds a record to, said once.
enum ObjectLayout {
    // The format, which moves when the layout moves and for no other reason.
    // Which Warp wrote an object is not written, because what an object holds
    // is the language's and any implementation of it reads any other's.
    static let format = 2

    // The key an object says its format under, which is also what tells an
    // object from a document at the door: a document says `warp`.
    static let formatKey: Name = "object"

    // Every key an object carries, the format key among them, which a reading
    // holds a record to before it takes any.
    static let parts: Set<Name> = [
        formatKey, "document", "dependencies", "types", "constraints", "contracts", "claims", "leaned",
        "rows", "lifted", "answers", "numbering", "typeNumbering", "variables", "constants"
    ]
}
