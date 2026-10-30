# warp-runtime-swift

The Swift runtime for [Warp](warp/spec/README.md). It reads documents, builds them before anything runs, runs them under a host that can always stop them, and brings the host's vocabulary. The language is defined by the specification; this package is one implementation of it.

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
                    selector: "Standard.Text.joined",
                    arguments: [
                        .array([
                            .literal(.string("hello, ")),
                            .call(Call(selector: "Standard.Text.text", arguments: [.reference([.name("name", optional: false)])]))
                        ]),
                        .literal(.string(""))
                    ]
                )
            )
        ),
        Statement(expression: .leave(.procedure(.reference([.name("greeting", optional: false)]))))
    ]
)

let image = try await Builder().build(
    [try Module(procedures: ["Hello.greet": greet])] + Module.standard
)

let value = try await Executor().run(
    image,
    entry: "Hello.greet",
    arguments: ["name": .string("warp")]
)

// value == .string("hello, warp")
```

## The products

| product | what | depends on |
|---|---|---|
| `Warp` | the language, checking, linking, running | nothing |
| `WarpStandard` | the standard vocabulary, in bundles | `Warp`, `WarpSyntax` |
| `WarpSyntax` | a document: the bytes and text one is carried in, read into a program | `Warp` |

A host that reads bytes needs `WarpSyntax`. A host that assembles a program in Swift against a vocabulary of its own needs only `Warp`. `WarpStandard` reads the part of the vocabulary written in Warp, so it brings `WarpSyntax` along.

`WarpSyntax` writes and reads the wire without learning what the tree means. An implementation in another language can speak the format without implementing what a procedure is.

## An arriving program

```swift
import Warp
import WarpSyntax

let document = try BinaryEncoding().value(from: bytes) // bytes → tree, or refused
let module = try Loader().load(document)               // tree → module, or refused
let image = try await Builder().build([module] + Module.standard)
let returned = try await Executor().run(image, entry: "entry", arguments: [:])
```

Each step refuses rather than guesses. Everything the build can refuse is refused before anything runs, including branches this run would not take. The specification says which stage checks what.

## Compiling and linking

The specification names three stages a refusal can come from: `load`, `build` and `run`. `load` is `Loader` and `run` is `Executor`. The middle one is `Builder`, and a build is compiling and linking, the same two an ordinary toolchain has.

| | what it returns | what varies |
|---|---|---|
| compile | every declaration judged and lowered, and the call graph read off it | the modules |
| link | one table a run reads, every declaration of every module | the list |

The line between them is the numbering. **A lowered body carries the numbers its own document gave**, so a document lowers to the same text in every link. The link resolves those numbers to rows of a table. The entry a run starts from is not part of the documents, so one compile serves every entry.

`Builder` has an entry point for each. `build(_:)` is the two together. `compile(_:)` and `link(_:supplying:)` are the halves. `compile(_:against:supplying:)` compiles documents against documents compiled earlier, and `lay(_:supplying:)` makes a `Laid` that `compile(_:against:)` reuses, for a host that compiles against the same vocabulary many times.

`Loader.load` reads a document in the one form the specification writes: each construct under its own key, every name written in full, and `imports` listing every name the program uses. It reads nothing else, and a document that says something another way is refused where it does.

A refusal from load or build carries a `Place`, the path to it through the program. The language names its own parts, which a host that built the program in Swift can follow, and the refusal's sentence reads them. `Place.value` is the same place as `CHECKING.md` names it, the value `[identity, steps]`: the identity as its bytes and each step a key the document writes, a string, or a position in a list it writes, an int, such as `procedures.greet.body[2].value.call.arguments[1]`, which an author can follow in the text. It reaches whoever holds the text without this runtime's types.

Whoever holds the file a document was written from can walk a place's value to a line. In it a statement is its position in the body, and the construct it writes is `value` and then the construct's key, so `procedures.entry.body[0].value.loop.while` is the `while` of the loop the first statement writes. A `landmark` names a body a host assembled, which has no document, and a place holding one has no `value`.

A refusal from a run carries a `Trace` instead: where the run had been.

A declaration's name is its key. A link calls a declaration `Wallet.entry` because `Wallet.entry` is the key the document wrote under `procedures`, dot and all. So a place's value steps through `procedures` and then `Wallet.entry`, and the identity beside the steps is the only part that is not a key.

**Which document a place is in is an `Identity`, and never a name.** A link holds several documents and the steps alone do not say which. `Standard.Collection.first` and `Wallet.first` may sit in two documents or in one, and a program split across files declares names under one prefix from several documents. So identity is derived from the document: the digest of its canonical bytes, worked out by `WarpSyntax`. Two hosts holding one document get the same identity.

`Module.identity` is nil for a module a host built: there is no text to point back into. A loaded document always has one: `Loader().load(document)` works it out before reading, so a refusal from that reading already says which document it is in.

In a refusal's sentence a place reads `0da2e372bba7/procedures.Wallet.charge…`: the part before the slash is `identity.short`, the first twelve hex digits of the identity, and the declared spelling stands as the document wrote it. The host that handed the bytes in knows which file an identity came from, and tells a person.

Whether a place has a text under it is `document.identity != nil`. A place from a program nobody wrote down is in `Place.Document.assembled`, whose identity is nil.

A name declared by two modules is refused at the later declaration. Not every refusal has a place: an entry nobody declares is refused by the run, with an `ExecutionError` that has no place.

## Vocabulary: the boundary to the outside

A native procedure is one whose implementation the host supplies. `Query` is const; `Effect` returns its value by running. Everything a program does outside itself goes through a native procedure the host declared.

```swift
struct ShoutQuery: Query {
    enum Parameters: Int, ParameterSet {
        case text

        var declared: Parameter { Parameter(name: "text", type: .string) }
    }

    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .string(text) = question[.text] else {
            throw ExecutionError("App.shout asks a String")
        }

        return .string(text.uppercased())
    }
}

let vocabulary = try Module(
    procedures: [
        "App.shout": Procedure(
            signature: Signature(of: ShoutQuery.self, returns: .string),
            implementation: .query(ShoutQuery())
        )
    ]
)
```

Linked beside `Module.standard`, it lets a document send `App.shout`. A document that sends a procedure nobody linked is refused by name before anything runs. The standard vocabulary ships the same way, as bundles a host picks from.

What a host hands a run is its `Environment`, which its effects read back through `Invocation.environment`. A host carrying ambient state on the task, a task local holding an open session say, conforms that environment to `WarpStandard.ConcurrentEnvironment`, and a fan-out runs each piece through its `isolateConcurrentWork`, where the state is severed or forked.

## Stopping and watching

A run can always be stopped from outside. Cancellation is observed between statements and at the start of every round. The runtime sets no fan-out cap, recursion depth or iteration limit; a `loop`'s `while` is the author's own bound. Runaway work is watched through `ExecutionObserver` and stopped by cancelling the task.

## Conformance

`WarpConformanceTests` runs the cases in [`spec/conformance/`](warp/spec/conformance) through public API, so a case passes by what the specification says and not by what the implementation holds inside. The specification is the `warp` submodule, at the version this runtime conforms to; `git submodule update --init` brings it.

```sh
PROBE_DIR=~/cases swift test --filter ProbeTests
PROBE_REWRITE=~/written tool/probe.sh ~/cases ~/more-cases
```

A folder of cases of one's own is asked the same way: `PROBE_DIR` enables the probe suite, which prints one line per case saying what it got and whether that held against its `expect`. `PROBE_REWRITE` also writes each program case there with its `expect` replaced by what it got, in the writer's layout, which is how a new case is generated. `tool/probe.sh` builds once and probes each folder given, writing its lines to `.build/probe/<folder name>.txt`.

## Examples

[`example/`](example/README.md) is a package of hosts beside this one: `warp`, which builds and runs any documents it is handed and lends them vocabulary modules (console, time, random, file, net, JSON, process), and `warpx`, which builds a program both straight and through its objects. They run the programs in `warp/example`.

## This repository

| path | what |
|---|---|
| `Package.swift`, `Sources/`, `Tests/` | the package: the products above and their tests |
| [`warp/`](warp/README.md) | the specification, the `warp` repository as a submodule at the version this runtime conforms to |
| [`example/`](example/README.md) | hosts beside this package, which run the programs in `warp/example` |
| `tool/probe.sh` | asks folders of cases through the probe suite, under Conformance above |
| `tool/embed-library.sh` | writes `warp/lib/standard` into `Sources/WarpStandard/Library/Library.swift`, which `LibraryTests` holds to the same text; run it after the submodule moves |
| `tool/bench/` | a package timing the programs under `program/`; `run.sh` builds it in release and runs it |

## Status

Everything above is implemented and tested. What the language does is asked by the specification's cases.
