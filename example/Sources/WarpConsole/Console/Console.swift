//
//  Console.swift
//  WarpConsole
//

import Foundation
import Warp

// The terminal the `io` module reaches: keys in, text out. Off a terminal it
// hears no keys and writes text as it comes, which is how a script runs it.
public actor Console {
    // MARK: - Property
    private static let cursorHidden = "\u{1B}[?25l"
    private static let cursorShown = "\u{1B}[?25h"
    private static let cleared = "\u{1B}[2J"
    private static let home = "\u{1B}[H"

    private let interactive = isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    private var original = termios()

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func enter() {
        guard interactive else { return }

        tcgetattr(STDIN_FILENO, &original)

        var raw = original
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON)
        raw.c_cc.16 = 0
        raw.c_cc.17 = 0
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)
        write(Self.cursorHidden + Self.cleared)
    }

    public func leave() {
        guard interactive else { return }

        tcsetattr(STDIN_FILENO, TCSANOW, &original)
        write(Self.cursorShown + "\n")
    }

    // The last key pressed since the previous read, or nil where none was.
    // An arrow is named; any other character is itself.
    public func key() -> String? {
        guard interactive else { return nil }

        var buffer = [UInt8](repeating: 0, count: 64)
        let count = read(STDIN_FILENO, &buffer, buffer.count)

        guard count > 0 else { return nil }

        return Self.keys(in: buffer[..<count]).last
    }

    public func write(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    // Clears the screen and puts the cursor at its top. Off a terminal there
    // is nothing to clear, so what is written next simply follows.
    public func clear() {
        guard interactive else { return }

        write(Self.home + Self.cleared)
    }

    public func note(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }

    // The console an effect was sent on: the environment the run was handed.
    static func of<P: NativeProcedure>(_ invocation: Invocation<P>) throws -> Console {
        guard let host = invocation.environment as? ConsoleLending else {
            throw ExecutionError("'\(invocation.selector)' reaches a console, and this run was handed none")
        }

        return host.console
    }

    // MARK: - Private
    private static func keys(in bytes: ArraySlice<UInt8>) -> [String] {
        var keys: [String] = []
        var index = bytes.startIndex

        while index < bytes.endIndex {
            let byte = bytes[index]

            if byte == 0x1B, bytes.index(index, offsetBy: 2) < bytes.endIndex, bytes[index + 1] == UInt8(ascii: "[") {
                switch bytes[index + 2] {
                case UInt8(ascii: "A"): keys.append("up")
                case UInt8(ascii: "B"): keys.append("down")
                case UInt8(ascii: "C"): keys.append("right")
                case UInt8(ascii: "D"): keys.append("left")
                default: break
                }

                index += 3
                continue
            }

            if let scalar = Unicode.Scalar(UInt32(byte)), byte >= 0x20, byte < 0x7F {
                keys.append(String(Character(scalar)))
            }

            index += 1
        }

        return keys
    }
}
