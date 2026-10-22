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
import WarpYAML

// warp <document.warpt or .yaml>... --entry <name> [--arg name=<value>]...
//
// Every document is compiled, in the order its needs stand before it, beside
// the standard vocabulary and the modules this host lends, linked as one, and
// run from the entry. An argument is a value written as JSON, and the answer
// shows the way `text` spells it. The `File` and `Process` modules reach the
// current directory.
//
// A document's object is filed beside it and read back while what it was
// compiled against still stands; one compiled against a document that has
// since changed is compiled again, the way a build tool rebuilds a stale
// object.
//
// What this host lends a run: its console and its directory.
struct Host: ConsoleLending, FileLending, ProcessLending {
    let console: Console
    let directory: URL
}

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
        given[try Name(name)] = try JSON.value(from: text)
    } catch {
        fail("argument '\(name)' does not read: \(error)")
    }
}

guard let entry, !arguments.isEmpty else {
    fail("usage: warp <document.warpt>... --entry <name> [--arg name=<value>]...")
}

// Whether every object this one was compiled against is laid here as it was
// then. The object, a map, records them under `dependencies` by fingerprint.
func standing(_ object: Value, beside laid: [Compiled]) -> Bool {
    guard case let .dictionary(fields) = object, case let .array(dependencies)? = fields["dependencies"] else { return true }

    let fingerprints = Set(laid.compactMap { compiled in compiled.fingerprint?.bytes })

    return dependencies.allSatisfy { dependency in
        guard case let .bytes(bytes) = dependency else { return false }

        return fingerprints.contains(bytes)
    }
}

let console = Console()
let host = Host(console: console, directory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
let files = arguments.map { path in URL(fileURLWithPath: path) }

await console.enter()

do {
    let builder = Builder(fingerprinting: Fingerprint.of)
    let vocabulary = Module.standard + [try Module.console(), try Module.time(), try Module.random(), try Module.file(), try Module.net(), try Module.json(), try Module.process()]
    let supplying = try Supplying(vocabulary)
    var laid = try await builder.compile(vocabulary, against: [], supplying: supplying)

    // The documents in the order each one's needs stand before it, whatever
    // order they were given in, so each is laid against what it sends.
    var documents: [Identity: (module: Module, file: URL)] = [:]

    // A `.yaml` file is what a person wrote, and the front end turns it into
    // the document; a `.warpt` file is the document.
    for file in files {
        let text = try String(contentsOf: file, encoding: .utf8)
        let written = file.pathExtension == "yaml"
            ? try YAMLFrontend().document(from: text)
            : try TextEncoding().value(from: text)
        let identity = try Identity.of(written)

        documents[identity] = (try Loader().load(written, identity: identity), file)
    }

    for module in try ModuleGraph(documents.values.map(\.module)).modules {
        guard let identity = module.identity, let file = documents[identity]?.file else { continue }

        let cache = ObjectCache(directory: file.deletingLastPathComponent().appendingPathComponent(".objects"))

        if let object = try cache.object(of: identity) {
            if standing(object, beside: laid) {
                laid.append(try Compiled(written: object, of: identity, fingerprint: try Fingerprint.of(object)))
                await console.note("\(file.lastPathComponent): object \(identity) read from the cache")
                continue
            }

            await console.note("\(file.lastPathComponent): object \(identity) was compiled against a document that changed")
        }

        let compiled = try await builder.compile([module], against: laid, supplying: supplying)

        guard compiled.count == 1, let own = compiled.first else {
            fail("\(compiled.count) documents compiled where one stood")
        }

        try cache.file(try own.object(), of: identity)
        await console.note("\(file.lastPathComponent): object \(identity) compiled and filed")
        laid.append(own)
    }

    // A `T?` parameter the command line does not write is handed null. The
    // language takes every argument from its caller, and this caller holds
    // nothing there, so it says so.
    if let declared = documents.values.lazy.compactMap({ document in document.module.procedures[entry] }).first {
        for parameter in declared.signature.parameters where given[parameter.name] == nil {
            guard case .nullable = parameter.type else { continue }

            given[parameter.name] = .null
        }
    }

    let image = try builder.link(laid, supplying: supplying)
    let answered = try await Executor(environment: host).run(image, entry: entry, arguments: given)

    await console.leave()

    if answered != .null {
        print(Rendering(answered).text())
    }
} catch {
    await console.leave()
    FileHandle.standardError.write(Data("refused(\(type(of: error))): \(error)\n".utf8))
    exit(1)
}
