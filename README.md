# warp-runtime-swift

The Swift runtime for [Warp](warp/spec/README.md). It reads documents, builds them before anything runs, runs them, and brings the host's vocabulary. The language is defined by the specification; this package is one implementation of it.

A program arrives as a document. The host reads it, builds it against the vocabulary it lends, and runs it.

```swift
import Warp
import WarpStandard
import WarpSyntax

let text = """
    (warp 1)
    (import Standard.Text.joined)
    (procedure Hello.greet
      (access public)
      (parameter name (type String))
      (returns String)
      (body
        (return (call Standard.Text.joined (array "hello, " name) ""))))
    """

let module = try Loader().load(try TextEncoding().value(from: text))
let image = try await Builder().build([module] + Module.standard)

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

A host that reads documents needs `WarpSyntax`. A module of native procedures a host lends needs only `Warp`. `WarpStandard` reads the part of the vocabulary written in Warp, so it brings `WarpSyntax` along.

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

A host that keeps objects between builds hands `Builder(fingerprinting:)` how a compiled document's fingerprint is worked out, and compiles with `compile(_:against:supplying:reading:)`. For each document, once what it stands on is laid down, the build asks `reading` for the object cached under the document's `Identity` and the fingerprints of what it is compiled against. An object compiled against exactly those is read back and judged no further, and any other document is compiled. Each `Compilation` says which: `.read` or `.compiled`, its `object` the `Compiled` either way, so a host writes back only what was compiled. `WarpSyntax` gives two fingerprints. `Fingerprint.of(objectOf:)` is over the whole object, so a change anywhere in a document compiles again everything that stands on it. `Fingerprint.of(interfaceOf:)` is over `Compiled.interface()`, the object without the bodies of its procedures that are not const or the closures they wrote. A compile runs another document's body only by folding, and folding runs only what is const, so a change to the body of a procedure that is not const leaves what stands on its document read back. A document with no identity, which a host built, is always compiled.

A build refuses with `BuildRefused`, from each of these and from `Supplying`. Its `refusals` are each a `BuildError` with its own sentence and place. A document's declarations refuse alone, since everything else in it stands on them. Once they stand, a body stands on its declaration's signature and on no other body, so every body of the document is judged and each one that refuses is there, in the order the declarations are named. Documents are compiled after the ones they stand on, and the build stops at the first document that refuses.

`Loader.load` reads a document in the one form the specification writes: each construct under its own key, every name written in full, `imports` listing every name the program uses, and `importedClaims` every claim another document makes that it stands on. It reads nothing else, and a document that says something another way is refused where it does.

`Loader.interface` reads an interface, `(interface …)`, into the module it declares: each declaration read as a document's is, each procedure with no body, and no identity. A host that lends native procedures and hands their interface to a front end holds the one to the other as this package holds `Standard` to the interface the IR gives, comparing the two modules' `types`, `contracts`, `claims`, `members`, `typeMembers` and each procedure's `signature`.

A refusal from load, and each refusal a build holds, carries a `Place`, the path to it through the program. The language names its own parts, which a host that built the program in Swift can follow, and the refusal's sentence reads them. `Place.value` is the same place as [WARP-65](warp/spec/WARP-65/SPEC.md) names it, the value `[identity, steps]`: the identity as its bytes and each step a key the document writes, a string, or a position in a list it writes, an int, such as `procedures.greet.body[2].value.call.arguments[1]`, which an author can follow in the text. It reaches whoever holds the text without this runtime's types.

Whoever holds the file a document was written from can walk a place's value to a line. In it a statement is its position in the body, and the construct it writes is `value` and then the construct's key, so `procedures.entry.body[0].value.loop.while` is the `while` of the loop the first statement writes. A `landmark` names a body a host assembled, which has no document, and a place holding one has no `value`.

A refusal from a run carries a `Trace` instead: where the run had been. Its `places` are what [WARP-72](warp/spec/WARP-72/SPEC.md) names, one place for each frame that was running a statement, the outermost first, each read with `Place.value` like any other. An object does not say where a closure literal stands, so the body of a closure is found in its document's text, which a link reads from the modules handed to `Supplying`. A frame running a closure whose document was not handed there names no place.

A declaration's name is its key. A link calls a declaration `Wallet.entry` because `Wallet.entry` is the key the document wrote under `procedures`, dot and all. So a place's value steps through `procedures` and then `Wallet.entry`, and the identity beside the steps is the only part that is not a key.

**Which document a place is in is an `Identity`, and never a name.** A link holds several documents and the steps alone do not say which. `Standard.Collection.first` and `Wallet.first` may sit in two documents or in one, and a program split across files declares names under one prefix from several documents. So identity is derived from the document: the digest of its canonical bytes, worked out by `WarpSyntax`. Two hosts holding one document get the same identity.

`Module.identity` is nil for a module a host built: there is no text to point back into. A loaded document always has one: `Loader().load(document)` works it out before reading, so a refusal from that reading already says which document it is in.

In a refusal's sentence a place reads `0da2e372bba7/procedures.Wallet.charge…`: the part before the slash is `identity.short`, the first twelve hex digits of the identity, and the declared spelling stands as the document wrote it. The host that handed the bytes in knows which file an identity came from, and tells a person.

Whether a place has a text under it is `document.identity != nil`. A place from a program nobody wrote down is in `Place.Document.assembled`, whose identity is nil.

A name declared by two modules is refused at the later declaration. Not every refusal has a place: an entry nobody declares is refused by the run, with a `RunRefused` that has no place.

`Builder.expressionType(at:of:against:)`, from `WarpSyntax`, says what the build judged the expression at a place to hold, the place given as its `Place.value`. It builds the modules against what is laid, and the walk that judges a body answers as it passes the place. The answer is an `ExpressionType`: the type as the language spells it, and the fields a dot reads on it, those of the struct an Optional holds included, since `?.` reads past one. What an expression holds is read off what the walk judging its body passed before reaching it. So a refusal the build meets before the walk reaches the place, of a declaration or of something before it in its body, refuses the question, and one it meets after, in another body, after it in its own, or in a check of the body as a whole, leaves the answer standing. Nil is a place holding no expression the build judged.

## Vocabulary: the boundary to the outside

A native procedure is one whose implementation the host supplies. A `Query` is handed what its call wrote and may be declared const. An `Effect` is handed that and two things more, the caller's variable for a parameter handed in place and the run's `Environment`, and is never const. Everything a program does outside itself goes through a native procedure the host declared.

```swift
struct ShoutQuery: Query {
    enum Parameters: Int, ParameterSet {
        case text

        var declared: Parameter { Parameter(name: "text", type: .string) }
    }

    func evaluate(_ question: Question<Self>) async throws -> Value {
        guard case let .string(text) = question[.text] else {
            throw RunRefused("App.shout asks a String")
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

Cancellation is observed between statements and at the start of every round. `ExecutionObserver` watches a run, and a host may cancel the task running it.

A run that stops throws one of three things. A `RecoverableFailure` is a failure the program did not catch, the kind a `try` catches, and its `type`, `message` and `details` are what a catch would have read. Any other `WarpError` is a refusal, what the specification says a run refuses. `CancellationError` is the host cancelling.

## Conformance

`WarpConformanceTests` runs the cases of every live WARP, an accepted one no accepted WARP supersedes, from its `conformance/` under [`spec/`](warp/spec/README.md), through public API, so a case passes by what the specification says and not by what the implementation holds inside. The specification is the `warp` submodule, at the version this runtime conforms to; `git submodule update --init` brings it.

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
