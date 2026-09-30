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
// text's answer to what `Trace` answers about a run: this says where the procedures
// are, that says where the run had been, and a stage that refuses before
// anything runs has only the first to give.
//
// The steps are kept rather than a string assembled from them, because a place
// is read at more than one level and each spells it for its own reader. A part
// and a construct travel as themselves; the names an author gave things travel
// as the spellings they typed. A string spells both the same way and neither can be
// recovered from it.
//
// What is spelled here is the language's own reading, which is the one a caller
// holding a program it assembled in Swift is owed. It wrote no document, so no
// document's keys would lead it anywhere. A reading in a document's keys is
// the reading side's, and a reading in lines and columns is the front end's.
public struct Place: Sendable, Equatable {
    // Which document a place is an address in.
    public struct Document: Sendable, Equatable {
        // MARK: - Property
        // Which text this is. Nil where the program was never written down (a
        // caller that built it in memory) and that is the whole of what nil
        // means here: there is no file for a reader to be pointed back into.
        public let identity: Identity?

        // A program nobody wrote down, which is what a caller holding a body it
        // assembled has. Spelled out rather than left to a default, so that a
        // place meaning to say which text it is in cannot get this one by
        // saying nothing.
        public static let assembled = Document(identity: nil)

        // How the document reads on its own. An identity tells one document
        // from every other in a link, since a link refuses the same one twice.
        var rendered: String? {
            identity?.short
        }

        // MARK: - Initializer
        public init(identity: Identity?) {
            self.identity = identity
        }

        // MARK: - Public
        public static func of(_ module: Module) -> Document {
            Document(identity: module.identity)
        }

        // What a sentence calls this document when it names one among several.
        // Without an identity there is only where the caller put it: the
        // caller counts its own modules, in the order it handed them over.
        func spelled(at origin: Int) -> String {
            rendered ?? "the module at \(origin) in this link"
        }

        // MARK: - Private
    }

    // Every part a program has, by the language's own name for it. A part is
    // where something sits in the structure of a program; the boundary's `Slot` is
    // what a call fills, and the two are named apart because they are two
    // things. No spelling rides along: what a document writes a part under is
    // the reading side's, and a procedure declared in two places is a procedure the two
    // can come to disagree about with nothing going wrong loudly enough to
    // notice.
    //
    // One case per part and not per key. A conditional and a loop both hold a
    // condition; that a document writes the two under different keys is a fact
    // about the document.
    public enum Part: Sendable, Equatable {
        case procedures
        case constants
        case variables
        case types
        case constraints
        case contracts
        case satisfies
        case imports

        case parameters
        case returns
        case body
        case result

        // What a cast reads, and whether the cast reads a mismatch as null,
        // which a document writes under a key of its own.
        case subject(optional: Bool)
        case callee
        case arguments
        case closure

        // What a record is written with: its fields, each under its name.
        case fields

        // A condition, and which construct holds it. The construct is carried
        // because a document does not write the two under one key (a
        // conditional asks `when` and a loop asks `while`) and a part that had
        // to be told by whatever step came before it is a part that can be
        // reached from somewhere nobody remembered to tell.
        //
        // Only what can hold one, so a side spelling this has nothing to
        // guess at and a construct added later cannot be spelled by a default
        // arm that nobody looked at.
        case condition(of: ConditionHolder)
        case then
        case otherwise
        case rescue

        // MARK: - Property
        // What the language calls this part.
        var rendered: String {
            switch self {
            case .procedures: "procedures"
            case .constants: "constants"
            case .variables: "variables"
            case .types: "types"
            case .constraints: "constraints"
            case .contracts: "contracts"
            case .satisfies: "satisfies"
            case .imports: "imports"
            case .parameters: "parameters"
            case .returns: "returns"
            case .body: "body"
            case .result: "result"
            case .subject: "subject"
            case .fields: "fields"
            case .callee: "callee"
            case .arguments: "arguments"
            case .closure: "closure"
            case .condition: "condition"
            case .then: "then"
            case .otherwise: "otherwise"
            case .rescue: "rescue"
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // A construct that holds a condition. Two of them, and a third would be a
    // third here, which is the point: whoever spells a condition for a document
    // is asked about every one of these by name.
    public enum ConditionHolder: Sendable, Equatable {
        case conditional
        case loop
    }

    // What one step of a place is. The cases divide on who chose the procedure,
    // because that is the division a reader that maps a place back to a file
    // has to make.
    public enum Step: Sendable, Equatable {
        // A name the document itself writes: a procedure's, a field's, an
        // argument's. The author typed it, so it is carried as it was typed.
        case key(String)

        // A part of the program, which every side names for itself. Carried as
        // the part and not as a spelling, so the side spelling it is the side that
        // knows what its reader is looking at.
        case part(Part)

        // The type a statement writes, carried the same way and for the same
        // reason: two texts spelling one type two ways arrive as one type.
        case construct(Construct)

        // A position in an array the document writes.
        case index(Int)

        // A statement, which a document writes as an array element and an
        // author knows by the name it fixes. Both are carried: the name is what
        // a person looks for, and the position is what finds it. The name alone
        // finds nothing when a `var` and the `set` writing it share one.
        case statement(name: String?, at: Int)

        // A body a caller assembled and handed over, which has no document
        // under it to have a key in. It renders like a key on purpose, since a
        // person reading a line wants a line. What tells the two apart is this
        // case, for the reader that has to know which of the procedures it may look
        // for in a file.
        case landmark(String)

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        // A statement step, with a name written empty read as no name.
        //
        // The rule is on the case rather than beside each caller: a step
        // rendering an empty name puts a dot in front of nothing, and every
        // stage that spells a statement (reading a document, validating a
        // module, linking one) makes this step from a name it did not write.
        public static func statement(_ name: String?, at position: Int) -> Step {
            .statement(name: name?.isEmpty == true ? nil : name, at: position)
        }

        // MARK: - Private
    }

    // MARK: - Property
    // Which document the steps are in. A declared spelling is unique across a
    // link, so steps that reach a declaration already say which one; what
    // only this answers is a refusal about a document as a whole, where the
    // steps are empty, and a program a caller assembled, which no steps in
    // any text lead to.
    public let document: Document

    public let steps: [Step]

    // How the place reads in a message: named steps joined with dots, positions
    // bracketed. `Trace` reads by the same two rules, since an author holding
    // one has just read the other. What differs is what gets a bracket. A trace
    // brackets an occurrence, because the text it names ran more than once; a
    // place brackets every statement, because one name in the text may be two
    // statements. Nothing where there is nothing to say. A place in no document
    // at no step is what a caller holding a body it assembled has, and spelling
    // it as "" would fold an absence into a string every reader then has to
    // unfold again. The same absence `Document` keeps as an absence one field
    // over.
    //
    // The only way to read a place as text, for the same reason. A
    // `description` would have to answer something for a place that says
    // nothing, and "" is the string this deliberately does not return.
    public var rendered: String? {
        let address = steps.enumerated().reduce(into: "") { written, entry in
            let (offset, step) = entry
            // The first step takes no dot: there is nothing to its left but the
            // document's name, which the slash already separates. Read off the
            // position rather than the text written so far. A step's name is
            // whatever a document wrote, slashes included, and asking the text
            // what it is would be reading a string this type keeps steps to
            // avoid having to read.
            let joined = offset == 0

            switch step {
            case let .key(name), let .landmark(name):
                written += joined ? name : ".\(name)"

            case let .part(part):
                written += joined ? part.rendered : ".\(part.rendered)"

            case let .construct(construct):
                written += joined ? construct.rendered : ".\(construct.rendered)"

            case let .index(position):
                written += "[\(position)]"

            // A statement wears both: the name an author knows it by, and the
            // position that tells two statements of one name apart. A `var` and
            // the `set` that writes it are two statements and one name, and a
            // place that dropped the position would call them one.
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
    // The four things a module declares, each in the part that holds it and
    // then under the name the author gave it. Which document is stated and
    // never defaulted, so that a caller meaning to say which text it was in
    // cannot get "none" by saying nothing.
    public static func procedure(_ name: String, in document: Document) -> Place {
        Place([.part(.procedures), .key(name)], in: document)
    }

    public static func constant(_ name: String, in document: Document) -> Place {
        Place([.part(.constants), .key(name)], in: document)
    }

    public static func variable(_ name: String, in document: Document) -> Place {
        Place([.part(.variables), .key(name)], in: document)
    }

    public static func type(_ name: String, in document: Document) -> Place {
        Place([.part(.types), .key(name)], in: document)
    }

    public static func constraint(_ name: String, in document: Document) -> Place {
        Place([.part(.constraints), .key(name)], in: document)
    }

    public static func contract(_ name: String, in document: Document) -> Place {
        Place([.part(.contracts), .key(name)], in: document)
    }

    // A claim that one type answers some contracts, under the name of the
    // type. What is refused about one is refused about the type it is about,
    // which is the key an author wrote it under.
    public static func satisfies(_ name: String, in document: Document) -> Place {
        Place([.part(.satisfies), .key(name)], in: document)
    }

    // A caller holding a program it assembled itself, with no document under
    // it. There is no key to name, so the place says what was handed in, and no
    // document either, which is a third thing and not a module that wrote no
    // name.
    public static func given(_ name: String) -> Place {
        Place([.landmark(name)], in: .assembled)
    }

    public func key(_ name: String) -> Place { appending(.key(name)) }

    // The part of a program something sits in. Four walks report places into
    // these parts and each destructures the language for itself; naming the
    // parts here is what keeps them from disagreeing about where one thing is.
    // What a walk cannot be stopped from doing is forgetting one, so the suite
    // asks the four of them for the same place and compares.
    public func part(_ part: Part) -> Place { appending(.part(part)) }

    // What a call is written with. Two steps and not one: a document nests them
    // under a key of their own.
    public func argument(_ position: Int) -> Place { part(.arguments).index(position) }

    public func index(_ position: Int) -> Place { appending(.index(position)) }

    // A name with nothing in it is no name. The position is what is left to
    // call the statement by, and a step that rendered an empty name would put a
    // dot in front of nothing.
    public func statement(_ name: String?, at position: Int) -> Place {
        appending(.statement(name, at: position))
    }

    // A statement and the construct it writes, which is how every walk reaches
    // what one holds.
    public func statement(_ statement: Statement, at position: Int) -> Place {
        self.statement(statement.name?.spelling, at: position)
            .appending(.construct(statement.expression.construct))
    }

    public func appending(_ step: Step) -> Place {
        Place(steps + [step], in: document)
    }

    // MARK: - Private
}
