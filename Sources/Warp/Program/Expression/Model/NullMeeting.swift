//
//  NullMeeting.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// What a segment does when the walk meets null. The one rule, owned here so the
// link's walk over types and the run's walk over values cannot drift: an
// optional segment (`?.`, `?[`) reads the absence as null for the rest of the
// path, and a plain one refuses.
enum NullMeeting {
    case reads
    case refused(String)
}
