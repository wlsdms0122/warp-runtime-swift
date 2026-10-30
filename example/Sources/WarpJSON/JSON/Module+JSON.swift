//
//  Module+JSON.swift
//  WarpJSON
//

import Foundation
import Warp

public extension Module {
    // JSON as a string, read into a value and written from one. Both are
    // const, so a constant may parse at the build and a string that does not
    // read is refused there.
    static func json() throws -> Module {
        try Module(
            procedures: [
                "JSON.parse": Procedure(
                    signature: Signature(of: ParseQuery.self, returns: .any, failing: .these([JSONFailed.type]), constness: .const, isolation: .isolated),
                    implementation: .query(ParseQuery())
                ),
                "JSON.text": Procedure(
                    signature: Signature(of: TextQuery.self, returns: .string, failing: .these([JSONFailed.type]), constness: .const, isolation: .isolated),
                    implementation: .query(TextQuery())
                )
            ]
        )
    }
}
