//
//  Double+Spelling.swift
//  Warp
//
//  Created by JSilver on 8/24/26.
//

import Foundation

extension Double {
    // The fraction as something to read, spelled where a document spells it and
    // said in this vocabulary's own terms where none does. Only a host's hand
    // brings an infinity or a nan here, and every surface that has to show one
    // says it the same way rather than in whatever the host's formatter says
    // today.
    //
    // Apart from `spelling` because the two are asked by different callers: a
    // message shows whatever it was handed, and a document may only carry what
    // reads back.
    var shown: String {
        guard isFinite else {
            guard !isNaN else { return "<not a number>" }

            return self > 0 ? "<infinity>" : "<-infinity>"
        }

        return spelling ?? "<unspellable>"
    }

    // The one spelling a document writes a fraction in, and every judge of a
    // fraction's spelling (the writer, the boundary's enum, the link's
    // candidate check) reads this one answer. Nil for what no document carries.
    //
    // The digits are the host's shortest round-trip rendering; the *form* is
    // the document's own rule, assembled here so a host's presentation taste
    // cannot leak into the grammar: writing d.ddd…×10^k, the point form when -5
    // < k < 16, otherwise the exponent form with an explicit sign and at least
    // two digits. `1e-05`, `1e+16`.
    public var spelling: String? {
        guard isFinite else { return nil }

        let signed = sign == .minus ? "-" : ""

        guard self != 0 else { return signed + "0.0" }

        // Take the shortest digits apart: mantissa text and exponent, then
        // the significant digits and where the first of them stands.
        let plain = "\(magnitude)"
        let halves = plain.split(separator: "e", maxSplits: 1)

        // The exponent behind `e` is the host's own rendering, so no finite
        // fraction takes this way out.
        guard let shift = halves.count == 2 ? Int(halves[1]) : 0 else { return nil }
        let pieces = halves[0].split(separator: ".", maxSplits: 1)
        let whole = pieces[0]
        let fractional = pieces.count == 2 ? pieces[1] : ""

        var digits = Array(whole + fractional)
        let leading = digits.prefix { digit in digit == "0" }.count

        digits.removeFirst(leading)

        while digits.last == "0" { digits.removeLast() }

        let exponent = whole.count - 1 - leading + shift

        // The exponent form: one digit, the rest after the point, and the
        // signed two-digit-minimum exponent.
        guard exponent > -5, exponent < 16 else {
            let head = String(digits[0])
            let tail = digits.count > 1 ? "." + String(digits[1...]) : ""

            return signed + head + tail + "e" + String(format: "%+03d", exponent)
        }

        // The point form, the point always present.
        if exponent >= 0 {
            let count = exponent + 1
            let padded = digits + Array(repeating: "0", count: max(0, count - digits.count))
            let fraction = padded.count > count ? String(padded[count...]) : "0"

            return signed + String(padded[..<count]) + "." + fraction
        }

        return signed + "0." + String(repeating: "0", count: -exponent - 1) + String(digits)
    }

    // The fraction-side door beside `Int.init?(spelling:)`: the text must be
    // the value's own one spelling, so `1e0` and `1.50` read as nothing.
    // Public because the document readers hold the same line.
    public init?(spelling: String) {
        guard let fraction = Double(spelling), fraction.spelling == spelling else {
            return nil
        }

        self = fraction
    }
}
