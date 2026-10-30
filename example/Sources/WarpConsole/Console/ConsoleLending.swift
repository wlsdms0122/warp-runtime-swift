//
//  ConsoleLending.swift
//  WarpConsole
//

import Foundation
import Warp

// What a host lends the `io` module: its console. The host's environment
// adopts this, and an effect reaches the console through it.
public protocol ConsoleLending: Environment {
    var console: Console { get }
}
