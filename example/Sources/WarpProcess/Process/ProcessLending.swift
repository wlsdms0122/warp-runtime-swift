//
//  ProcessLending.swift
//  WarpProcess
//

import Foundation
import Warp

// What a host lends the `process` module: the directory a command runs in.
public protocol ProcessLending: Environment {
    var directory: URL { get }
}
