//
//  Lent.swift
//  WarpFile
//

import Foundation
import Warp

enum Lent {
    // The file a path names under the lent directory, refused where the
    // path leads out of it.
    static func file<P: NativeProcedure>(_ invocation: Invocation<P>, at key: P.Parameters) throws -> (url: URL, path: String) {
        guard let host = invocation.environment as? FileLending else {
            throw ExecutionError("'\(invocation.selector)' reaches a directory, and this run was handed none")
        }

        guard case let .string(path) = invocation[key] else {
            throw ExecutionError("'\(invocation.selector)' takes a path as text, and \(invocation[key].nominal) arrived")
        }

        let root = host.directory.standardizedFileURL
        let url = root.appendingPathComponent(path).standardizedFileURL

        guard url.path == root.path || url.path.hasPrefix(root.path + "/") else {
            throw FileFailed("'\(path)' leads out of the directory the host lends", path: path)
        }

        return (url, path)
    }
}
