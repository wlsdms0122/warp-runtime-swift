//
//  Decoder+Reading.swift
//  WarpSyntax
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp

extension Decoder {
    // The reading this decoder is. Every reader is reached from a
    // `ValueDecoder`, which is what knows the steps it has walked; a decoder
    // that is not one is refused rather than read some other way.
    var valueDecoder: ValueDecoder {
        get throws {
            guard let decoder = self as? ValueDecoder else {
                throw ReadingError("a document is read from the value it is")
            }

            return decoder
        }
    }

    // Where this reading has reached, in the document's own terms.
    var steps: [Place.Step] {
        get throws { try valueDecoder.steps }
    }

    // Read what is written here, standing on it, so a reader judging a value
    // after reading it refuses at the place it read.
    func read<T: Decodable>(_ type: T.Type) throws -> T {
        try valueDecoder.decode(type)
    }

    // A dictionary keyed by names, read in the key order.
    func read<T: Decodable>(_ type: [Name: T].Type) throws -> [Name: T] {
        try valueDecoder.read(type)
    }

    func read<T: Decodable>(_ type: [T].Type) throws -> [T] {
        try valueDecoder.read(type)
    }

    // The reading under a key, standing on it.
    func descending(to key: some CodingKey) throws -> Decoder {
        try valueDecoder.descending(to: key.stringValue)
    }

    // The same, and nothing where the key is not written or holds null.
    func descendingIfPresent(to key: some CodingKey) throws -> Decoder? {
        try valueDecoder.descendingIfPresent(to: key.stringValue)
    }
}
