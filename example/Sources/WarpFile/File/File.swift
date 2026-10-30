//
//  File.swift
//  WarpFile
//

import Foundation
import Warp

// The file a path names under the lent directory, failing where the path
// leads out of it.
struct File {
    // MARK: - Property
    let url: URL

    // The path as the program wrote it, which a failure names.
    let path: String

    // MARK: - Initializer
    init<P: NativeProcedure>(_ invocation: Invocation<P>, at key: P.Parameters) throws {
        guard let host = invocation.environment as? FileLending else {
            throw ExecutionError("'\(invocation.selector)' reaches a directory, and this run was handed none")
        }

        guard case let .string(path) = invocation[key] else {
            throw ExecutionError("'\(invocation.selector)' takes a path as a string, and \(invocation[key].nominal) arrived")
        }

        let root = host.directory.standardizedFileURL
        let url = root.appendingPathComponent(path).standardizedFileURL

        guard url.path == root.path || url.path.hasPrefix(root.path + "/") else {
            throw FileFailed("'\(path)' leads out of the directory the host lends", path: path)
        }

        self.url = url
        self.path = path
    }

    // MARK: - Public
    // MARK: - Private
}
