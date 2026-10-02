# warp-runtime-swift

The Swift runtime for [Warp](../../spec/README.md). It reads documents, builds them before anything runs, runs them under a host that can always stop them, and brings the host's vocabulary. The language is defined by the specification; this package is one implementation of it.

A program can also be built directly from Swift values (`Module`, `Procedure`, `Statement`, `Expression`) without a document.

```swift
import Warp
import WarpStandard

let greet = Procedure(
    access: .public,
    signature: Signature(
        parameters: [Parameter(name: "name", type: .string)],
        returns: .string
    ),
    body: [
        Statement(
            binding: .constant("greeting"),
            expression: .call(
                Call(
                    selector: "std.text.joined",
                    arguments: [
                        .array([
                            .literal(.string("hello, ")),
                            .call(Call(selector: "std.text.text", arguments: [.reference([.key("name", optional: false)])]))
                        ]),
                        .literal(.string(""))
                    ]
                )
            )
        )
    ],
    result: .reference([.key("greeting", optional: false)])
)

let image = try await Builder().build(
    [try Module(procedures: ["hello.greet": greet])] + Module.standard
)

let value = try await Executor().run(
    image,
    entry: "hello.greet",
    arguments: ["name": .string("warp")]
)

// value == .string("hello, warp")
```

## The products

| product | what | depends on |
|---|---|---|
| `Warp` | the language, checking, linking, running | nothing |
| `WarpStandard` | the standard vocabulary, in bundles | `Warp`, `WarpSyntax` |
| `WarpSyntax` | a document: the bytes and text one is carried in, read into a program and written back out | `Warp` |

A host that reads bytes needs `WarpSyntax`. A host that assembles a program in Swift against a vocabulary of its own needs only `Warp`. `WarpStandard` reads the part of the vocabulary written in Warp, so it brings `WarpSyntax` along.

`WarpSyntax` writes and reads the wire without learning what the tree means. An implementation in another language can speak the format without implementing what a procedure is.

## An arriving program

```swift
import Warp
import WarpSyntax

let document = try BinaryEncoding().value(from: bytes) // bytes → tree, or refused
let module = try Loader().load(                        // tree → module, or refused
    document,
    identity: try Identity.of(document)                // which document, for refusals
)
let image = try await Builder().build([module] + Module.standard)
let answer = try await Executor().run(image, entry: "entry", arguments: [:])
```

Each step refuses rather than guesses. Everything the build can refuse is refused before anything runs, including branches this run would not take. The specification says which stage checks what.

## Compiling and linking

The specification names three stages a refusal can come from: `load`, `build` and `run`. `load` is `Loader` and `run` is `Executor`. The middle one is `Builder`, and a build is compiling and linking, the same two an ordinary toolchain has.

| | what it answers | what varies |
|---|---|---|
| compile | every declaration judged and lowered, and the call graph read off it | the modules |
| link | one table a run reads, every declaration of every module | the list |

The line between them is the numbering. **A lowered body carries the numbers its own document gave**, so a document lowers to the same text in every link. The link resolves those numbers to rows of a table. The entry a run starts from is not part of the documents, so one compile serves every entry.

`Builder` has a door for each. `build(_:)` is the two together. `compile(_:)` and `link(_:supplying:)` are the halves. `compile(_:against:supplying:)` compiles documents against documents compiled earlier, and `lay(_:supplying:)` makes a `Laid` that `compile(_:against:)` reuses, for a host that compiles against the same vocabulary many times.

`Loader` reads the canonical document by default. Which construct keys exist is a `ConstructRegistry`; a host may register its own forms. A front end may also hand over a `Notation`: an `ExpressionSpelling` read wherever an expression is, a template's `Interpolation`, whether a parameter is written as a pair (`pairedParameter`), whether a mapping is read as a bare record (`readsBareRecords`), and how a name the text declares is read in full (`qualifying`). A document has no spellings, so this package ships no notation but the canonical one.

`Writer` writes a program back out as a document, so a program built in Swift can be sent to a runtime elsewhere.

A refusal from load or build carries a `Place`, the path to it through the program. The language names its own slots, which a host that built the program in Swift can follow. `Loader.reading { }` reads the same place in the keys the document writes, such as `procedures.greet.body.total[2].call.arguments[1]`, which an author can follow in the text.

A place is a list of steps, so a front end holding the file a document was written from can walk them to a line. A `key` step is one the document writes. A `landmark` is this implementation's key for a construct the document does not name on its own, since `{ call: … }` and `{ value: { call: … } }` arrive as one.

A refusal from a run carries a `Trace` instead: where the run had been.

A declaration's name is its key. A link calls a declaration `wallet.entry` because `wallet.entry` is the key the document wrote under `procedures`, dot and all. So a place reads `0da2e372bba7/procedures.wallet.entry.body.sent[0].call`, and the part before the slash is the only part that is not a key.

**Which document a place is in is an `Identity`, and never a name.** A link holds several documents and the steps alone do not say which. `std.collection.first` and `wallet.first` may sit in two documents or in one, and a program split across files declares names under one prefix from several documents. So identity is derived from the document: the digest of its canonical bytes, worked out by `WarpSyntax`. Two hosts holding one document get the same identity.

`Module.identity` is nil for a module a host built: there is no text to point back into. A reader is told which document it reads when it loads it:

```swift
let module = try Loader().load(document, identity: try Identity.of(document))
```

The identity is given before reading, so a refusal from that reading already says which document it is in.

A place reads `0da2e372bba7/procedures.wallet.charge…`: the part before the slash is `identity.short`, the first twelve hex digits of the identity, and the steps after it are the document's own keys, the declared spelling among them. The host that handed the bytes in knows which file an identity came from, and tells a person.

Whether a place has a text under it is `document.identity != nil`. A place from a program nobody wrote down says `assembled` rather than `none`, since `Optional.none` answers to that spelling too and `document == .none` would read true for a place that does not exist.

Not every refusal has a place. A name declared by two modules is refused at the later declaration. An entry nobody declares is refused by the run, with an `ExecutionError` that has no place. A refusal from reading with a notation (`Loader.canonical`) carries the steps it reached, `ReadingError.steps`, in no identified document: its `place.document.identity` is nil.

## Vocabulary: the boundary to the outside

A native procedure is one whose implementation the host supplies. `Query` answers without running; `Effect` answers by running. Everything a program does outside itself goes through a native procedure the host declared.

```swift
struct ShoutQuery: Query {
    enum Parameters: Int, ParameterSet {
        case text

        var declared: Parameter { Parameter(name: "text", type: .string) }
    }

    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .string(text) = question[.text] else {
            throw ExecutionError("app.shout asks a string")
        }

        return .string(text.uppercased())
    }
}

let vocabulary = try Module(
    procedures: [
        "app.shout": Procedure(
            signature: Signature(of: ShoutQuery.self, returns: .string),
            implementation: .query(ShoutQuery())
        )
    ]
)
```

Linked beside `Module.standard`, it lets a document send `app.shout`. A document that sends a procedure nobody linked is refused by name before anything runs. The standard vocabulary ships the same way, as bundles a host picks from.

## Stopping and watching

A run can always be stopped from outside. Cancellation is observed between statements and at the start of every round. The runtime sets no fan-out cap, recursion depth or iteration limit; a `loop`'s `while` is the author's own bound. Runaway work is watched through `ExecutionObserver` and stopped by cancelling the task.

## Conformance

`WarpConformanceTests` runs the cases in [`spec/conformance/`](../../spec/conformance) through public API, so a case passes by what the specification says and not by what the implementation holds inside.

## Status

Everything above is implemented and tested. What the language does is asked by the specification's cases. Names in this package still change.
