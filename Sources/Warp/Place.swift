//
//  Place.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// Where in a document something was written.
//
// A refusal that names no place sends the author searching the whole document,
// so every stage that reads a document before running it carries one. It is the
// text's answer to what `Trace` answers about a run: this says where the words
// are, that says where the run had been, and a stage that refuses before
// anything runs has only the first to give.
//
// The steps are kept rather than a string assembled from them, because a place
// has two readers who want different things. A person wants a line to read. A
// front end wants to point at the file the author actually typed — and to do
// that it has to know which parts of the place are keys the document writes and
// which are names the language gave to something the text left unnamed. A
// string spells both the same way and neither can be recovered from it.
//
// So the steps say what the document says, and are spelled from the document's
// own keys: an author reading `procedures.greet.body.total.call.arguments.amount`
// finds every one of those words in front of them.
public struct Place: Sendable, Equatable {
    // MARK: - Property
    public let steps: [Step]

    // How the place reads in a message. Named steps are joined with dots and
    // positions are bracketed — the same spelling `Trace` uses, since an author
    // reading one has just read the other.
    public var rendered: String {
        steps.reduce(into: "") { written, step in
            switch step {
            case let .key(name), let .landmark(name):
                written += written.isEmpty ? name : ".\(name)"

            case let .index(position):
                written += "[\(position)]"

            case let .statement(name?, _):
                written += written.isEmpty ? name : ".\(name)"

            case let .statement(nil, position):
                written += "[\(position)]"
            }
        }
    }

    // MARK: - Initializer
    public init(_ steps: [Step] = []) {
        self.steps = steps
    }

    // MARK: - Public
    // The four things a module declares, each under the key the document writes
    // it under — which is what makes a place something an author can follow.
    public static func procedure(_ name: String) -> Place { Place([.key("procedures"), .key(name)]) }

    public static func constant(_ name: String) -> Place { Place([.key("const"), .key(name)]) }

    public static func type(_ name: String) -> Place { Place([.key("types"), .key(name)]) }

    public static func constraint(_ name: String) -> Place { Place([.key("constraints"), .key(name)]) }

    // A caller holding a program it assembled itself, with no document under
    // it. There is no key to name, so the place says what was handed in.
    public static func given(_ name: String) -> Place { Place([.landmark(name)]) }

    public func key(_ name: String) -> Place { appending(.key(name)) }

    public func index(_ position: Int) -> Place { appending(.index(position)) }

    // A name with nothing in it is no name — the position is what is left to
    // call the statement by, and a step that rendered an empty name would put
    // a dot in front of nothing.
    public func statement(_ name: String?, at position: Int) -> Place {
        appending(.statement(name: name?.isEmpty == true ? nil : name, at: position))
    }

    public func landmark(_ name: String) -> Place { appending(.landmark(name)) }

    public func appending(_ step: Step) -> Place {
        Place(steps + [step])
    }

    // MARK: - Private
}

public extension Place {
    // What one step of a place is. The cases divide on who chose the word,
    // because that is the division a reader that maps a place back to a file
    // has to make.
    enum Step: Sendable, Equatable {
        // A key the document itself writes.
        case key(String)

        // A position in an array the document writes.
        case index(Int)

        // A statement, which a document writes as an array element and an
        // author knows by the name it fixes. Both are carried: the name is what
        // a person looks for, and the position is what finds it when there is
        // no name to look for.
        case statement(name: String?, at: Int)

        // Somewhere the document gives no key — what a construct binds, or a
        // body a caller handed over without one. It renders like a key on
        // purpose, since a person reading a line wants a line; what tells the
        // two apart is this case, for the reader that needs them apart.
        case landmark(String)
    }
}

extension Place: CustomStringConvertible {
    public var description: String { rendered }
}
