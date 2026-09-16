//
//  Library.swift
//  WarpStandard
//
//  Written by script/embed-library.sh. Edit lib/std and run it again.
//

import Foundation

// The documents of `lib/std`, as they stand in the repository.
enum Library {
    static let documents: [String: String] = [
        "logic": """
            warpt 1
            {
              description "Negation, written from equality."
              imports [
                "std.logic.equal"
              ]
              procedures {
                "std.logic.not" {
                  description "The opposite of a truth."
                  parameters {
                    of "bool"
                  }
                  receiver "of"
                  result {
                    call {
                      arguments {
                        value false
                      }
                      of {
                        ref "of"
                      }
                      procedure "std.logic.equal"
                    }
                  }
                  returns "bool"
                }
              }
              warp 1
            }
            """,
    ]
}
