//
//  Series.swift
//  WarpConformanceTests
//
//  Created by JSilver on 11/1/26.
//

import Foundation

// The specification's WARPs, and which of them are the language: every
// accepted WARP that no accepted WARP supersedes. A WARP is superseded by
// what an accepted WARP writes under `Supersedes` and never by anything it
// writes itself, so which WARPs are live is worked out here from all of them
// and is written nowhere.
struct Series: Sendable {
    // MARK: - Property
    // In number order.
    let warps: [WARP]

    // What the accepted WARPs supersede. A draft is not part of the language,
    // so what it says it supersedes is replaced by nothing yet.
    var superseded: Set<Int> {
        Set(warps.filter { warp in warp.status == .accepted }.flatMap(\.supersedes))
    }

    // The WARPs whose cases a runner asks.
    var live: [WARP] {
        let superseded = superseded

        return warps.filter { warp in warp.status == .accepted && !superseded.contains(warp.number) }
    }

    // MARK: - Initializer
    init(at specification: URL) throws {
        self.warps = try Self.folders(in: specification)
            .map { folder in try WARP(at: folder) }
            .sorted { one, other in one.number < other.number }
    }

    // MARK: - Public
    // Every folder in the specification named like a WARP's, whether or not
    // what it holds reads as one.
    static func folders(in specification: URL) throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: specification, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { folder in
                folder.lastPathComponent.hasPrefix(WARP.prefix)
                    && (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { one, other in one.lastPathComponent < other.lastPathComponent }
    }

    // MARK: - Private
}
