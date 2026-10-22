//
//  Warpx.swift
//  warpx
//

import Foundation
import Warp
import WarpJSON
import WarpStandard
import WarpSyntax

// warpx <entry> <document.warpt>... [--arg name=<value>]... [--one-at-a-time]
//
// The documents are handed to the builder in one batch, and it works the
// order out; under `--one-at-a-time` each is laid in the order given, against
// the ones before it, the way a document arriving later is, after the standard vocabulary
// and the host's. The program is built twice, once from the documents and
// once from their objects read back through the binary encoding, and run
// twice, so the answer and whether the objects agree are both printed.
@main
struct Warpx {
    static func main() async {
        var arguments = Array(CommandLine.arguments.dropFirst())
        var given: [Name: Value] = [:]
        var together = true

        if let at = arguments.firstIndex(of: "--one-at-a-time") {
            together = false
            arguments.remove(at: at)
        }

        while let at = arguments.firstIndex(of: "--arg") {
            guard at + 1 < arguments.count, let split = arguments[at + 1].firstIndex(of: "=") else {
                Self.fail("--arg takes name=<value>")
            }

            let name = String(arguments[at + 1][..<split])
            let text = String(arguments[at + 1][arguments[at + 1].index(after: split)...])

            do {
                given[try Name(name)] = try JSON.value(from: text)
            } catch {
                Self.fail("argument '\(name)' does not read: \(error)")
            }

            arguments.removeSubrange(at ... at + 1)
        }

        guard arguments.count >= 2 else {
            Self.fail("usage: warpx <entry> <document.warpt>... [--arg name=<value>]... [--one-at-a-time]")
        }

        let entry: Name

        do {
            entry = try Name(arguments[0])
        } catch {
            Self.fail("the entry is a name: \(error)")
        }

        let files = arguments.dropFirst().map { path in URL(fileURLWithPath: path) }
        let store = Store()

        do {
            let direct = try await Run(files: files, entry: entry, arguments: given, store: store, together: together).straight()
            print("answer:\n\(Rendering(direct).text())")
        } catch let refusal as Refusal {
            print(refusal)
            exit(1)
        } catch {
            print("refused(\(type(of: error))): \(error)")
            exit(1)
        }

        do {
            let again = try await Run(files: files, entry: entry, arguments: given, store: Store(), together: together).throughObjects()
            print("objects:\n\(Rendering(again).text())")
        } catch {
            print("objects refused(\(type(of: error))): \(error)")
            exit(1)
        }

        let log = await store.log

        if !log.isEmpty {
            print("log: \(log.joined(separator: " | "))")
        }
    }

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(2)
    }
}
