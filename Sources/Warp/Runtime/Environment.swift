//
//  Environment.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What a host hands one run: the services its own procedures reach for, and
// whatever else only that host knows about. The language never reads it; an
// effect recognises its own environment and takes it from here.
public protocol Environment: Sendable {}
