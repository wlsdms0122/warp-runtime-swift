//
//  CodingUserInfoKey+Reading.swift
//  WarpSyntax
//
//  Created by JSilver on 9/27/26.
//

import Foundation
import Warp

public extension CodingUserInfoKey {
    static let constructRegistry = CodingUserInfoKey(rawValue: "warp.constructRegistry")!
    static let notation = CodingUserInfoKey(rawValue: "warp.notation")!
}
