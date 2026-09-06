//
//  ValueReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// Data as a document spells it. `Value` is the language's data type and knows
// nothing about being written down; this is the one place that mapping lives.
public struct ValueReader: Decodable {
    // MARK: - Property
    public let value: Value

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = .null

            return
        }

        if let bool = try? container.decode(Bool.self) {
            self.value = .bool(bool)

            return
        }

        // Across the Value bridge a numeral keeps its kind: the bridge holds
        // the `Value` itself, so a fraction that happens to be whole is known
        // to be a fraction rather than re-guessed from its spelling.
        if let bridged = decoder as? ValueDecoder {
            switch bridged.value {
            case .int, .double:
                self.value = bridged.value

                return

            default:
                break
            }
        }

        if let integer = try? container.decode(Int.self) {
            self.value = .int(integer)

            return
        }

        // A foreign carrier's number is a binary64 by the carrier's own nature:
        // past the machine word its digits cannot be told from a fraction
        // spelled without a point (`1e19` and its digits arrive identically) so
        // what a word cannot hold reads as the double the carrier holds. This
        // is the one reader that does not keep a whole numeral's kind past the
        // word, on purpose: the warp encodings and the YAML front end own their
        // grammars and refuse there, and this path reads what a Codable carrier
        // holds, which lost the distinction before this reader saw it.
        if let double = try? container.decode(Double.self) {
            self.value = .double(double)

            return
        }

        if let string = try? container.decode(String.self) {
            self.value = .string(string)

            return
        }

        // Bytes come over whole, as `Data`, and only across the Value bridge,
        // which answers `Data` for the bytes kind alone. A foreign decoder is
        // never asked, because its own `Data` reading walks an unkeyed list of
        // small numbers and would quietly turn an array of them into bytes.
        // What the writer puts out is no part of that: it writes bytes as the
        // array they are, and a carrier that has no compact spelling gives that
        // array back as an array.
        if decoder is ValueDecoder, let data = try? container.decode(Data.self) {
            self.value = .bytes([UInt8](data))

            return
        }

        if let array = try? container.decode([ValueReader].self) {
            self.value = .array(array.map(\.value))

            return
        }

        if let fields = try? container.decode([String: ValueReader].self) {
            self.value = .dictionary(try fields.mapValues(\.value).named(at: decoder.steps))

            return
        }

        throw ReadingError(
            "Value could not be decoded",
            at: decoder.steps
        )
    }

    // MARK: - Public
    // MARK: - Private
}
