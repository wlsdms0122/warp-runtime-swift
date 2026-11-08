//
//  String+UTF8.swift
//  WarpSyntax
//
//  Created by JSilver on 10/1/26.
//

import Foundation

extension String {
    // The text the bytes spell, or nil where they are not UTF-8. Every scalar
    // is kept as written, a leading U+FEFF included: here it is a character of
    // the text and not a note about how the bytes are laid out.
    init?(utf8 bytes: some Collection<UInt8>) {
        let decoded = String(decoding: bytes, as: UTF8.self)

        guard decoded.utf8.elementsEqual(bytes) else { return nil }

        self = decoded
    }
}
