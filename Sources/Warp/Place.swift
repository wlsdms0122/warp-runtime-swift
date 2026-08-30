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
// own keys: an author reading
// `procedures.greet.body.total[2].call.arguments.amount` finds every one of
// those words in front of them.
public struct Place: Sendable, Equatable {
    // MARK: - Property
    // Which document the steps are in, by the name that document writes beside
    // its declarations. Not a step: `name` sits next to `procedures` rather
    // than inside it, so no walk down the keys ever passes through it.
    //
    // It is here because a link holds several documents and the steps alone do
    // not say which one — `std.collection` and `std.concurrent` both declare
    // `first`, and a reader handed `procedures.first` with no document would
    // point at whichever `first` it happened to be holding. Nil where the
    // module wrote no name: such a module declares into the link's shared
    // space, where nothing else may declare the same name, so there is nothing
    // to tell apart.
    public let document: String?

    public let steps: [Step]

    // How the place reads in a message: named steps joined with dots, positions
    // bracketed. `Trace` reads by the same two rules, since an author holding
    // one has just read the other — what differs is what gets a bracket. A
    // trace brackets an occurrence, because the text it names ran more than
    // once; a place brackets every statement, because one name in the text may
    // be two statements.
    public var rendered: String {
        let address = steps.enumerated().reduce(into: "") { written, entry in
            let (offset, step) = entry
            // The first step takes no dot: there is nothing to its left but the
            // document's name, which the slash already separates. Read off the
            // position rather than the text written so far — a step's name is
            // whatever a document wrote, slashes included, and asking the text
            // what it is would be reading a string this type keeps steps to
            // avoid having to read.
            let joined = offset == 0

            switch step {
            case let .key(name), let .landmark(name):
                written += joined ? name : ".\(name)"

            case let .index(position):
                written += "[\(position)]"

            // A statement wears both: the name an author knows it by, and
            // the position that tells two statements of one name apart — a
            // `var` and the `set` that writes it are two statements and one
            // name, and a place that dropped the position would call them one.
            case let .statement(name?, position):
                written += (joined ? name : ".\(name)") + "[\(position)]"

            case let .statement(nil, position):
                written += "[\(position)]"
            }
        }

        return (document.map { name in "\(name)/" } ?? "") + address
    }

    // MARK: - Initializer
    public init(_ steps: [Step] = [], in document: String? = nil) {
        self.document = document
        self.steps = steps
    }

    // MARK: - Public
    // The four things a module declares, each under the key the document writes
    // it under — which is what makes a place something an author can follow.
    public static func procedure(_ name: String, in document: String? = nil) -> Place {
        Place([.key("procedures"), .key(name)], in: document)
    }

    public static func constant(_ name: String, in document: String? = nil) -> Place {
        Place([.key("const"), .key(name)], in: document)
    }

    public static func type(_ name: String, in document: String? = nil) -> Place {
        Place([.key("types"), .key(name)], in: document)
    }

    public static func constraint(_ name: String, in document: String? = nil) -> Place {
        Place([.key("constraints"), .key(name)], in: document)
    }

    // A caller holding a program it assembled itself, with no document under
    // it. There is no key to name, so the place says what was handed in.
    public static func given(_ name: String) -> Place { Place([.landmark(name)]) }

    public func key(_ name: String) -> Place { appending(.key(name)) }

    // The slot a part of a program sits in, by the key a document writes it
    // under. Four walks report places into these slots and each destructures
    // the language for itself; spelling the keys here is what keeps them from
    // disagreeing about where one thing is. What a walk cannot be stopped from
    // doing is forgetting a slot, so the suite asks the four of them for the
    // same place and compares.
    public func slot(_ slot: Slot) -> Place { key(slot.rawValue) }

    // What a call is written with. Two steps and not one — a document nests
    // them under a key of their own, and an argument named beside a statement
    // would be a name meaning two things.
    public func argument(_ name: String) -> Place { slot(.arguments).key(name) }

    public func index(_ position: Int) -> Place { appending(.index(position)) }

    // A name with nothing in it is no name — the position is what is left to
    // call the statement by, and a step that rendered an empty name would put
    // a dot in front of nothing.
    public func statement(_ name: String?, at position: Int) -> Place {
        appending(.statement(name: name?.isEmpty == true ? nil : name, at: position))
    }

    // A statement and the construct it writes, which is how every walk reaches
    // what one holds. The construct is a landmark and not a key: it is the word
    // this implementation has for the shape, and two documents that write the
    // shape differently arrive as one shape.
    public func statement(_ statement: Statement, at position: Int) -> Place {
        self.statement(statement.id, at: position)
            .appending(.landmark(statement.expression.constructKey))
    }

    public func appending(_ step: Step) -> Place {
        Place(steps + [step], in: document)
    }

    // MARK: - Private
}

public extension Place {
    // Every slot a document names, under the key it names it with. The
    // spellings differ from the model's own names — a loop's condition is
    // `where` and a walk's collection is `in` — and it is the document's that
    // an author is reading.
    enum Slot: String, Sendable {
        case parameters
        case returns
        case body
        case result

        case of
        case procedure
        case arguments
        case closure

        case when
        case then
        case otherwise = "else"
        case condition = "where"
        case material = "in"
        case rescue
    }

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
        // a person looks for, and the position is what finds it — the name
        // alone finds nothing when a `var` and the `set` writing it share one.
        case statement(name: String?, at: Int)

        // A word the language chose, where the document's own is not known: a
        // statement's construct, which two texts spell two ways and one shape
        // arrives as; a body a caller assembled and handed over, which has no
        // document under it to have a key in. It renders like a key on purpose,
        // since a person reading a line wants a line — what tells the two apart
        // is this case, for the reader that has to know which of the words it
        // may look for in a file.
        case landmark(String)
    }
}

extension Place: CustomStringConvertible {
    public var description: String { rendered }
}
