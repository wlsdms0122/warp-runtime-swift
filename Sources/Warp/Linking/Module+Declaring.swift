//
//  Module+Declaring.swift
//  Warp
//
//  Created by JSilver on 9/9/26.
//

import Foundation

extension Module: Declaring {
    var document: Place.Document { .of(self) }
}
