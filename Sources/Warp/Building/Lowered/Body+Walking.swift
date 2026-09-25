//
//  Body+Walking.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// Every operation and instruction a body holds, outermost first. What a
// reading of the code asks is answered node by node; how the code nests is
// answered by each kind of node walking what it holds.
//
// A reading walks and a relocation rewrites (`Body+Rewriting`), and the two
// stay apart: a reading stops where it has its answer and builds nothing.
extension Body {
    enum Node {
        case operation(Operation)
        case instruction(Instruction)
    }

    // Whether the walk went the whole way. A visit answering false stops it.
    @discardableResult
    func walk(_ visit: (Node) -> Bool) -> Bool {
        instructions.allSatisfy { instruction in instruction.walk(visit) }
            && (result?.walk(visit) ?? true)
    }

    // Whether any node answers, stopping at the first that does.
    func contains(where predicate: (Node) -> Bool) -> Bool {
        !walk { node in !predicate(node) }
    }
}
