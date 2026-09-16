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
              description "Negation, difference, choosing and the connectives, written from equality."
              imports [
                "std.collection.count"
                "std.logic.equal"
                "std.math.lessThan"
              ]
              procedures {
                "std.logic.and" {
                  body [
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              let "side"
                              value {
                                ref "of[walk.index]"
                              }
                            }
                            {
                              let "answered"
                              value {
                                apply {
                                  procedure {
                                    ref "side"
                                  }
                                }
                              }
                            }
                            {
                              value {
                                conditional {
                                  then [
                                    {
                                      value {
                                        return false
                                      }
                                    }
                                  ]
                                  when {
                                    call {
                                      arguments {
                                        value false
                                      }
                                      of {
                                        ref "answered"
                                      }
                                      procedure "std.logic.equal"
                                    }
                                  }
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments {
                                value {
                                  call {
                                    of {
                                      ref "of"
                                    }
                                    procedure "std.collection.count"
                                  }
                                }
                              }
                              of {
                                ref "walk.index"
                              }
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Whether every one answers true, asked until one does not."
                  parameters {
                    of {
                      type {
                        array {
                          "pure procedure" {
                            returns "bool"
                          }
                        }
                      }
                    }
                  }
                  receiver "of"
                  result true
                  returns "bool"
                }
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
                "std.logic.notEqual" {
                  description "Whether two values differ."
                  parameters {
                    of {
                      default null
                      type "any"
                    }
                    value {
                      default null
                      type "any"
                    }
                  }
                  receiver "of"
                  result {
                    call {
                      arguments {
                        value false
                      }
                      of {
                        call {
                          arguments {
                            value {
                              ref "value"
                            }
                          }
                          of {
                            ref "of"
                          }
                          procedure "std.logic.equal"
                        }
                      }
                      procedure "std.logic.equal"
                    }
                  }
                  returns "bool"
                }
                "std.logic.or" {
                  body [
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              let "side"
                              value {
                                ref "of[walk.index]"
                              }
                            }
                            {
                              let "answered"
                              value {
                                apply {
                                  procedure {
                                    ref "side"
                                  }
                                }
                              }
                            }
                            {
                              value {
                                conditional {
                                  then [
                                    {
                                      value {
                                        return true
                                      }
                                    }
                                  ]
                                  when {
                                    ref "answered"
                                  }
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments {
                                value {
                                  call {
                                    of {
                                      ref "of"
                                    }
                                    procedure "std.collection.count"
                                  }
                                }
                              }
                              of {
                                ref "walk.index"
                              }
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Whether one answers true, asked until one does."
                  parameters {
                    of {
                      type {
                        array {
                          "pure procedure" {
                            returns "bool"
                          }
                        }
                      }
                    }
                  }
                  receiver "of"
                  result false
                  returns "bool"
                }
              }
              warp 1
            }
            """,
        "math": """
            warpt 1
            {
              description "Ordering the other way round, choosing between two, and dropping a sign. Written from lessThan."
              imports [
                "std.math.lessThan"
                "std.math.minus"
              ]
              procedures {
                "std.math.absolute" {
                  body [
                    {
                      value {
                        conditional {
                          then [
                            {
                              value {
                                return {
                                  call {
                                    arguments {
                                      value {
                                        ref "of"
                                      }
                                    }
                                    of 0
                                    procedure "std.math.minus"
                                  }
                                }
                              }
                            }
                          ]
                          when {
                            call {
                              arguments {
                                value 0
                              }
                              of {
                                ref "of"
                              }
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  bounds {
                    N "std.Numeric"
                  }
                  description "The number without its sign."
                  parameters {
                    of "some N"
                  }
                  receiver "of"
                  result {
                    ref "of"
                  }
                  returns "some N"
                }
                "std.math.greaterThan" {
                  bounds {
                    T "std.Comparable"
                  }
                  description "Whether this one is larger, by the one order."
                  parameters {
                    of "some T"
                    value "some T"
                  }
                  receiver "of"
                  result {
                    call {
                      arguments {
                        value {
                          ref "of"
                        }
                      }
                      of {
                        ref "value"
                      }
                      procedure "std.math.lessThan"
                    }
                  }
                  returns "bool"
                }
                "std.math.max" {
                  body [
                    {
                      value {
                        conditional {
                          then [
                            {
                              value {
                                return {
                                  ref "value"
                                }
                              }
                            }
                          ]
                          when {
                            call {
                              arguments {
                                value {
                                  ref "value"
                                }
                              }
                              of {
                                ref "of"
                              }
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  bounds {
                    T "std.Comparable"
                  }
                  description "The larger of two of a kind, by the one order."
                  parameters {
                    of "some T"
                    value "some T"
                  }
                  receiver "of"
                  result {
                    ref "of"
                  }
                  returns "some T"
                }
                "std.math.min" {
                  body [
                    {
                      value {
                        conditional {
                          then [
                            {
                              value {
                                return {
                                  ref "of"
                                }
                              }
                            }
                          ]
                          when {
                            call {
                              arguments {
                                value {
                                  ref "value"
                                }
                              }
                              of {
                                ref "of"
                              }
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  bounds {
                    T "std.Comparable"
                  }
                  description "The smaller of two of a kind, by the one order."
                  parameters {
                    of "some T"
                    value "some T"
                  }
                  receiver "of"
                  result {
                    ref "value"
                  }
                  returns "some T"
                }
              }
              warp 1
            }
            """,
        "text": """
            warpt 1
            {
              description "Scanning text, written from its characters."
              imports [
                "std.collection.appending"
                "std.collection.count"
                "std.control.abort"
                "std.logic.equal"
                "std.logic.not"
                "std.math.lessThan"
                "std.math.plus"
                "std.text.characters"
                "std.text.joined"
              ]
              procedures {
                "std.text.replacing" {
                  body [
                    {
                      value {
                        conditional {
                          then [
                            {
                              value {
                                call {
                                  of "replacing asks an empty piece"
                                  procedure "std.control.abort"
                                }
                              }
                            }
                          ]
                          when {
                            call {
                              arguments {
                                value ""
                              }
                              of {
                                ref "value"
                              }
                              procedure "std.logic.equal"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Every occurrence of a piece swapped for another."
                  parameters {
                    of "string"
                    value "string"
                    with "string"
                  }
                  receiver "of"
                  result {
                    call {
                      arguments {
                        value {
                          ref "with"
                        }
                      }
                      of {
                        call {
                          arguments {
                            value {
                              ref "value"
                            }
                          }
                          of {
                            ref "of"
                          }
                          procedure "std.text.split"
                        }
                      }
                      procedure "std.text.joined"
                    }
                  }
                  returns "string"
                }
                "std.text.split" {
                  body [
                    {
                      let "held"
                      value {
                        call {
                          of {
                            ref "of"
                          }
                          procedure "std.text.characters"
                        }
                      }
                    }
                    {
                      let "heldCount"
                      value {
                        call {
                          of {
                            ref "held"
                          }
                          procedure "std.collection.count"
                        }
                      }
                    }
                    {
                      let "wanted"
                      value {
                        call {
                          of {
                            ref "value"
                          }
                          procedure "std.text.characters"
                        }
                      }
                    }
                    {
                      let "wantedCount"
                      value {
                        call {
                          of {
                            ref "wanted"
                          }
                          procedure "std.collection.count"
                        }
                      }
                    }
                    {
                      value {
                        conditional {
                          then [
                            {
                              value {
                                call {
                                  of "split asks an empty separator"
                                  procedure "std.control.abort"
                                }
                              }
                            }
                          ]
                          when {
                            call {
                              arguments {
                                value 0
                              }
                              of {
                                ref "wantedCount"
                              }
                              procedure "std.logic.equal"
                            }
                          }
                        }
                      }
                    }
                    {
                      value []
                      var "pieces"
                    }
                    {
                      value []
                      var "current"
                    }
                    {
                      value 0
                      var "at"
                    }
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              value {
                                call {
                                  of {
                                    call {
                                      arguments {
                                        value {
                                          call {
                                            arguments {
                                              value {
                                                ref "wantedCount"
                                              }
                                            }
                                            of {
                                              ref "at"
                                            }
                                            procedure "std.math.plus"
                                          }
                                        }
                                      }
                                      of {
                                        ref "heldCount"
                                      }
                                      procedure "std.math.lessThan"
                                    }
                                  }
                                  procedure "std.logic.not"
                                }
                              }
                              var "matched"
                            }
                            {
                              value {
                                conditional {
                                  then [
                                    {
                                      let "probe"
                                      value {
                                        loop {
                                          body [
                                            {
                                              let "offset"
                                              value {
                                                call {
                                                  arguments {
                                                    value {
                                                      ref "probe.index"
                                                    }
                                                  }
                                                  of {
                                                    ref "at"
                                                  }
                                                  procedure "std.math.plus"
                                                }
                                              }
                                            }
                                            {
                                              value {
                                                conditional {
                                                  then [
                                                    {
                                                      set "matched"
                                                      value false
                                                    }
                                                    {
                                                      value {
                                                        break null
                                                      }
                                                    }
                                                  ]
                                                  when {
                                                    call {
                                                      of {
                                                        call {
                                                          arguments {
                                                            value {
                                                              ref "wanted[probe.index]"
                                                            }
                                                          }
                                                          of {
                                                            ref "held[offset]"
                                                          }
                                                          procedure "std.logic.equal"
                                                        }
                                                      }
                                                      procedure "std.logic.not"
                                                    }
                                                  }
                                                }
                                              }
                                            }
                                          ]
                                          while {
                                            call {
                                              arguments {
                                                value {
                                                  ref "wantedCount"
                                                }
                                              }
                                              of {
                                                ref "probe.index"
                                              }
                                              procedure "std.math.lessThan"
                                            }
                                          }
                                        }
                                      }
                                    }
                                  ]
                                  when {
                                    ref "matched"
                                  }
                                }
                              }
                            }
                            {
                              value {
                                conditional {
                                  else [
                                    {
                                      set "current"
                                      value {
                                        call {
                                          arguments {
                                            value {
                                              ref "held[at]"
                                            }
                                          }
                                          of {
                                            ref "current"
                                          }
                                          procedure "std.collection.appending"
                                        }
                                      }
                                    }
                                    {
                                      set "at"
                                      value {
                                        call {
                                          arguments {
                                            value 1
                                          }
                                          of {
                                            ref "at"
                                          }
                                          procedure "std.math.plus"
                                        }
                                      }
                                    }
                                  ]
                                  then [
                                    {
                                      set "pieces"
                                      value {
                                        call {
                                          arguments {
                                            value {
                                              call {
                                                of {
                                                  ref "current"
                                                }
                                                procedure "std.text.joined"
                                              }
                                            }
                                          }
                                          of {
                                            ref "pieces"
                                          }
                                          procedure "std.collection.appending"
                                        }
                                      }
                                    }
                                    {
                                      set "current"
                                      value []
                                    }
                                    {
                                      set "at"
                                      value {
                                        call {
                                          arguments {
                                            value {
                                              ref "wantedCount"
                                            }
                                          }
                                          of {
                                            ref "at"
                                          }
                                          procedure "std.math.plus"
                                        }
                                      }
                                    }
                                  ]
                                  when {
                                    ref "matched"
                                  }
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments {
                                value {
                                  ref "heldCount"
                                }
                              }
                              of {
                                ref "at"
                              }
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "The text cut on a separator."
                  parameters {
                    of "string"
                    value "string"
                  }
                  receiver "of"
                  result {
                    call {
                      arguments {
                        value {
                          call {
                            of {
                              ref "current"
                            }
                            procedure "std.text.joined"
                          }
                        }
                      }
                      of {
                        ref "pieces"
                      }
                      procedure "std.collection.appending"
                    }
                  }
                  returns "array<string>"
                }
                "std.text.startsWith" {
                  body [
                    {
                      let "held"
                      value {
                        call {
                          of {
                            ref "of"
                          }
                          procedure "std.text.characters"
                        }
                      }
                    }
                    {
                      let "wanted"
                      value {
                        call {
                          of {
                            ref "value"
                          }
                          procedure "std.text.characters"
                        }
                      }
                    }
                    {
                      value {
                        conditional {
                          then [
                            {
                              value {
                                return false
                              }
                            }
                          ]
                          when {
                            call {
                              arguments {
                                value {
                                  call {
                                    of {
                                      ref "wanted"
                                    }
                                    procedure "std.collection.count"
                                  }
                                }
                              }
                              of {
                                call {
                                  of {
                                    ref "held"
                                  }
                                  procedure "std.collection.count"
                                }
                              }
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              value {
                                conditional {
                                  then [
                                    {
                                      value {
                                        return false
                                      }
                                    }
                                  ]
                                  when {
                                    call {
                                      of {
                                        call {
                                          arguments {
                                            value {
                                              ref "wanted[walk.index]"
                                            }
                                          }
                                          of {
                                            ref "held[walk.index]"
                                          }
                                          procedure "std.logic.equal"
                                        }
                                      }
                                      procedure "std.logic.not"
                                    }
                                  }
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments {
                                value {
                                  call {
                                    of {
                                      ref "wanted"
                                    }
                                    procedure "std.collection.count"
                                  }
                                }
                              }
                              of {
                                ref "walk.index"
                              }
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Whether a string begins with another."
                  parameters {
                    of "string"
                    value "string"
                  }
                  receiver "of"
                  result true
                  returns "bool"
                }
              }
              warp 1
            }
            """,
    ]
}
