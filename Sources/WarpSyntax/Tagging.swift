//
//  Tagging.swift
//  WarpSyntax
//
//  Created by JSilver on 9/24/26.
//

import Foundation
import Warp

// What a mapping's keys say about it where a form is read by its one key: an
// expression's tags, or a type's. The one question every such reader asks
// before anything else, so a tag stands alone wherever one is read.
enum Tagging<Tag, Payload> {
    // One key, and it is a tag, with what stands under it.
    case one(Tag, Payload)

    // Tags written beside other keys, which no form is.
    case among([Name])

    // No tag at all.
    case none

    // MARK: - Initializer
    init(_ entries: [(name: Name, value: Payload)], reading tag: (Name) -> Tag?) {
        let tags = entries.map(\.name).filter { name in tag(name) != nil }.sorted()

        if entries.count == 1, let (name, value) = entries.first, let read = tag(name) {
            self = .one(read, value)
        } else if tags.isEmpty {
            self = .none
        } else {
            self = .among(tags)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
