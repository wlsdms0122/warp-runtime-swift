//
//  CodingKey+Name.swift
//  WarpSyntax
//
//  Created by JSilver on 9/30/26.
//

import Foundation
import Warp

extension CodingKey {
    // A notation's reserved key as the name it stands for. These spellings
    // are written in this source rather than read out of a document.
    var name: Name { Name(normal: stringValue) }
}
