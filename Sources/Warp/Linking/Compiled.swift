//
//  Compiled.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

// What compiling a world answers: every declaration judged and lowered, the
// facts the judgment read off them, and the call graph it gathered on the way.
//
// Everything here is true of the documents alone. Which declaration a run
// starts from is not, so an entry names nothing in this and one world compiled
// once answers every entry asked of it.
struct Compiled: Sendable {
    // MARK: - Property
    // One row per declaration, in name order.
    let table: [Linked]

    // Every declared spelling, by row.
    let rows: [Name: Int]

    // What each declaration calls, by declared spelling. Read off the bodies
    // as they were judged, so what a link walks is what was proved rather
    // than what a second reading of the same text would find.
    let calls: [Name: [Name]]

    let types: TypeTable

    // What each document's variables start a run holding, in the order the
    // layouts read them.
    let variables: [Int: [(name: Name, value: Value)]]

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
