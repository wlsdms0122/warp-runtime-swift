//
//  ImportSet.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// The words one native word sends: every selector it names, and where each
// stands among them.
//
// A word sends by naming a case, so a word it never declared is a word that
// does not compile. The place is the case's raw value, and the link fills a
// row per place, so the run reads a row where the word wrote a spelling.
//
// This is what a document's `imports` is for a body. A body's sends are read
// off its text; a Swift body is not text the link can read, so the word says
// them.
public protocol ImportSet: CaseIterable, Hashable, Sendable {
    // The declared spelling this reaches, as a link resolves it.
    var selector: Name { get }

    // Where it stands among the word's imports.
    var position: Int { get }
}

public extension ImportSet where Self: RawRepresentable, RawValue == Int {
    var position: Int { rawValue }
}

// A word that sends nothing. Its one case is never reached, which is what
// sending nothing means.
public enum NoImports: Int, ImportSet {
    case none

    public static var allCases: [NoImports] { [] }

    public var selector: Name { "" }
}
