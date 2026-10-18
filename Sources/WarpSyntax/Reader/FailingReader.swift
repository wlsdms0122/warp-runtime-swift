//
//  FailingReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/18/26.
//

import Foundation
import Warp

// What may come out of a procedure, as a declaration writes it under
// `failing`: the failures it names, as a list of strings, or the word
// `anything`. A list and a word are told apart by what is written, so no
// failure's name stands for anything.
struct FailingReader: Decodable {
    // MARK: - Property
    static let anything = "anything"

    let failing: Failing

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        guard let word = try? decoder.read(String.self) else {
            self.failing = .these(Set(try decoder.read([String].self)))

            return
        }

        guard word == Self.anything else {
            throw ReadingError(
                "`failing` is '\(word)'. It names the failures as a list, or is `\(Self.anything)`",
                at: decoder.steps
            )
        }

        self.failing = .anything
    }

    // MARK: - Public
    // MARK: - Private
}
