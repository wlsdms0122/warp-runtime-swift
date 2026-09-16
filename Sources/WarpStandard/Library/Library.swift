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
    ]
}
