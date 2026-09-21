//
//  Access.swift
//  Warp
//
//  Created by JSilver on 9/21/26.
//

import Foundation

// Who may name a declaration. Three scopes, from the document that declares it
// out to the caller that assembles the link, and a declaration is named from
// inside its scope and refused from outside it.
public enum Access: String, Sendable, Equatable, CaseIterable {
    // The document that declares it, and nothing else.
    case `private`

    // Every document in the link. What a declaration is when it says nothing.
    case `internal`

    // The link and the caller. The only kind a run may start from.
    case `public`

    // MARK: - Property
    // Whether a document other than the declaring one may name this.
    public var reachesOtherDocuments: Bool { self != .private }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
