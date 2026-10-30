//
//  Implementation.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// How a procedure does what it declares. A body of statements, or native code.
//
// This is the whole of what separates a native procedure from one written as a
// body: which language the body is written in. Both are the same concept
// implemented two ways, so they share one container.
//
// There is one kind of declaration, and this is the axis it varies on. A module
// of native procedures links like any other, and a document calling one is
// doing what a document calling a written body does.
public enum Implementation: Sendable {
    case body(Body)

    // Touches nothing outside the run, so its declaration may say it is
    // const.
    case query(any Query)

    // Reaches outside the run for its return value, so its declaration
    // cannot say it is const.
    case effect(any Effect)

    // MARK: - Property
    // The procedure behind this where it is written in native code. Nil for a
    // body.
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

    // The places a native procedure reads its arguments at, with the name each
    // place stands under. Nil for a body, which reads the names its own
    // declaration gave it.
    var nativeParameters: [(position: Int, name: Name)]? {
        native?.parameters
    }

    // The procedures a native procedure sends, in the places it names them at. Nil for
    // a body, whose sends are read off its text.
    var nativeImports: [Native.Send]? {
        native?.imports
    }

    // The statements a written procedure runs, and nil for native code.
    public var body: Body? {
        guard case let .body(body) = self else { return nil }

        return body
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
