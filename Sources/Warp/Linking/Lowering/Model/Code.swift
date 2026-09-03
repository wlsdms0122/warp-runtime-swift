//
//  Code.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A body as the run reads it: the document's expression with every fact the
// link proved written in. A name is the frame slot the link gave it, a
// selector is the row of the linked table it named, a path word is the row
// it sends, and an argument stands at the position of the parameter it fills.
// What only a run can know, the shape of a value or the signature of a
// closure value, is still asked at the run.
indirect enum Code: Sendable {
    case literal(Value)

    // A slot of the frame, read through a path.
    case local(Int, [Step])

    case array([Code])

    // In name order, the order fields are read in.
    case record([(String, Code)])

    // A closure literal: the row its body was lowered into, and which cells
    // of the frame it takes with it, as (outer slot, inner slot).
    case closure(Linked, captures: [(Int, Int)])

    // Calling a value. Which signature it has is the value's, so the
    // arguments travel by name and settle where the closure is known.
    case invoke(Code, arguments: [(String, Code)])

    case cast(Code, as: TypeExpression, optional: Bool)
    case block(Body)
    case conditional(Code, then: [Instruction], else: [Instruction]?)

    // `keeps` is the range of body slots the result reads, where a round can
    // end early: the result reads what the last finished round bound, so a
    // round cut short is put back before the result reads.
    case loop(while: Code, body: Body, round: Int, keeps: Range<Int>?)

    case iteration(over: Code, body: [Instruction], element: Int)
    case attempt(Body, rescue: Body, failure: Int)
    case send(Send)
    case leave(Leave.Reach, target: String?, Code?)
}
