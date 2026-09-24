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
        "collection": """
            warpt 1
            {
              description "Reading a collection by walking it, written from its count and its index."
              imports [
                "std.Comparable"
                "std.collection.appending"
                "std.collection.count"
                "std.collection.gathering"
                "std.collection.keys"
                "std.logic.equal"
                "std.math.lessThan"
                "std.math.minus"
                "std.math.plus"
              ]
              procedures {
                "std.collection.append" {
                  body [
                    {
                      set "array"
                      value {
                        call {
                          arguments [
                            {
                              ref "array"
                            }
                            {
                              ref "element"
                            }
                          ]
                          procedure "std.collection.appending"
                        }
                      }
                    }
                  ]
                  description "Writes one element onto the end of the array a variable holds, in place."
                  parameters [
                    {
                      name "array"
                      type "inout array<some Element>"
                    }
                    {
                      name "element"
                      type "some Element"
                    }
                  ]
                  result null
                  returns "null"
                }
                "std.collection.contains" {
                  body [
                    {
                      value false
                      var "found"
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
                                      set "found"
                                      value true
                                    }
                                    {
                                      value {
                                        break null
                                      }
                                    }
                                  ]
                                  when {
                                    call {
                                      arguments [
                                        {
                                          ref "array[walk.index]"
                                        }
                                        {
                                          ref "element"
                                        }
                                      ]
                                      procedure "std.logic.equal"
                                    }
                                  }
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "array"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Whether an array holds a value."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                    {
                      name "element"
                      type "some Element"
                    }
                  ]
                  result {
                    ref "found"
                  }
                  returns "bool"
                }
                "std.collection.dropFirst" {
                  body [
                    {
                      value []
                      var "places"
                    }
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              set "places"
                              value {
                                call {
                                  arguments [
                                    {
                                      ref "places"
                                    }
                                    {
                                      call {
                                        arguments [
                                          {
                                            ref "walk.index"
                                          }
                                          1
                                        ]
                                        procedure "std.math.plus"
                                      }
                                    }
                                  ]
                                  procedure "std.collection.appending"
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        call {
                                          arguments [
                                            {
                                              ref "array"
                                            }
                                          ]
                                          procedure "std.collection.count"
                                        }
                                      }
                                      1
                                    ]
                                    procedure "std.math.minus"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "The elements after the first."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          ref "array"
                        }
                        {
                          ref "places"
                        }
                      ]
                      procedure "std.collection.gathering"
                    }
                  }
                  returns "array<some Element>"
                }
                "std.collection.dropLast" {
                  body [
                    {
                      value []
                      var "places"
                    }
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              set "places"
                              value {
                                call {
                                  arguments [
                                    {
                                      ref "places"
                                    }
                                    {
                                      ref "walk.index"
                                    }
                                  ]
                                  procedure "std.collection.appending"
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        call {
                                          arguments [
                                            {
                                              ref "array"
                                            }
                                          ]
                                          procedure "std.collection.count"
                                        }
                                      }
                                      1
                                    ]
                                    procedure "std.math.minus"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "The elements before the last."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          ref "array"
                        }
                        {
                          ref "places"
                        }
                      ]
                      procedure "std.collection.gathering"
                    }
                  }
                  returns "array<some Element>"
                }
                "std.collection.filter" {
                  body [
                    {
                      value []
                      var "places"
                    }
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              let "kept"
                              value {
                                call {
                                  arguments [
                                    {
                                      ref "array[walk.index]"
                                    }
                                  ]
                                  procedure {
                                    ref "isIncluded"
                                  }
                                }
                              }
                            }
                            {
                              value {
                                conditional {
                                  then [
                                    {
                                      set "places"
                                      value {
                                        call {
                                          arguments [
                                            {
                                              ref "places"
                                            }
                                            {
                                              ref "walk.index"
                                            }
                                          ]
                                          procedure "std.collection.appending"
                                        }
                                      }
                                    }
                                  ]
                                  when {
                                    ref "kept"
                                  }
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "array"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "The elements a procedure answers true for."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                    {
                      name "isIncluded"
                      type {
                        "const procedure" {
                          parameters [
                            "some Element"
                          ]
                          returns "bool"
                        }
                      }
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          ref "array"
                        }
                        {
                          ref "places"
                        }
                      ]
                      procedure "std.collection.gathering"
                    }
                  }
                  returns "array<some Element>"
                }
                "std.collection.first" {
                  description "The first element, or nothing."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                  ]
                  result {
                    ref "array[0]"
                  }
                  returns "some Element"
                }
                "std.collection.last" {
                  body [
                    {
                      let "at"
                      value {
                        call {
                          arguments [
                            {
                              call {
                                arguments [
                                  {
                                    ref "array"
                                  }
                                ]
                                procedure "std.collection.count"
                              }
                            }
                            1
                          ]
                          procedure "std.math.minus"
                        }
                      }
                    }
                  ]
                  description "The last element, or nothing."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                  ]
                  result {
                    ref "array[at]"
                  }
                  returns "some Element"
                }
                "std.collection.map" {
                  body [
                    {
                      value []
                      var "answers"
                    }
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              let "answered"
                              value {
                                call {
                                  arguments [
                                    {
                                      ref "array[walk.index]"
                                    }
                                  ]
                                  procedure {
                                    ref "transform"
                                  }
                                }
                              }
                            }
                            {
                              set "answers"
                              value {
                                call {
                                  arguments [
                                    {
                                      ref "answers"
                                    }
                                    {
                                      ref "answered"
                                    }
                                  ]
                                  procedure "std.collection.appending"
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "array"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Each element answered by a procedure, in order."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                    {
                      name "transform"
                      type {
                        "const procedure" {
                          parameters [
                            "some Element"
                          ]
                          returns "some Answer"
                        }
                      }
                    }
                  ]
                  result {
                    ref "answers"
                  }
                  returns "array<some Answer>"
                }
                "std.collection.prepending" {
                  body [
                    {
                      let "back"
                      value {
                        call {
                          arguments [
                            {
                              ref "array"
                            }
                          ]
                          procedure "std.collection.reversed"
                        }
                      }
                    }
                    {
                      let "grown"
                      value {
                        call {
                          arguments [
                            {
                              ref "back"
                            }
                            {
                              ref "element"
                            }
                          ]
                          procedure "std.collection.appending"
                        }
                      }
                    }
                  ]
                  description "The elements with one more at the front."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                    {
                      name "element"
                      type "some Element"
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          ref "grown"
                        }
                      ]
                      procedure "std.collection.reversed"
                    }
                  }
                  returns "array<some Element>"
                }
                "std.collection.reduce" {
                  body [
                    {
                      value {
                        ref "initialResult"
                      }
                      var "carried"
                    }
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              let "answered"
                              value {
                                call {
                                  arguments [
                                    {
                                      ref "carried"
                                    }
                                    {
                                      ref "array[walk.index]"
                                    }
                                  ]
                                  procedure {
                                    ref "nextPartialResult"
                                  }
                                }
                              }
                            }
                            {
                              set "carried"
                              value {
                                ref "answered"
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "array"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "The elements folded into one, starting from a value."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                    {
                      name "initialResult"
                      type "some Carried"
                    }
                    {
                      name "nextPartialResult"
                      type {
                        "const procedure" {
                          parameters [
                            "some Carried"
                            "some Element"
                          ]
                          returns "some Carried"
                        }
                      }
                    }
                  ]
                  result {
                    ref "carried"
                  }
                  returns "some Carried"
                }
                "std.collection.reversed" {
                  body [
                    {
                      value []
                      var "places"
                    }
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              set "places"
                              value {
                                call {
                                  arguments [
                                    {
                                      ref "places"
                                    }
                                    {
                                      call {
                                        arguments [
                                          {
                                            call {
                                              arguments [
                                                {
                                                  ref "array"
                                                }
                                              ]
                                              procedure "std.collection.count"
                                            }
                                          }
                                          {
                                            call {
                                              arguments [
                                                {
                                                  ref "walk.index"
                                                }
                                                1
                                              ]
                                              procedure "std.math.plus"
                                            }
                                          }
                                        ]
                                        procedure "std.math.minus"
                                      }
                                    }
                                  ]
                                  procedure "std.collection.appending"
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "array"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "The elements back to front."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          ref "array"
                        }
                        {
                          ref "places"
                        }
                      ]
                      procedure "std.collection.gathering"
                    }
                  }
                  returns "array<some Element>"
                }
                "std.collection.sorted" {
                  body [
                    {
                      let "total"
                      value {
                        call {
                          arguments [
                            {
                              ref "array"
                            }
                          ]
                          procedure "std.collection.count"
                        }
                      }
                    }
                    {
                      value []
                      var "ranks"
                    }
                    {
                      let "outer"
                      value {
                        loop {
                          body [
                            {
                              value 0
                              var "rank"
                            }
                            {
                              let "inner"
                              value {
                                loop {
                                  body [
                                    {
                                      value true
                                      var "tie"
                                    }
                                    {
                                      value {
                                        conditional {
                                          then [
                                            {
                                              set "rank"
                                              value {
                                                call {
                                                  arguments [
                                                    {
                                                      ref "rank"
                                                    }
                                                    1
                                                  ]
                                                  procedure "std.math.plus"
                                                }
                                              }
                                            }
                                            {
                                              set "tie"
                                              value false
                                            }
                                          ]
                                          when {
                                            call {
                                              arguments [
                                                {
                                                  ref "array[inner.index]"
                                                }
                                                {
                                                  ref "array[outer.index]"
                                                }
                                              ]
                                              procedure "std.math.lessThan"
                                            }
                                          }
                                        }
                                      }
                                    }
                                    {
                                      value {
                                        conditional {
                                          then [
                                            {
                                              set "tie"
                                              value false
                                            }
                                          ]
                                          when {
                                            call {
                                              arguments [
                                                {
                                                  ref "array[outer.index]"
                                                }
                                                {
                                                  ref "array[inner.index]"
                                                }
                                              ]
                                              procedure "std.math.lessThan"
                                            }
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
                                                conditional {
                                                  then [
                                                    {
                                                      set "rank"
                                                      value {
                                                        call {
                                                          arguments [
                                                            {
                                                              ref "rank"
                                                            }
                                                            1
                                                          ]
                                                          procedure "std.math.plus"
                                                        }
                                                      }
                                                    }
                                                  ]
                                                  when {
                                                    call {
                                                      arguments [
                                                        {
                                                          ref "inner.index"
                                                        }
                                                        {
                                                          ref "outer.index"
                                                        }
                                                      ]
                                                      procedure "std.math.lessThan"
                                                    }
                                                  }
                                                }
                                              }
                                            }
                                          ]
                                          when {
                                            ref "tie"
                                          }
                                        }
                                      }
                                    }
                                  ]
                                  while {
                                    call {
                                      arguments [
                                        {
                                          ref "inner.index"
                                        }
                                        {
                                          ref "total"
                                        }
                                      ]
                                      procedure "std.math.lessThan"
                                    }
                                  }
                                }
                              }
                            }
                            {
                              set "ranks"
                              value {
                                call {
                                  arguments [
                                    {
                                      ref "ranks"
                                    }
                                    {
                                      ref "rank"
                                    }
                                  ]
                                  procedure "std.collection.appending"
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "outer.index"
                                }
                                {
                                  ref "total"
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                    {
                      value []
                      var "places"
                    }
                    {
                      let "pick"
                      value {
                        loop {
                          body [
                            {
                              let "scan"
                              value {
                                loop {
                                  body [
                                    {
                                      value true
                                      var "same"
                                    }
                                    {
                                      value {
                                        conditional {
                                          then [
                                            {
                                              set "same"
                                              value false
                                            }
                                          ]
                                          when {
                                            call {
                                              arguments [
                                                {
                                                  ref "ranks[scan.index]"
                                                }
                                                {
                                                  ref "pick.index"
                                                }
                                              ]
                                              procedure "std.math.lessThan"
                                            }
                                          }
                                        }
                                      }
                                    }
                                    {
                                      value {
                                        conditional {
                                          then [
                                            {
                                              set "same"
                                              value false
                                            }
                                          ]
                                          when {
                                            call {
                                              arguments [
                                                {
                                                  ref "pick.index"
                                                }
                                                {
                                                  ref "ranks[scan.index]"
                                                }
                                              ]
                                              procedure "std.math.lessThan"
                                            }
                                          }
                                        }
                                      }
                                    }
                                    {
                                      value {
                                        conditional {
                                          then [
                                            {
                                              set "places"
                                              value {
                                                call {
                                                  arguments [
                                                    {
                                                      ref "places"
                                                    }
                                                    {
                                                      ref "scan.index"
                                                    }
                                                  ]
                                                  procedure "std.collection.appending"
                                                }
                                              }
                                            }
                                          ]
                                          when {
                                            ref "same"
                                          }
                                        }
                                      }
                                    }
                                  ]
                                  while {
                                    call {
                                      arguments [
                                        {
                                          ref "scan.index"
                                        }
                                        {
                                          ref "total"
                                        }
                                      ]
                                      procedure "std.math.lessThan"
                                    }
                                  }
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "pick.index"
                                }
                                {
                                  ref "total"
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  bounds {
                    Element "std.Comparable"
                  }
                  description "The elements in order, for numbers or for strings."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          ref "array"
                        }
                        {
                          ref "places"
                        }
                      ]
                      procedure "std.collection.gathering"
                    }
                  }
                  returns "array<some Element>"
                }
                "std.collection.values" {
                  body [
                    {
                      let "names"
                      value {
                        call {
                          arguments [
                            {
                              ref "dictionary"
                            }
                          ]
                          procedure "std.collection.keys"
                        }
                      }
                    }
                    {
                      value []
                      var "held"
                    }
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              let "name"
                              value {
                                ref "names[walk.index]"
                              }
                            }
                            {
                              set "held"
                              value {
                                call {
                                  arguments [
                                    {
                                      ref "held"
                                    }
                                    {
                                      ref "dictionary[name]"
                                    }
                                  ]
                                  procedure "std.collection.appending"
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "names"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "What a record holds, by its names in order."
                  parameters [
                    {
                      name "dictionary"
                      type "dictionary<some Entry>"
                    }
                  ]
                  result {
                    ref "held"
                  }
                  returns "array<some Entry>"
                }
              }
              warp 1
            }
            """,
        "concurrent": """
            warpt 1
            {
              description "Running one closure once per element, written from the fan-out that runs a list of them."
              imports [
                "std.collection.appending"
                "std.collection.count"
                "std.concurrent.all"
                "std.math.lessThan"
              ]
              procedures {
                "std.concurrent.map" {
                  body [
                    {
                      value []
                      var "pieces"
                    }
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              let "item"
                              value {
                                ref "array[walk.index]"
                              }
                            }
                            {
                              let "index"
                              value {
                                ref "walk.index"
                              }
                            }
                            {
                              let "piece"
                              value {
                                closure {
                                  body [
                                    {
                                      let "answered"
                                      value {
                                        call {
                                          arguments [
                                            {
                                              ref "item"
                                            }
                                            {
                                              ref "index"
                                            }
                                          ]
                                          procedure {
                                            ref "transform"
                                          }
                                        }
                                      }
                                    }
                                  ]
                                  result {
                                    ref "answered"
                                  }
                                }
                              }
                            }
                            {
                              set "pieces"
                              value {
                                call {
                                  arguments [
                                    {
                                      ref "pieces"
                                    }
                                    {
                                      ref "piece"
                                    }
                                  ]
                                  procedure "std.collection.appending"
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "array"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Each element answered by a procedure, run at once, in the collection's order."
                  parameters [
                    {
                      name "array"
                      type "array<some Element>"
                    }
                    {
                      name "transform"
                      type {
                        "isolated procedure" {
                          parameters [
                            "some Element"
                            "int"
                          ]
                          returns "some Answer"
                        }
                      }
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          ref "pieces"
                        }
                      ]
                      procedure "std.concurrent.all"
                    }
                  }
                  returns "array<some Answer>"
                }
              }
              warp 1
            }
            """,
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
                                ref "conditions[walk.index]"
                              }
                            }
                            {
                              let "answered"
                              value {
                                call {
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
                                      arguments [
                                        {
                                          ref "answered"
                                        }
                                        false
                                      ]
                                      procedure "std.logic.equal"
                                    }
                                  }
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "conditions"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Whether every one answers true, asked until one does not."
                  parameters [
                    {
                      name "conditions"
                      type {
                        array {
                          "const procedure" {
                            returns "bool"
                          }
                        }
                      }
                    }
                  ]
                  result true
                  returns "bool"
                }
                "std.logic.not" {
                  description "The opposite of a truth."
                  parameters [
                    {
                      name "value"
                      type "bool"
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          ref "value"
                        }
                        false
                      ]
                      procedure "std.logic.equal"
                    }
                  }
                  returns "bool"
                }
                "std.logic.notEqual" {
                  description "Whether two values differ."
                  parameters [
                    {
                      name "lhs"
                      type "any"
                    }
                    {
                      name "rhs"
                      type "any"
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          call {
                            arguments [
                              {
                                ref "lhs"
                              }
                              {
                                ref "rhs"
                              }
                            ]
                            procedure "std.logic.equal"
                          }
                        }
                        false
                      ]
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
                                ref "conditions[walk.index]"
                              }
                            }
                            {
                              let "answered"
                              value {
                                call {
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
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "conditions"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Whether one answers true, asked until one does."
                  parameters [
                    {
                      name "conditions"
                      type {
                        array {
                          "const procedure" {
                            returns "bool"
                          }
                        }
                      }
                    }
                  ]
                  result false
                  returns "bool"
                }
                "std.logic.select" {
                  body [
                    {
                      value {
                        conditional {
                          then [
                            {
                              let "taken"
                              value {
                                call {
                                  procedure {
                                    ref "then"
                                  }
                                }
                              }
                            }
                            {
                              value {
                                return {
                                  ref "taken"
                                }
                              }
                            }
                          ]
                          when {
                            ref "condition"
                          }
                        }
                      }
                    }
                    {
                      let "left"
                      value {
                        call {
                          procedure {
                            ref "else"
                          }
                        }
                      }
                    }
                  ]
                  description "The value one of two sides answers, chosen by a truth."
                  parameters [
                    {
                      name "condition"
                      type "bool"
                    }
                    {
                      name "then"
                      type {
                        "const procedure" {
                          returns "some Answer"
                        }
                      }
                    }
                    {
                      name "else"
                      type {
                        "const procedure" {
                          returns "some Answer"
                        }
                      }
                    }
                  ]
                  result {
                    ref "left"
                  }
                  returns "some Answer"
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
                "std.Comparable"
                "std.Numeric"
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
                                    arguments [
                                      0
                                      {
                                        ref "number"
                                      }
                                    ]
                                    procedure "std.math.minus"
                                  }
                                }
                              }
                            }
                          ]
                          when {
                            call {
                              arguments [
                                {
                                  ref "number"
                                }
                                0
                              ]
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
                  parameters [
                    {
                      name "number"
                      type "some N"
                    }
                  ]
                  result {
                    ref "number"
                  }
                  returns "some N"
                }
                "std.math.greaterThan" {
                  bounds {
                    T "std.Comparable"
                  }
                  description "Whether this one is larger, by the one order."
                  parameters [
                    {
                      name "lhs"
                      type "some T"
                    }
                    {
                      name "rhs"
                      type "some T"
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          ref "rhs"
                        }
                        {
                          ref "lhs"
                        }
                      ]
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
                                  ref "rhs"
                                }
                              }
                            }
                          ]
                          when {
                            call {
                              arguments [
                                {
                                  ref "lhs"
                                }
                                {
                                  ref "rhs"
                                }
                              ]
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
                  parameters [
                    {
                      name "lhs"
                      type "some T"
                    }
                    {
                      name "rhs"
                      type "some T"
                    }
                  ]
                  result {
                    ref "lhs"
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
                                  ref "lhs"
                                }
                              }
                            }
                          ]
                          when {
                            call {
                              arguments [
                                {
                                  ref "lhs"
                                }
                                {
                                  ref "rhs"
                                }
                              ]
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
                  parameters [
                    {
                      name "lhs"
                      type "some T"
                    }
                    {
                      name "rhs"
                      type "some T"
                    }
                  ]
                  result {
                    ref "rhs"
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
                "std.math.minus"
                "std.math.plus"
                "std.text.characters"
                "std.text.joined"
              ]
              procedures {
                "std.text.contains" {
                  body [
                    {
                      let "held"
                      value {
                        call {
                          arguments [
                            {
                              ref "text"
                            }
                          ]
                          procedure "std.text.characters"
                        }
                      }
                    }
                    {
                      let "wanted"
                      value {
                        call {
                          arguments [
                            {
                              ref "other"
                            }
                          ]
                          procedure "std.text.characters"
                        }
                      }
                    }
                    {
                      let "walk"
                      value {
                        loop {
                          body [
                            {
                              value true
                              var "same"
                            }
                            {
                              let "probe"
                              value {
                                loop {
                                  body [
                                    {
                                      let "at"
                                      value {
                                        call {
                                          arguments [
                                            {
                                              ref "walk.index"
                                            }
                                            {
                                              ref "probe.index"
                                            }
                                          ]
                                          procedure "std.math.plus"
                                        }
                                      }
                                    }
                                    {
                                      value {
                                        conditional {
                                          then [
                                            {
                                              set "same"
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
                                              arguments [
                                                {
                                                  call {
                                                    arguments [
                                                      {
                                                        ref "held[at]"
                                                      }
                                                      {
                                                        ref "wanted[probe.index]"
                                                      }
                                                    ]
                                                    procedure "std.logic.equal"
                                                  }
                                                }
                                              ]
                                              procedure "std.logic.not"
                                            }
                                          }
                                        }
                                      }
                                    }
                                  ]
                                  while {
                                    call {
                                      arguments [
                                        {
                                          ref "probe.index"
                                        }
                                        {
                                          call {
                                            arguments [
                                              {
                                                ref "wanted"
                                              }
                                            ]
                                            procedure "std.collection.count"
                                          }
                                        }
                                      ]
                                      procedure "std.math.lessThan"
                                    }
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
                                    ref "same"
                                  }
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        call {
                                          arguments [
                                            {
                                              call {
                                                arguments [
                                                  {
                                                    ref "held"
                                                  }
                                                ]
                                                procedure "std.collection.count"
                                              }
                                            }
                                            {
                                              call {
                                                arguments [
                                                  {
                                                    ref "wanted"
                                                  }
                                                ]
                                                procedure "std.collection.count"
                                              }
                                            }
                                          ]
                                          procedure "std.math.minus"
                                        }
                                      }
                                      1
                                    ]
                                    procedure "std.math.plus"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Whether a string holds another inside it."
                  parameters [
                    {
                      name "text"
                      type "string"
                    }
                    {
                      name "other"
                      type "string"
                    }
                  ]
                  result false
                  returns "bool"
                }
                "std.text.replacing" {
                  body [
                    {
                      value {
                        conditional {
                          then [
                            {
                              value {
                                call {
                                  arguments [
                                    "replacing asks an empty piece"
                                  ]
                                  procedure "std.control.abort"
                                }
                              }
                            }
                          ]
                          when {
                            call {
                              arguments [
                                {
                                  ref "target"
                                }
                                ""
                              ]
                              procedure "std.logic.equal"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Every occurrence of a piece swapped for another."
                  parameters [
                    {
                      name "text"
                      type "string"
                    }
                    {
                      name "target"
                      type "string"
                    }
                    {
                      name "replacement"
                      type "string"
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          call {
                            arguments [
                              {
                                ref "text"
                              }
                              {
                                ref "target"
                              }
                            ]
                            procedure "std.text.split"
                          }
                        }
                        {
                          ref "replacement"
                        }
                      ]
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
                          arguments [
                            {
                              ref "text"
                            }
                          ]
                          procedure "std.text.characters"
                        }
                      }
                    }
                    {
                      let "heldCount"
                      value {
                        call {
                          arguments [
                            {
                              ref "held"
                            }
                          ]
                          procedure "std.collection.count"
                        }
                      }
                    }
                    {
                      let "wanted"
                      value {
                        call {
                          arguments [
                            {
                              ref "separator"
                            }
                          ]
                          procedure "std.text.characters"
                        }
                      }
                    }
                    {
                      let "wantedCount"
                      value {
                        call {
                          arguments [
                            {
                              ref "wanted"
                            }
                          ]
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
                                  arguments [
                                    "split asks an empty separator"
                                  ]
                                  procedure "std.control.abort"
                                }
                              }
                            }
                          ]
                          when {
                            call {
                              arguments [
                                {
                                  ref "wantedCount"
                                }
                                0
                              ]
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
                                  arguments [
                                    {
                                      call {
                                        arguments [
                                          {
                                            ref "heldCount"
                                          }
                                          {
                                            call {
                                              arguments [
                                                {
                                                  ref "at"
                                                }
                                                {
                                                  ref "wantedCount"
                                                }
                                              ]
                                              procedure "std.math.plus"
                                            }
                                          }
                                        ]
                                        procedure "std.math.lessThan"
                                      }
                                    }
                                  ]
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
                                                  arguments [
                                                    {
                                                      ref "at"
                                                    }
                                                    {
                                                      ref "probe.index"
                                                    }
                                                  ]
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
                                                      arguments [
                                                        {
                                                          call {
                                                            arguments [
                                                              {
                                                                ref "held[offset]"
                                                              }
                                                              {
                                                                ref "wanted[probe.index]"
                                                              }
                                                            ]
                                                            procedure "std.logic.equal"
                                                          }
                                                        }
                                                      ]
                                                      procedure "std.logic.not"
                                                    }
                                                  }
                                                }
                                              }
                                            }
                                          ]
                                          while {
                                            call {
                                              arguments [
                                                {
                                                  ref "probe.index"
                                                }
                                                {
                                                  ref "wantedCount"
                                                }
                                              ]
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
                                          arguments [
                                            {
                                              ref "current"
                                            }
                                            {
                                              ref "held[at]"
                                            }
                                          ]
                                          procedure "std.collection.appending"
                                        }
                                      }
                                    }
                                    {
                                      set "at"
                                      value {
                                        call {
                                          arguments [
                                            {
                                              ref "at"
                                            }
                                            1
                                          ]
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
                                          arguments [
                                            {
                                              ref "pieces"
                                            }
                                            {
                                              call {
                                                arguments [
                                                  {
                                                    ref "current"
                                                  }
                                                  ""
                                                ]
                                                procedure "std.text.joined"
                                              }
                                            }
                                          ]
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
                                          arguments [
                                            {
                                              ref "at"
                                            }
                                            {
                                              ref "wantedCount"
                                            }
                                          ]
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
                              arguments [
                                {
                                  ref "at"
                                }
                                {
                                  ref "heldCount"
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "The text cut on a separator."
                  parameters [
                    {
                      name "text"
                      type "string"
                    }
                    {
                      name "separator"
                      type "string"
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          ref "pieces"
                        }
                        {
                          call {
                            arguments [
                              {
                                ref "current"
                              }
                              ""
                            ]
                            procedure "std.text.joined"
                          }
                        }
                      ]
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
                          arguments [
                            {
                              ref "text"
                            }
                          ]
                          procedure "std.text.characters"
                        }
                      }
                    }
                    {
                      let "wanted"
                      value {
                        call {
                          arguments [
                            {
                              ref "prefix"
                            }
                          ]
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
                              arguments [
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "held"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "wanted"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                              ]
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
                                      arguments [
                                        {
                                          call {
                                            arguments [
                                              {
                                                ref "held[walk.index]"
                                              }
                                              {
                                                ref "wanted[walk.index]"
                                              }
                                            ]
                                            procedure "std.logic.equal"
                                          }
                                        }
                                      ]
                                      procedure "std.logic.not"
                                    }
                                  }
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments [
                                {
                                  ref "walk.index"
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "wanted"
                                      }
                                    ]
                                    procedure "std.collection.count"
                                  }
                                }
                              ]
                              procedure "std.math.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "Whether a string begins with another."
                  parameters [
                    {
                      name "text"
                      type "string"
                    }
                    {
                      name "prefix"
                      type "string"
                    }
                  ]
                  result true
                  returns "bool"
                }
              }
              warp 1
            }
            """,
    ]
}
