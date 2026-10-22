//
//  RunEffect.swift
//  WarpProcess
//

import Foundation
import Warp

struct RunEffect: Effect {
    typealias Parameters = RunParameters

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        guard let host = invocation.environment as? ProcessLending else {
            throw ExecutionError("'\(invocation.selector)' reaches a directory, and this run was handed none")
        }

        guard case let .string(command) = invocation[.command] else {
            throw ExecutionError("'\(invocation.selector)' takes a command as text, and \(invocation[.command].nominal) arrived")
        }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = host.directory
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw ProcessFailed("'\(command)' does not start: \(error.localizedDescription)", command: command)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        return try Value.holding(
            [
                (name: "output", value: .string(String(decoding: data, as: UTF8.self))),
                (name: "status", value: .int(Int(process.terminationStatus)))
            ],
            named: "Process.Result"
        )
    }

    // MARK: - Private
}
