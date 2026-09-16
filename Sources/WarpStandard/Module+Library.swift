//
//  Module+Library.swift
//  WarpStandard
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Warp
import WarpSyntax

public extension Module {
    // The vocabulary written in Warp rather than in Swift, read from the
    // documents of `lib/std`.
    //
    // A plain Warp module with no standing of its own: a caller that brings a
    // procedure of its own under one of these names links that one instead.
    // What it saves is every implementation writing these again, and it is
    // here rather than on a disk so that taking this library is the whole of
    // taking the vocabulary.
    //
    // The force is the same one the bundles written in Swift take: there is no
    // caller to hand a refusal to, and a document shipped with the language
    // that will not read is a bug in the language.
    static let library: [Module] = Library.documents
        .sorted { one, other in one.key < other.key }
        .map { _, text in
            try! Loader().load(try! TextEncoding.value(from: text), identity: nil)
        }
}
