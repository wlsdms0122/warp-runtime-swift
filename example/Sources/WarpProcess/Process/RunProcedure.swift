//
//  RunProcedure.swift
//  WarpProcess
//

import Foundation
import Warp
import WarpMacros

@ProcedureConvertible("Process.run", failing: .these([ProcessFailed.type]))
struct RunProcedure: Effect {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(command: String, invocation: Invocation<Self>) async throws -> ProcessResult {
        guard let host = invocation.environment as? ProcessLending else {
            throw RunRefused("'\(invocation.selector)' reaches a directory, and this run was handed none")
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

        return ProcessResult(output: String(decoding: data, as: UTF8.self), status: Int(process.terminationStatus))
    }

    // MARK: - Private
}
