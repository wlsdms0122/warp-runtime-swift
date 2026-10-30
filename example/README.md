# Example hosts

Hosts of this runtime, kept as a package beside it, that run the programs in the specification's `example/` (the `warp` submodule). A host is a runner and the vocabulary modules it lends; every program is a document.

| target | what |
|---|---|
| `warp` | builds and runs the documents it is handed from an entry, lending every module below |
| `warpx` | builds a program twice, straight from its documents and back through their objects, runs both and prints both return values; lends the `Host` vocabulary the feature programs call |
| `WarpConsole` … `WarpProcess` | vocabulary modules, one library each |

`warp` reads a document as its text (`.warpt`) or as its binary (`.warp`), told by the leading bytes: a file beginning with the binary's magic is read as the binary, under the specification's `spec/ENCODING.md`, and any other as the text.

```
git submodule update --init      # from the repository root
swift build
```

## Running the examples

`warp <document>... --entry <name> [--arg name=<value>]...` compiles the documents in the order their needs stand, beside the standard vocabulary and the modules, links them and runs the entry. An argument is a JSON value (`24`, `'"add"'`), and an Optional parameter the command line leaves out is handed null. `File` and `Process` reach the directory it is run in, so a program is run from its own folder. A document's object is filed under `.objects/` beside it and read back while what it was compiled against still stands.

```
warp=$PWD/.build/debug/warp
cd ../warp/example

(cd snake && $warp snake.warpt --entry game.main --arg width=24 --arg height=12)
(cd todo && $warp todo.warpt --entry todo.main --arg command='"add"' --arg text='"write programs"')
(cd wordfreq && $warp wordfreq.warpt --entry words.main --arg path='"words.txt"')
(cd sheet && $warp *.warpt --entry sheet.main --arg path='"input/budget.json"')

python3 tool/server.py 8765 orders &
(cd fetch && $warp fetch.warpt --entry fetch.main --arg url='"http://127.0.0.1:8765/orders.json"')
(cd orders && $warp money.warpt orders.warpt --entry orders.main --arg path='"orders.json"' --arg server='"http://127.0.0.1:8765"')
(cd flow && $warp *.warpt --entry flow.main --arg path='"plan/nightly.json"')
```

`tool/feature.sh` runs every program of `feature/programs.tsv` through `warpx` and prints one line each, `ok` when it did what the table expects and its objects returned the same. It exits 1 when one differs.

```
swift build && tool/feature.sh
```

## The modules

| library | declares | reaches | fails with |
|---|---|---|---|
| WarpConsole | `IO.key`, `IO.write`, `IO.clear` | the host's `Console` (`ConsoleLending`) | |
| WarpTime | `Time.now`, `Time.wait` | the clock | |
| WarpRandom | `Random.int` | a die | |
| WarpFile | `File.read`, `File.write`, `File.exists`, `File.list` | files under the host's directory (`FileLending`); a path leading out of it fails | `file_failed`, details `path` |
| WarpNet | `Net.get`, `Net.post`, `Net.Response` | HTTP | `net_failed`, details `url` |
| WarpJSON | `JSON.parse`, `JSON.text` | nothing: both are const queries, so a string a document writes is parsed at the build | `json_failed` |
| WarpProcess | `Process.run`, `Process.Result` | `/bin/sh -c` in the host's directory (`ProcessLending`) | `process_failed`, details `command` |

The signatures are listed in the specification's `example/README.md`. A host takes the modules it means to lend; where a module reaches the host it names a protocol, and the host's environment adopts each one it lends:

```swift
struct Host: ConsoleLending, FileLending {
    let console: Console
    let directory: URL
}

let vocabulary = Module.standard + [try Module.console(), try Module.file(), try Module.json()]
let returned = try await Executor(environment: Host(console: console, directory: directory)).run(image, entry: entry, arguments: [:])
```
