//
//  main.swift
//  warp
//

import Foundation
import Warp
import WarpConsole
import WarpFile
import WarpJSON
import WarpNet
import WarpProcess
import WarpRandom
import WarpStandard
import WarpSyntax
import WarpTime

// warp <document.warpt or .warp>... --entry <name> [--arg name=<value>]...
//
// A file beginning with the binary's magic is a document's bytes, and any
// other is a document's text. Every document is compiled, in the order its
// needs stand before it, beside the standard vocabulary and the modules this
// host lends, linked as one, and run from the entry. An argument is a value
// written as JSON, and the return value shows the way `text` spells it. The
// `File` and `Process` modules reach the current directory.
//
// A document's object is cached beside it and read back while what it was
// compiled against still reads the same; one compiled against a document
// whose interface has since changed is compiled again, the way a build tool
// rebuilds a stale object. A body that is not const may change and leave the
// documents leaning on it read back, so long as it names what it named.

var arguments = Array(CommandLine.arguments.dropFirst())
var given: [Name: Value] = [:]
var entry: Name?

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(2)
}

while let at = arguments.firstIndex(where: { option in option == "--arg" || option == "--entry" }) {
    guard at + 1 < arguments.count else { fail("\(arguments[at]) takes a value") }

    let option = arguments[at]
    let value = arguments[at + 1]

    arguments.removeSubrange(at ... at + 1)

    if option == "--entry" {
        do {
            entry = try Name(value)
        } catch {
            fail("--entry takes a name: \(error)")
        }
        continue
    }

    guard let split = value.firstIndex(of: "=") else { fail("--arg takes name=<value>") }

    let name = String(value[..<split])
    let text = String(value[value.index(after: split)...])

    do {
        given[try Name(name)] = try JSON().value(from: text)
    } catch {
        fail("argument '\(name)' does not read: \(error)")
    }
}

guard let entry, !arguments.isEmpty else {
    fail("usage: warp <document.warpt or .warp>... --entry <name> [--arg name=<value>]...")
}

let console = Console()
let host = Host(console: console, directory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
let files = arguments.map { path in URL(fileURLWithPath: path) }

await console.enter()

do {
    let builder = Builder(fingerprinting: Fingerprint.of(interfaceOf:))
    let vocabulary = Module.standard + [try Module.console(), try Module.time(), try Module.random(), try Module.file(), try Module.net(), try Module.json(), try Module.process()]
    let supplying = try Supplying(vocabulary)
    let laid = try await builder.compile(vocabulary, against: [], supplying: supplying)

    // Every document, with the cache its object is kept in.
    var documents: [(module: Module, identity: Identity, file: URL, cache: ObjectCache)] = []

    for file in files {
        let data = try Data(contentsOf: file)
        let written = data.starts(with: BinaryEncoding.magic)
            ? try BinaryEncoding().value(from: data)
            : try TextEncoding().value(from: data)
        let cache = ObjectCache(directory: file.deletingLastPathComponent().appendingPathComponent(".objects"))

        documents.append((try Loader().load(written), try Identity.of(written), file, cache))
    }

    let caches = Dictionary(documents.map { document in (document.identity, document.cache) }) { first, _ in first }
    var cached = Set<Identity>()
    let compilations = try await builder.compile(
        documents.map(\.module),
        against: laid,
        supplying: supplying
    ) { identity, _ in
        let object = try caches[identity]?.object(of: identity)

        if object != nil {
            cached.insert(identity)
        }

        return object
    }

    for (document, compilation) in zip(documents, compilations) {
        let name = document.file.lastPathComponent

        switch compilation {
        case .read:
            await console.note("\(name): object \(document.identity) read from the cache")

        case let .compiled(own):
            if cached.contains(document.identity) {
                await console.note("\(name): object \(document.identity) was compiled against a document that changed")
            }

            try document.cache.store(try own.object(), of: document.identity)
            await console.note("\(name): object \(document.identity) compiled and cached")
        }
    }

    // A `T?` parameter the command line does not write is handed null. The
    // language takes every argument from its caller, and this caller holds
    // nothing there, so it says so.
    if let declared = documents.lazy.compactMap({ document in document.module.procedures[entry] }).first {
        for parameter in declared.signature.parameters where given[parameter.name] == nil {
            guard case .optional = parameter.type else { continue }

            given[parameter.name] = .null
        }
    }

    let image = try builder.link(laid + compilations.map(\.object), supplying: supplying)
    let returned = try await Executor(environment: host).run(image, entry: entry, arguments: given)

    await console.leave()

    if returned != .null {
        print(Rendering(returned).text())
    }
} catch {
    await console.leave()
    FileHandle.standardError.write(Data("refused(\(type(of: error))): \(error)\n".utf8))
    exit(1)
}
