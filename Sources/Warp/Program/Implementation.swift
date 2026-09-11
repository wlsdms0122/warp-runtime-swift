//
//  Implementation.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// How a procedure does what it declares. A body of statements, or native code.
//
// This is the whole of what separates a native word from a procedure: which
// language the body is written in. Both are the same concept answered two ways,
// so they share one container.
//
// There is one kind of declaration, and this is the axis it varies on. A module
// of native words links like any other, and a document calling one is doing what
// a document calling a procedure does.
public enum Implementation: Sendable {
    case body(Block)

    // Answers without running anything. Pure and synchronous, which is what
    // lets it be asked inside a condition and inside a path.
    case query(any Query)

    // Answers by reaching outside the run. Asynchronous, so it cannot be asked
    // where a value is merely read.
    case effect(any Effect)

    // MARK: - Property
    // The word behind this where it is written in native code, which is what
    // declares its own purity, isolation and failing. Nil for a body, whose
    // claims are what its code turns out to do.
    var native: Native? {
        switch self {
        case .body:
            return nil

        case let .query(query):
            return .query(query)

        case let .effect(effect):
            return .effect(effect)
        }
    }

    // What a native declares about itself, in the answers a builder works out
    // for a body. Nil where nothing was declared, which is what a body is.
    public var isNativelyPure: Bool? {
        native.map { word in word.purity == .pure }
    }

    public var isNativelyIsolated: Bool? {
        native.map { word in word.isolation == .isolated }
    }

    public var nativelyFailing: Failing? {
        native?.failing
    }

    // The places a native word reads its arguments at, with the name each
    // place stands under. Nil for a body, which reads the names its own
    // declaration gave it.
    var nativeParameters: [(position: Int, name: Name)]? {
        native?.parameters
    }

    // The words a native word sends, in the places it names them at. Nil for
    // a body, whose sends are read off its text.
    var nativeImports: [(position: Int, selector: Name)]? {
        native?.imports
    }

    public var block: Block? {
        guard case let .body(block) = self else { return nil }

        return block
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
