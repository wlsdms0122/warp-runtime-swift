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
