//
//  ObjectCache.swift
//  warp
//

import Foundation
import Warp
import WarpSyntax

// A document's object, filed under its identity beside the document.
struct ObjectCache {
    // MARK: - Property
    private let directory: URL

    // MARK: - Initializer
    init(directory: URL) {
        self.directory = directory
    }

    // MARK: - Public
    func object(of identity: Identity) throws -> Value? {
        let file = location(of: identity)

        guard FileManager.default.fileExists(atPath: file.path) else { return nil }

        return try BinaryEncoding().value(from: try Data(contentsOf: file))
    }

    func file(_ object: Value, of identity: Identity) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try BinaryEncoding().data(from: object).write(to: location(of: identity))
    }

    // MARK: - Private
    private func location(of identity: Identity) -> URL {
        directory.appendingPathComponent("\(identity).warp")
    }
}
