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
    // Which document the steps are in. Not a step: `name` sits next to
    // `procedures` rather than inside it, so no walk down the keys passes
    // through it.
    //
    // It is here because a link holds several documents and the steps alone do
    // not say which one — `std.collection` and `std.concurrent` both declare
    // `first`, and a reader handed `procedures.first` with no document would
    // point at whichever `first` it happened to be holding.
    public let document: Document

    public let steps: [Step]

    // How the place reads in a message: named steps joined with dots, positions
    // bracketed. `Trace` reads by the same two rules, since an author holding
    // one has just read the other — what differs is what gets a bracket. A
    // trace brackets an occurrence, because the text it names ran more than
    // once; a place brackets every statement, because one name in the text may
    // be two statements.
    // Nothing where there is nothing to say. A place in no document at no step
    // is what a caller holding a body it assembled has, and spelling it as ""
    // would fold an absence into a string every reader then has to unfold
    // again — the same absence `Document` keeps as an absence one field over.
    //
    // The only way to read a place as text, for the same reason. A
    // `description` would have to answer something for a place that says
    // nothing, and "" is the string this deliberately does not return.
    public var rendered: String? {
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

        let named = document.rendered

        // The slash separates the document from an address inside it, so it is
        // written where there are both. What is refused about a document rather
        // than about anything in it has no steps, and the document alone is the
        // whole answer.
        guard let named else { return address.isEmpty ? nil : address }
        guard !address.isEmpty else { return named }

        return "\(named)/\(address)"
    }

    // MARK: - Initializer
    // The document is stated and never defaulted, for the reason a refusal's
    // place is: a caller that says nothing gets the one state nothing can be
    // read for, and a place that meant to say which text it was in would look
    // like a program that was never written down.
    public init(_ steps: [Step] = [], in document: Document) {
        self.document = document
        self.steps = steps
    }

    // MARK: - Public
    // The four things a module declares, each under the key the document writes
    // it under — which is what makes a place something an author can follow.
    // Which document is stated and never defaulted, so that a caller meaning to
    // say which text it was in cannot get "none" by saying nothing.
    public static func procedure(_ name: String, in document: Document) -> Place {
        Place([.key("procedures"), .key(name)], in: document)
    }

    public static func constant(_ name: String, in document: Document) -> Place {
        Place([.key("const"), .key(name)], in: document)
    }

    public static func type(_ name: String, in document: Document) -> Place {
        Place([.key("types"), .key(name)], in: document)
    }

    public static func constraint(_ name: String, in document: Document) -> Place {
        Place([.key("constraints"), .key(name)], in: document)
    }

    // A caller holding a program it assembled itself, with no document under
    // it. There is no key to name, so the place says what was handed in — and
    // no document either, which is a third thing and not a module that wrote
    // no name.
    public static func given(_ name: String) -> Place {
        Place([.landmark(name)], in: .assembled)
    }

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
        appending(.statement(name, at: position))
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
    // Which document a place is an address in, and what that document's module
    // calls itself.
    //
    // Two facts and not one, because they answer to different things. A
    // document is told from another by what it says — `name` is the namespace a
    // module declares into, several documents may share one, and a document may
    // write none — so identifying by the name would answer a refusal in one
    // half of a split module with the other half's line. And a module a caller
    // built has a namespace and no text at all, so folding the two together
    // would take the namespace out of every refusal about one.
    struct Document: Sendable, Equatable {
        // Which text this is. Nil where the program was never written down —
        // a caller that built it in memory — and that is the whole of what nil
        // means here: there is no file for a reader to be pointed back into.
        public let identity: Identity?

        // What the module calls itself. Carried beside the identity and never
        // instead of it: a name is the namespace a module declares into, two
        // documents may share one, and a module a caller built has a name and
        // no text. A person reading a refusal wants the word they typed, which
        // is the whole of what this is for.
        public let namespace: String?

        // A program nobody wrote down and nobody named, which is what a caller
        // holding a body it assembled has. Spelled out rather than left to a
        // default, so that a place meaning to say which text it is in cannot
        // get this one by saying nothing.
        public static let assembled = Document(identity: nil, namespace: nil)

        // A namespace written empty is no namespace. The rule is here and not
        // at whoever is assembling one, because a place is assembled at every
        // stage: what is read from a document before it is judged, what a
        // validated module says it is called, what a caller hands in. Three
        // sites keeping one rule is three chances to spell one document two
        // ways, and which document a refusal is about is the one thing a place
        // exists to answer.
        public init(identity: Identity?, namespace: String?) {
            self.identity = identity
            self.namespace = namespace?.isEmpty == true ? nil : namespace
        }

        public static func of(_ module: Module) -> Document {
            Document(identity: module.identity, namespace: module.name)
        }

        // How the document reads on its own, which is both halves where there
        // are both. A person reading a refusal wants the word they typed, and
        // the word alone does not tell two documents apart — two halves of a
        // module split across files write one name between them, which is the
        // case this exists to keep separate. Showing the name and hiding what
        // makes it unambiguous would put that case back in front of the only
        // reader who cannot check it.
        //
        // Absence stays absence rather than folding into an empty string and
        // being read back out of one: a document that wrote its name as nothing
        // would otherwise spell the same as a program nobody wrote down.
        var rendered: String? {
            switch (namespace, identity) {
            case let (namespace?, identity?): "\(namespace)@\(identity.short)"
            case let (namespace?, nil): namespace
            case let (nil, identity?): identity.short
            case (nil, nil): nil
            }
        }

        // What a sentence calls this document when it names one among several.
        //
        // An identity tells one document from every other, so where there is
        // one nothing else is needed. Without one there is only the name, and
        // two modules a caller built may write the same name or no name at all
        // — so where the caller put it goes on as well. The caller counts its
        // own modules, in the order it handed them over.
        func spelled(at origin: Int) -> String {
            if identity != nil, let rendered { return rendered }

            let position = "the module at \(origin) in this link"

            return namespace.map { namespace in "\(namespace), \(position)" } ?? position
        }
    }

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

        // A statement step, with a name written empty read as no name.
        //
        // The rule is on the case rather than beside each caller: a step
        // rendering an empty name puts a dot in front of nothing, and every
        // stage that spells a statement — reading a document, validating a
        // module, linking one — makes this step from a name it did not write.
        public static func statement(_ name: String?, at position: Int) -> Step {
            .statement(name: name?.isEmpty == true ? nil : name, at: position)
        }
    }
}
