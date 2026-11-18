//
//  Host.swift
//  warp
//

import Foundation
import WarpConsole
import WarpFile
import WarpProcess

// What this host lends a run: its console and its directory.
struct Host: ConsoleLending, FileLending, ProcessLending {
    // MARK: - Property
    let console: Console
    let directory: URL

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
