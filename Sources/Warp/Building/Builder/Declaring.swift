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
    var types: [Name: TypeExpression] { get }
    var constraints: [Name: [TypeExpression]] { get }
    var contracts: [Name: [Name: ContractProcedure]] { get }

    // Which contracts this document says each type answers. Not a type table
    // and gathered apart from the three: it declares no name, it says
    // something about two that are declared elsewhere.
    var claims: [Name: Set<Name>] { get }
}
