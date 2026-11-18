//
//  Identity+Document.swift
//  WarpSyntax
//
//  Created by JSilver on 8/31/26.
//

import Foundation
import Warp

// Working out which document a document is: the digest of its one canonical
// binary writing, so a second implementation gets identity right by getting
// the wire right. It is a function of the document and of everything inside
// it, down to the order of an array, and of nothing outside it: text in and
// bytes in give the same digest, since both are read into the same tree before
// anything is hashed. Whoever wrote a document and whoever received it hash
// the same tree, so a document rewritten on the way is another document to
// this.
public extension Identity {
    // Worked out from the document every time it is wanted, and stored
    // nowhere.
    static func of(_ document: Value) throws -> Identity {
        Identity(SHA256().digest(of: try BinaryEncoding().data(from: document)))
    }
}
