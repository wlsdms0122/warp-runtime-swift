//
//  ExecutionObserver.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// What a run does, as the language sees it: a statement starts, then completes
// with its value or fails, and a failure is either absorbed by a try or
// not. A statement a `break`, `continue` or `return` leaves never finishes, so
// it has no end event.
public protocol ExecutionObserver: Sendable {
    func statementStarted(at trace: Trace) async
    func statementCompleted(at trace: Trace, result: Value) async
    func statementFailed(at trace: Trace, error: any Error) async

    // The name is the one the failure was bound under while the catch ran,
    // and nothing for a try written nameless.
    func failureCaught(name: String?, error: any Error) async
}

public extension ExecutionObserver {
    func statementStarted(at trace: Trace) async {
    }

    func statementCompleted(at trace: Trace, result: Value) async {
    }

    func statementFailed(at trace: Trace, error: any Error) async {
    }

    func failureCaught(name: String?, error: any Error) async {
    }
}
