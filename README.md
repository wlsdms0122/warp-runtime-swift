# warp-runtime-swift

The Swift runtime for [Warp](../../spec/README.md). It reads documents, checks
and links them before anything runs, runs them under a caller that can always
stop them, and brings the host's vocabulary. What the language *is* lives in
the specification; this package is one implementation of it.

A program can also be built directly as Swift values — `Module`, `Procedure`,
`Statement`, `Expression` — and never touch a document. That is not a trick:
it is what a program that stays where it was built looks like.

```swift
import Warp

let language = Language()

let greet = Procedure(
    signature: Signature(
        parameters: ["name": Parameter(type: .string)],
        returns: .string
    ),
    body: [
        Statement(
            id: "greeting",
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

let image = try language.link(
    [Module(name: "hello", procedures: ["greet": greet])] + Module.standard,
    entry: "greet"
)

let value = try await language.makeExecutor().run(
    image,
    arguments: ["name": .string("warp")]
)

// value == .string("hello, warp")
```

## The products

| product | what | depends on |
|---|---|---|
| `Warp` | the shapes, checking, linking, running, and the standard vocabulary | nothing |
| `WarpSyntax` | a document read into shapes, and shapes written back out | `Warp` |
| `WarpSerialization` | a document written down — Warp's own bytes to carry it, text to read it | `Warp` |

The arrows are the architecture. A serialization carries a tree of data and
never learns what the tree means, so it sees `Warp`'s `Value` and nothing of
`WarpSyntax`. `WarpSyntax` is optional in the honest sense: a program that
never travels never links it.

## An arriving program

```swift
import Warp
import WarpSyntax
import WarpSerialization

let document = try BinaryEncoding.value(from: bytes)   // bytes → tree, or refused
let module = try Loader().load(document)               // tree → module, or refused
let image = try Language().link([module] + Module.standard, entry: "entry")
let answer = try await Language().makeExecutor().run(image)
```

Each step refuses rather than guesses, and everything refusable is refused
while nothing has run — including the branches this run would not have taken.
The stages and what each one checks are the specification's, not this file's.

`Loader` reads the canonical document and nothing else by default. Which
construct words exist is a `ConstructRegistry`; a host may register its own
forms. A front end may also hand over a `Notation` — its own condition
spelling and its own template words — and no table of either is shipped here:
a document has no spellings, so this package names none. The wire never carries
one.

`Writer` is the way back out: a program that was *built* rather than read has
no document to hand to anything running elsewhere, and this is how it gets one.

Whatever refuses somewhere says where. A refusal from the two stages that read
a program before running it carries a `Place` — the path to it through the document,
spelled from the keys the document itself writes, so
`procedures.greet.body.total[2].call.arguments.amount` is a line every word of
which an author can follow in the text in front of them. It is steps rather
than a sentence because a front end holding the file this was authored in has
to walk them to point at the line, and only the front end knows that file: what
crossed the wire is the document. Which is why a step says how it was got: a
`key` is a word the document itself writes and a reader may go looking for one
in the text, while a `landmark` — the word for a statement's construct — is
this implementation's for a shape, since `{ call: … }` and `{ value: { call:
… } }` arrive here as one. A refusal from a run carries a `Trace` instead —
where the run had been, which is the other question.

A module's name is never a step. A link calls a declaration `wallet.entry`, and
no document writes that: `name` sits beside `procedures`, and what `procedures`
holds is the declared key alone. It is carried beside the steps instead, because
a link holds several documents and the steps alone do not say which —
`std.collection` and `std.concurrent` both declare `first`, and a reader handed
`procedures.first` with no document would point at whichever one it was holding.
So a place reads `wallet/procedures.entry.body.sent[0].call`, and the part before
the slash is the only part that is not a key.

Which document is three answers rather than two. A module that wrote no name is
still a document — it declares into the link's shared space, the way a
translation unit without a namespace does. A program a caller assembled in
memory is not a document at all. Spelling both of those the same way would let a
place with no text under it be matched against any file an author never named,
and answered with that file's first line.

Not every refusal has a place, and the ones that do not say so: two modules
declaring one name is two places and an entry nobody declares is none, so those
carry `nil` — written out at the call, because the initializer takes no default
and a place nobody carried would otherwise look like a place that does not
exist. What a notation refuses while reading a document is not placed this way
yet.

## Vocabulary — the boundary to the outside

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
    name: "app",
    procedures: [
        "shout": Procedure(
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

Link it beside `Module.standard` and a document may write `name.shout` — and a
document that sends a word nobody linked is refused by name before anything
runs. The standard vocabulary ships the same way: bundles a caller takes what
it wants from, no second namespace and no second lookup order.

## Stopping and watching

A run can always be stopped from outside — cancellation is observed between
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
