//
//  Elements.swift
//  Warp
//
//  Created by JSilver on 11/15/26.
//

import Foundation

extension Value {
    // The elements of a list in either spelling, by position: an array's own,
    // and bytes as the ints they are, each read where it is asked for.
    public struct Elements: RandomAccessCollection, Sendable {
        enum Spelling: Sendable {
            case array([Value])
            case bytes([UInt8])
        }

        // MARK: - Property
        let spelling: Spelling

        public var startIndex: Int { 0 }

        public var endIndex: Int {
            switch spelling {
            case let .array(array):
                array.count

            case let .bytes(bytes):
                bytes.count
            }
        }

        // MARK: - Initializer
        init(_ spelling: Spelling) {
            self.spelling = spelling
        }

        // MARK: - Public
        public subscript(position: Int) -> Value {
            switch spelling {
            case let .array(array):
                array[position]

            case let .bytes(bytes):
                .int(Int(bytes[position]))
            }
        }

        // MARK: - Private
    }
}
