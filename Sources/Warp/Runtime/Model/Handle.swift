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

    // The type the value at the path is held beside, where the hold reads
    // and writes the value held rather than the two together.
    let held: LoweredType?

    // The variable and the path below it, as a refusal names them.
    var spelled: String {
        rendered(path)
    }

    // MARK: - Initializer
    init(_ head: Name, _ value: Value) {
        self.head = head
        self.box = Variable(value)
        self.path = []
        self.held = nil
    }

    init(head: Name, box: Variable, path: [Projection], held: LoweredType? = nil) {
        self.head = head
        self.box = box
        self.path = path
        self.held = held
    }

    // MARK: - Public
    // What the path holds. The build judged the path against the box's
    // declared type, so a part not there now is a box whose scope
    // changed under the hold. A path handed in place marks no step.
    func value() throws -> Value {
        var current = box.value

        for (index, projection) in path.enumerated() {
            let walked = { Path([.name(head)] + path[...index].map(\.spelled)) }

            switch projection.part(of: current, as: { projection.spelled }, walked: walked) {
            case let .found(part):
                current = part

            case let .unfit(reason):
                throw ExecutionError(reason)
            }
        }

        return held == nil ? current : current.opened
    }

    // Writes the part a path below the hold names. The box is read once,
    // rewritten, and stored once, so nothing observes the value halfway. A
    // whole value written where one is held beside a type is held beside it
    // again.
    func write(_ value: Value, at rest: [Projection]) throws {
        let whole = path + rest
        let written = if let held, rest.isEmpty { Value.existential(Existential(value, as: held)) } else { value }

        box.value = try box.value.writing(written, at: whole, under: rendered(whole))
    }

    // The same box, held through a longer path. A step below a value held
    // beside a type reaches into the value.
    func extended(by rest: [Projection]) -> Handle {
        Handle(head: head, box: box, path: path + rest, held: rest.isEmpty ? held : nil)
    }

    // The same box, read and written as the value held beside `type` at the
    // path.
    func opened(as type: LoweredType) -> Handle {
        Handle(head: head, box: box, path: path, held: type)
    }

    // MARK: - Private
    private func rendered(_ path: [Projection]) -> String {
        Path([.name(head)] + path.map(\.spelled)).rendered
    }
}
