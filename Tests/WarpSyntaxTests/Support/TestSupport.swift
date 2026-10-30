//
//  TestSupport.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp
@testable import WarpSyntax

func path(_ text: String) -> Path {
    try! PathParser().parse(text)
}

// A piece of a document read by the reader of that piece, for a test about
// the reader rather than the document around it. A refusal names no document.
func read<T: Decodable>(_ type: T.Type, from value: Value) throws -> T {
    try ValueDecoder(value: value, codingPath: [], steps: [], userInfo: [:]).decode(type)
}
