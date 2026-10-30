//
//  Value+Literal.swift
//  Warp
//
//  Created by JSilver on 8/18/26.
//

import Foundation

// Writing a value in Swift.
//
// Swift's own literals spell the kinds they name, each as exactly one case,
// so this is a spelling and not a conversion. `"a"` is
// `.string("a")` for the same reason `"a"` is a `String`. Nothing here reads
// structure out of a string: a path is still a `Path` and a reference is
// still an `Expression`.
//
// Bytes, a struct and a procedure have no literal. A procedure is made
// by capturing a scope, which happens during a run, so nothing written down
// can name one.
//
// `null` is spelled `.null` and never `nil`. They are not the same fact (`nil`
// is a slot with nothing in it and `.null` is a value a program computed).
extension Value: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension Value: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension Value: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension Value: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension Value: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Value...) {
        self = .array(elements)
    }
}

// Names written in this source are data a host is handing in, so the literal
// makes a dictionary. A duplicate key is a mistake being made twice in one
// literal, and there is no value to return.
extension Value: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (Name, Value)...) {
        self = .dictionary(Swift.Dictionary(elements) { _, _ in
            preconditionFailure("duplicate key in a value literal")
        })
    }
}
