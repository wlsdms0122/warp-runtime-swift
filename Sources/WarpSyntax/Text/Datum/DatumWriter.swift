//
//  DatumWriter.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// Elements written the one way, so a text that has been through this is the
// same bytes everywhere. A list is written on one line unless it breaks: a
// block holding a list breaks, and so does a list holding one that breaks. A
// list that breaks keeps the atoms it begins with on its first line and
// writes each part after them on a line of its own, two spaces deeper, its
// `)` closing the last. At the top, each element stands on a line of its own,
// a blank line before each that breaks.
struct DatumWriter {
    // One element of a datum, its lists' elements by where they stand in
    // the order the walk met them, a list's before its elements'. Written on
    // a stack of the writer's own, so a datum's depth is not this process's
    // call stack.
    private struct Entry {
        // MARK: - Property
        let datum: Datum
        let depth: Int
        var elements: [Int] = []

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // What is left to write: a text, or an entry.
    private enum Step {
        case text(String)
        case element(Int)
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func text(of data: [Datum]) throws -> String {
        var text = ""

        for (index, datum) in data.enumerated() {
            let entries = try self.entries(of: datum)
            let breaking = breaks(entries)

            if index > 0 {
                text += breaking[0] ? "\n\n" : "\n"
            }

            write(entries, breaking: breaking, into: &text)
        }

        return text + "\n"
    }

    // The same element on one line, for a sentence that quotes it.
    func line(of datum: Datum) throws -> String {
        let entries = try self.entries(of: datum)
        var text = ""

        write(entries, breaking: Array(repeating: false, count: entries.count), into: &text)

        return text
    }

    // MARK: - Private
    private func entries(of datum: Datum) throws -> [Entry] {
        var entries: [Entry] = []
        var walking: [(datum: Datum, within: Int?)] = [(datum, nil)]

        while let (datum, within) = walking.popLast() {
            let depth = within.map { list in entries[list].depth + 1 } ?? 0

            if datum.isList, depth >= DatumReader.nestingBound {
                throw EncodingRefused("the text nests deeper than a reader must follow")
            }

            if let within {
                entries[within].elements.append(entries.count)
            }

            entries.append(Entry(datum: datum, depth: depth))

            if case let .list(elements) = datum.form {
                walking += elements.reversed().map { element in (element, entries.count - 1) }
            }
        }

        return entries
    }

    // Whether each entry breaks, worked out from the last: an entry's
    // elements stand after it.
    private func breaks(_ entries: [Entry]) -> [Bool] {
        var breaking = Array(repeating: false, count: entries.count)

        for index in entries.indices.reversed() {
            let entry = entries[index]
            let holdsList = entry.elements.contains { element in entries[element].datum.isList }

            breaking[index] = entry.datum.isBlock && holdsList || entry.elements.contains { element in breaking[element] }
        }

        return breaking
    }

    private func write(_ entries: [Entry], breaking: [Bool], into text: inout String) {
        var steps: [Step] = [.element(0)]

        while let step = steps.popLast() {
            let index: Int

            switch step {
            case let .text(written):
                text += written

                continue

            case let .element(element):
                index = element
            }

            let entry = entries[index]

            if let atom = atom(entry.datum) {
                text += atom

                continue
            }

            // A list that breaks keeps the atoms it begins with on its
            // first line.
            let leading = breaking[index]
                ? entry.elements.prefix { element in !entries[element].datum.isList }.count
                : entry.elements.count

            var scheduled: [Step] = [.text("(")]

            for (position, element) in entry.elements.enumerated() {
                if position >= leading {
                    scheduled.append(.text("\n" + String(repeating: "  ", count: entry.depth + 1)))
                } else if position > 0 {
                    scheduled.append(.text(" "))
                }

                scheduled.append(.element(element))
            }

            scheduled.append(.text(")"))
            steps += scheduled.reversed()
        }
    }

    // An atom's spelling, nil for a list.
    private func atom(_ datum: Datum) -> String? {
        switch datum.form {
        case .null: "null"
        case let .bool(bool): bool ? "true" : "false"
        case let .int(int): "\(int)"
        case let .double(double): double.uncheckedSpelling
        case let .text(string): quoted(string, closing: "\"")
        case let .bytes(bytes): "x\"\(bytes.spelling)\""
        case let .name(name): isBare(name) ? name : quoted(name, closing: "`")
        case .list: nil
        }
    }

    // Whether a name is written bare: nothing in it ends a bare token or is
    // a control character, and it reads as no scalar.
    private func isBare(_ name: String) -> Bool {
        let scalars = Array(name.unicodeScalars)
        let digits: ClosedRange<Unicode.Scalar> = "0"..."9"

        guard
            let first = scalars.first,
            !["null", "true", "false"].contains(name),
            !scalars.contains(where: { scalar in scalar.value < 0x20 || "()\"`".unicodeScalars.contains(scalar) }),
            !DatumReader.whiteSpace.contains(where: scalars.contains)
        else {
            return false
        }

        return !(digits.contains(first) || ["-", "+"].contains(first) && scalars.count > 1 && digits.contains(scalars[1]))
    }

    private func quoted(_ string: String, closing: Unicode.Scalar) -> String {
        var text = String(closing)

        for character in string.unicodeScalars {
            switch character {
            case closing: text += "\\\(closing)"
            case "\\": text += "\\\\"
            case "\n": text += "\\n"
            case "\r": text += "\\r"
            case "\t": text += "\\t"

            default:
                guard character.value < 0x20 else {
                    text.unicodeScalars.append(character)

                    continue
                }

                text += String(format: "\\u%04x", character.value)
            }
        }

        return text + String(closing)
    }
}
