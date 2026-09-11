# warp-runtime-swift

The Swift runtime for [Warp](../../spec/README.md). It reads documents, checks
and links them before anything runs, runs them under a caller that can always
stop them, and brings the host's vocabulary. What the language *is* lives in
the specification; this package is one implementation of it.

A program can also be built directly as Swift values (`Module`, `Procedure`,
`Statement`, `Expression`) and never touch a document. That is what a program
that stays where it was built looks like.

```swift
import Warp

let greet = Procedure(
    signature: Signature(
        parameters: ["name": Parameter(type: .string)],
        returns: .string
    ),
    body: [
        Statement(
            binding: .constant("greeting"),
            expression: .dispatch(
                Dispatch(
                    receiver: .array([
                        .literal(.string("hello, ")),
                        .dispatch(
                            Dispatch(receiver: .reference([.key("name")]), selector: "text")
                        )
                    ]),
                    selector: "joined"
                )
            )
        )
    ],
    result: .reference([.key("greeting")])
)

let image = try Builder().build(
    [try Module(procedures: ["hello.greet": greet])] + Module.standard,
    entry: "hello.greet"
)

let value = try await Executor().run(
    image,
    arguments: ["name": .string("warp")]
)

// value == .string("hello, warp")
```

## The products

| product | what | depends on |
|---|---|---|
| `Warp` | the shapes, checking, linking, running, and the standard vocabulary | nothing |
| `WarpSyntax` | a document: the bytes and text one is carried in, read into shapes and written back out | `Warp` |

The arrow is the architecture, and it is the one line worth cutting on: what a
caller can leave out. A caller that reads bytes needs all of this, and a caller
assembling shapes in Swift needs none of it, so `WarpSyntax` is optional in the
honest sense, and a program that never travels never links it.

Inside it the wire is still written and read without learning what the tree
means, which is why an implementation in another language can speak the format
without also implementing what a procedure is.

## An arriving program

```swift
import Warp
import WarpSyntax

let document = try BinaryEncoding.value(from: bytes)   // bytes → tree, or refused
let module = try Loader().load(                        // tree → module, or refused
    document,
    identity: try Identity.of(document)                // which document, for refusals
)
let image = try Builder().build([module] + Module.standard, entry: "entry")
let answer = try await Executor().run(image)
```

Each step refuses rather than guesses, and everything refusable is refused
while nothing has run, including the branches this run would not have taken.
The stages and what each one checks are the specification's, not this file's.

## Compiling and linking

The specification names three stages a refusal can come from: `load`, `build`
and `run`. `load` is `Loader` and `run` is `Executor`. The middle one is
`Builder`, and a build is compiling and linking, the same two an ordinary
toolchain has.

| | what it answers | what varies |
|---|---|---|
| compile | every declaration judged and lowered, and the call graph read off it | the modules |
| link | one table a run reads, walked from a named entry | the entry |

The line between them is the numbering. **A lowered body carries the numbers
its own document gave**, so what a document lowers to is the same text in every
link, and resolving those numbers to rows of a table is the link's work. That is
why one compile answers every entry asked of it: which declaration a run starts
from is not a fact about the documents.

`Builder` has a door for each: `build(_ modules:entry:)` is the two together,
and `compile(_ modules:)` and `link(_ compiled:entry:supplying:)` are the
halves, for a caller holding what one compile answered. Compiling takes the
whole set of modules at once, and the table a compile is read against is its
own.

`Loader` reads the canonical document and nothing else by default. Which
construct words exist is a `ConstructRegistry`; a host may register its own
forms. A front end may also hand over a `Notation`. Its own condition
spelling and its own template words, and no table of either is shipped here:
a document has no spellings, so this package names none. The wire never carries
one.

`Writer` is the way back out: a program that was *built* rather than read has
no document to hand to anything running elsewhere, and this is how it gets one.

Whatever refuses somewhere says where. A refusal from the stages that read a
program before running it carries a `Place`, the path to it through the program,
and each side reads that path for the reader it has. The language names its own
slots, which is what a caller that built the shapes in Swift can follow.
`Loader.reading { }` reads the same place in the keys the document writes, so
`procedures.greet.body.total[2].call.arguments.amount` is a line every word of
which an author can follow in the text in front of them.

It is steps rather than a sentence because a front end holding the file this was
authored in has to walk them to point at the line, and only the front end knows
that file: what crossed the wire is the document. So a step says how it was got.
A `key` is a word the document itself writes, and a reader may go looking for
one in the text. A `landmark` is this implementation's word for a shape the
document does not name on its own, since `{ call: … }` and
`{ value: { call: … } }` arrive here as one.

A refusal from a run carries a `Trace` instead: where the run had been, which is
the other question.

A declaration's name is its key. A link calls a declaration `wallet.entry`
because `wallet.entry` is the key the document wrote under `procedures`, dot
and all. So a place reads `0da2e372bba7/procedures.wallet.entry.body.sent[0].call`,
and the part before the slash is the only part that is not a key.

**Which document a place is in is an `Identity`, and never a name.** A link
holds several documents and the steps alone do not say which.
`std.collection.first` and `wallet.first` are two declarations that may sit in
two documents or in one. Nothing a document says about itself can settle it:
what a document writes is declarations, and a program split across files
declares spellings under one prefix from several documents. So identity is
derived from the document itself. The digest of its canonical bytes, worked out
by `WarpSyntax` and never written down by anybody. Nothing to declare means
nothing to declare wrongly, and two callers holding one document arrive at one
answer without having agreed on anything.

`Module.identity` is nil for a module a caller built, and that is the whole of
what nil means: nothing was written down, so there is no text to be pointed
back into. A reader says which document it is reading, and says it going in:

```swift
let module = try Loader().load(document, identity: try Identity.of(document))
```

Going in rather than on the way out, because a refusal is exactly the moment
somebody wants the file it came from. A module stamped afterwards would be
stamped only when nothing was wrong with it.

A place reads `0da2e372bba7/procedures.wallet.charge…`: the part before the
slash is `identity.short`, the first twelve hex digits of the identity, and
the steps after it are the document's own keys, the declared spelling among
them. The side that handed the bytes in is the one that knows which file an
identity came from, and it is the side that says so to a person.

Whether a place has a text under it at all is `document.identity != nil`, and
nothing to do with the name. A
place from a program nobody wrote down says `assembled` rather than `none`,
since `Optional.none` answers to that spelling too and `document == .none`
would read true for a place that does not exist.

Not every refusal has a place, and the ones that do not say so: two modules
declaring one name is two places and an entry nobody declares is none, so those
carry `nil`. Written out at the call, because the initializer takes no default
and a place nobody carried would otherwise look like a place that does not
exist. What a notation refuses while reading a document is not placed this way
yet.

## Vocabulary: the boundary to the outside

A word is a procedure whose implementation is native. `Query` answers without
running; `Effect` answers by running. Everything a program can do to the world
goes through a word the host declared, which is what makes the host's
vocabulary the bounds of an arriving program.

```swift
struct ShoutQuery: Query {
    func evaluate(_ question: Question) throws -> Value? {
        guard case let .string(text) = question.receiver else { return nil }

        return .string(text.uppercased())
    }
}

let vocabulary = Module(
    procedures: [
        "app.shout": Procedure(
            signature: Signature(
                receiver: "of",
                parameters: ["of": Parameter(type: .string)],
                returns: .string
            ),
            implementation: .query(ShoutQuery())
        )
    ]
)
```

Link it beside `Module.standard` and a document may send `app.shout`, and a
document that sends a word nobody linked is refused by name before anything
runs. The standard vocabulary ships the same way: bundles a caller takes what
it wants from, no second name table and no second lookup order.

## Stopping and watching

A run can always be stopped from outside. Cancellation is observed between
statements and at the entry of every round. Nothing is bounded from inside: no
fan-out cap, no recursion depth, no iteration limit a program did not write
itself (`loop`'s `guard` is the author bounding their own program). Runaway
work is watched through `ExecutionObserver` and stopped by cancelling the
task, which is the one promise the language makes about consumption.

## Conformance

`WarpConformanceTests` runs the cases in [`spec/conformance/`](../../spec/conformance)
through public API only. A runner that could see inside could pass by agreeing
with the implementation rather than with the specification, which is the one
thing it must not do.

## Status

Settled enough to write in, not settled enough to be stable. Everything above
is implemented and tested; what the language *does* is asked by the
specification's cases rather than by anything written here. Names still move; a
program written against this package should expect to be edited when they do.
