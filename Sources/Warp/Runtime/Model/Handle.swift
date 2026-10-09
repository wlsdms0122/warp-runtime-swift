//
//  Handle.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A hold on a variable: the box, the name the box was declared under, and the
// path into what the box holds. A variable declared here is its box whole. A
// parameter handed a path is the caller's box seen through that path, so a
// read finds what the path holds now and a write lands in the box as it is
// made. Handing a part of a handed variable on extends the path; the box and
// its name stay the same, so a refusal names the variable it is about.
struct Handle: Sendable {
    // MARK: - Property
    let head: Name
    let box: Variable
    let path: [Projection]

    // The variable and the path below it, as a refusal names them.
    var spelled: String {
        rendered(path)
    }

    // MARK: - Initializer
    init(_ head: Name, _ value: Value) {
        self.head = head
        self.box = Variable(value)
        self.path = []
    }

    init(head: Name, box: Variable, path: [Projection]) {
        self.head = head
        self.box = box
        self.path = path
    }

    // MARK: - Public
    // What the path holds. The build judged the path against the box's
    // declared type, so a part not there now is a box whose scope
    // changed under the hold.
    func value() throws -> Value {
        try box.value.reading(at: path, under: spelled)
    }

    // The same, with nil where the path reaches a place nothing holds now.
    func written() throws -> Value? {
        try box.value.written(at: path, under: spelled)
    }

    // Writes the part a path below the hold names. The box is read once,
    // rewritten, and stored once, so nothing observes the value halfway.
    func write(_ value: Value, at rest: [Projection]) throws {
        let whole = path + rest

        box.value = try box.value.writing(value, at: whole, under: rendered(whole))
    }

    // The same box, held through a longer path.
    func extended(by rest: [Projection]) -> Handle {
        Handle(head: head, box: box, path: path + rest)
    }

    // MARK: - Private
    private func rendered(_ path: [Projection]) -> String {
        Path([.key(head)] + path.map(\.spelled)).rendered
    }
}
