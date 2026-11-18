//
//  ArmReader.swift
//  WarpSyntax
//
//  Created by JSilver on 11/1/26.
//

import Foundation
import Warp

// What a switch runs for one case: the fields it binds under `binds`, each
// beside the name it is read by, and the body under `then`. An arm binding
// nothing writes no `binds`, so one written empty says that a second way.
struct ArmReader: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case binds
        case then
    }

    // MARK: - Property
    let arm: Arm

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "arm")

        let binds = try decoder.descendingIfPresent(to: CodingKeys.binds).map { written in
            try Self.binds(from: written)
        }

        if binds?.isEmpty == true {
            throw ReadingError(
                "binds nothing under `binds`, and an arm binding nothing writes no `binds`",
                at: try decoder.steps + [.key(CodingKeys.binds.stringValue)]
            )
        }

        guard let then = try decoder.descendingIfPresent(to: CodingKeys.then)?.read(BodyReader.self).body else {
            throw ReadingError("an arm writes its `then`, the body that runs for its case", at: try decoder.steps)
        }

        self.arm = Arm(binds: binds ?? [:], then: then)
    }

    // MARK: - Public
    // MARK: - Private
    // Each field the case carries, beside the name it binds.
    private static func binds(from decoder: Decoder) throws -> [Name: Name] {
        guard case .dictionary = try ValueReader(from: decoder).value else {
            throw ReadingError("`binds` is a dictionary of each field to the name it binds", at: try decoder.steps)
        }

        return try decoder.read([Name: String].self).reduce(into: [:]) { binds, entry in
            binds[entry.key] = try Name.read(entry.value, at: decoder.steps + [.key(entry.key.spelling)])
        }
    }
}
