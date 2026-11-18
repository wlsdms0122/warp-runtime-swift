//
//  ProcessResult.swift
//  WarpProcess
//

import Foundation
import Warp
import WarpMacros

// What a command left: what it wrote, and the status it exited with.
@ValueRepresentable("Process.Result")
struct ProcessResult {
    // MARK: - Property
    let output: String
    let status: Int

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
