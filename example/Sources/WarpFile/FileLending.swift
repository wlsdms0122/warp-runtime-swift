//
//  FileLending.swift
//  WarpFile
//

import Foundation
import Warp

// What a host lends the `file` module: a directory. Every path a program
// writes is read under it, and one that leads out of it is refused.
public protocol FileLending: Environment {
    var directory: URL { get }
}
