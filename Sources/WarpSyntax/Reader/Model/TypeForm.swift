//
//  TypeForm.swift
//  WarpSyntax
//
//  Created by JSilver on 9/24/26.
//

import Foundation
import Warp

// The keys a type written as a mapping is a form by, one to a mapping. A
// procedure's key carries its mark and modifiers, so it is read rather than
// listed.
enum TypeForm {
    case procedure(mark: SlotMark?, constness: Constness, isolation: Isolation)
    case holding(TypeReader.Holding)
    case record

    // MARK: - Property
    // MARK: - Initializer
    init?(_ key: Name) {
        if let (mark, constness, isolation) = TypeReader.procedureKeywords(of: key.spelling) {
            self = .procedure(mark: mark, constness: constness, isolation: isolation)
        } else if let holding = TypeReader.Holding(rawValue: key.spelling) {
            self = .holding(holding)
        } else if key == TypeReader.recordKey {
            self = .record
        } else {
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
