//
//  Handle.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A hold on a variable: the box, and the path into what the box holds. A
// variable declared here is its box whole. A parameter handed a path is the
// caller's box seen through that path, so a read finds what the path holds
// now and a write lands in the box as it is made. Handing a part of a handed
// variable on extends the path; the box stays the same.
struct Handle: Sendable {
    // MARK: - Property
    let box: Variable
    let path: [PathSegment]

    // MARK: - Initializer
    init(_ value: Value) {
        self.box = Variable(value)
        self.path = []
    }

    init(box: Variable, path: [PathSegment]) {
        self.box = box
        self.path = path
    }

    // MARK: - Public
    // What the path holds, under the name it is reached by. The link judged
    // the path against the box's declared shape, so a part not there now is
    // a box whose surroundings changed under the hold.
    func value(under name: String) throws -> Value {
        try box.value.reading(at: path, under: name)
    }

    // Writes the part a path below the hold names, or the whole of it when the
    // path is empty. The box is read once, rewritten, and stored once, so
    // nothing observes the value halfway.
    func write(_ value: Value, at rest: [PathSegment], under rendered: String) throws {
        let whole = path + rest

        guard !whole.isEmpty else {
            box.value = value
            return
        }

        box.value = try box.value.writing(value, at: whole, under: rendered)
    }

    // The same box, held through a longer path.
    func extended(by rest: [PathSegment]) -> Handle {
        Handle(box: box, path: path + rest)
    }

    // MARK: - Private
}
