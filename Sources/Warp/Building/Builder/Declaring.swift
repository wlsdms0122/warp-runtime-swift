//
//  Declaring.swift
//  Warp
//
//  Created by JSilver on 9/9/26.
//

import Foundation

// What a document declares in the type tables, and which document it is.
//
// A module says it and so does a document already compiled, and a link gathers
// either the same way: it holds the names to being declared once and lays the
// declarations down in the order the documents stand. Which of the two it was
// handed is the difference between compiling a graph and linking one that is
// already compiled, and nothing about the gathering turns on it.
protocol Declaring {
    var document: Place.Document { get }
    var types: [Name: TypeDeclaration] { get }
    var contracts: [Name: [Name: ContractProcedure]] { get }

    // Which contracts this document says each type answers, by the head it
    // says so under. Not a type table
    // and gathered apart from the two: it declares no name, it says something
    // about a type, declared elsewhere or named by the language, and a
    // contract declared elsewhere.
    var claims: [Head: Set<Name>] { get }

    // The procedures this document gives each type, by the head it gives
    // them under. What answers a contract's procedure for a type is the
    // type's member of that name, given within what the claim's document
    // stands on.
    var members: [Head: Set<Name>] { get }

    // The claims other documents make that this one stands on.
    var importedClaims: Set<ClaimPair> { get }
}
