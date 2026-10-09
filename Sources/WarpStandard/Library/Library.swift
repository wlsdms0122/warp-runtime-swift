//
//  Library.swift
//  WarpStandard
//
//  Written by script/embed-library.sh. Edit lib/standard and run it again.
//

import Foundation

// The documents of `lib/standard`, as they stand in the repository.
enum Library {
    static let documents: [String: String] = [
        "collection": """
            warpt 1
            {
              description "Reading a collection by walking it, written from its count and its index."
              imports [
                "Standard.Collection.appending"
                "Standard.Collection.count"
                "Standard.Collection.gathering"
                "Standard.Collection.keys"
                "Standard.Comparable"
                "Standard.Comparable.lessThan"
                "Standard.Logic.equal"
                "Standard.Numeric.minus"
                "Standard.Numeric.plus"
              ]
              procedures {
                "Standard.Collection.append" {
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
                          procedure "Standard.Collection.appending"
                        }
                      }
                    }
                  ]
                  description "Writes one element onto the end of the array a variable holds, in place."
                  parameters [
                    {
                      name "array"
                      type "inout Array<some Element>"
                    }
                    {
                      name "element"
                      type "some Element"
                    }
                  ]
                  returns "Null"
                }
                "Standard.Collection.contains" {
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
                                      procedure "Standard.Logic.equal"
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
                                    procedure "Standard.Collection.count"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                      type "Array<some Element>"
                    }
                    {
                      name "element"
                      type "some Element"
                    }
                  ]
                  result {
                    ref "found"
                  }
                  returns "Bool"
                }
                "Standard.Collection.dropFirst" {
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
                                        procedure "Standard.Numeric.plus"
                                      }
                                    }
                                  ]
                                  procedure "Standard.Collection.appending"
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
                                          procedure "Standard.Collection.count"
                                        }
                                      }
                                      1
                                    ]
                                    procedure "Standard.Numeric.minus"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                      type "Array<some Element>"
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
                      procedure "Standard.Collection.gathering"
                    }
                  }
                  returns "Array<some Element>"
                }
                "Standard.Collection.dropLast" {
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
                                  procedure "Standard.Collection.appending"
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
                                          procedure "Standard.Collection.count"
                                        }
                                      }
                                      1
                                    ]
                                    procedure "Standard.Numeric.minus"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                      type "Array<some Element>"
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
                      procedure "Standard.Collection.gathering"
                    }
                  }
                  returns "Array<some Element>"
                }
                "Standard.Collection.filter" {
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
                                          procedure "Standard.Collection.appending"
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
                                    procedure "Standard.Collection.count"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                      type "Array<some Element>"
                    }
                    {
                      name "isIncluded"
                      type {
                        "const procedure" {
                          parameters [
                            "some Element"
                          ]
                          returns "Bool"
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
                      procedure "Standard.Collection.gathering"
                    }
                  }
                  returns "Array<some Element>"
                }
                "Standard.Collection.first" {
                  description "The first element."
                  parameters [
                    {
                      name "array"
                      type "Array<some Element>"
                    }
                  ]
                  result {
                    ref "array[0]"
                  }
                  returns "some Element"
                }
                "Standard.Collection.last" {
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
                                procedure "Standard.Collection.count"
                              }
                            }
                            1
                          ]
                          procedure "Standard.Numeric.minus"
                        }
                      }
                    }
                  ]
                  description "The last element."
                  parameters [
                    {
                      name "array"
                      type "Array<some Element>"
                    }
                  ]
                  result {
                    ref "array[at]"
                  }
                  returns "some Element"
                }
                "Standard.Collection.map" {
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
                                  procedure "Standard.Collection.appending"
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
                                    procedure "Standard.Collection.count"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                      type "Array<some Element>"
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
                  returns "Array<some Answer>"
                }
                "Standard.Collection.prepending" {
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
                          procedure "Standard.Collection.reversed"
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
                          procedure "Standard.Collection.appending"
                        }
                      }
                    }
                  ]
                  description "The elements with one more at the front."
                  parameters [
                    {
                      name "array"
                      type "Array<some Element>"
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
                      procedure "Standard.Collection.reversed"
                    }
                  }
                  returns "Array<some Element>"
                }
                "Standard.Collection.reduce" {
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
                                    procedure "Standard.Collection.count"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                      type "Array<some Element>"
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
                "Standard.Collection.reversed" {
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
                                              procedure "Standard.Collection.count"
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
                                              procedure "Standard.Numeric.plus"
                                            }
                                          }
                                        ]
                                        procedure "Standard.Numeric.minus"
                                      }
                                    }
                                  ]
                                  procedure "Standard.Collection.appending"
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
                                    procedure "Standard.Collection.count"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                      type "Array<some Element>"
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
                      procedure "Standard.Collection.gathering"
                    }
                  }
                  returns "Array<some Element>"
                }
                "Standard.Collection.sorted" {
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
                          procedure "Standard.Collection.count"
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
                                                  procedure "Standard.Numeric.plus"
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
                                              procedure "Standard.Comparable.lessThan"
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
                                              procedure "Standard.Comparable.lessThan"
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
                                                          procedure "Standard.Numeric.plus"
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
                                                      procedure "Standard.Comparable.lessThan"
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
                                      procedure "Standard.Comparable.lessThan"
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
                                  procedure "Standard.Collection.appending"
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
                              procedure "Standard.Comparable.lessThan"
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
                                              procedure "Standard.Comparable.lessThan"
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
                                              procedure "Standard.Comparable.lessThan"
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
                                                  procedure "Standard.Collection.appending"
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
                                      procedure "Standard.Comparable.lessThan"
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
                                  call {
                                    arguments [
                                      {
                                        ref "total"
                                      }
                                      1
                                    ]
                                    procedure "Standard.Numeric.plus"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  bounds {
                    Element "Standard.Comparable"
                  }
                  description "The elements in the order lessThan puts them in, for any type that orders."
                  parameters [
                    {
                      name "array"
                      type "Array<some Element>"
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
                      procedure "Standard.Collection.gathering"
                    }
                  }
                  returns "Array<some Element>"
                }
                "Standard.Collection.values" {
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
                          procedure "Standard.Collection.keys"
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
                                  procedure "Standard.Collection.appending"
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
                                    procedure "Standard.Collection.count"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  description "What a map holds, by its names in order."
                  parameters [
                    {
                      name "dictionary"
                      type "Dictionary<some Entry>"
                    }
                  ]
                  result {
                    ref "held"
                  }
                  returns "Array<some Entry>"
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
                "Standard.Collection.appending"
                "Standard.Collection.count"
                "Standard.Comparable.lessThan"
                "Standard.Concurrent.all"
              ]
              procedures {
                "Standard.Concurrent.map" {
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
                                  procedure "Standard.Collection.appending"
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
                                    procedure "Standard.Collection.count"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                      type "Array<some Element>"
                    }
                    {
                      name "transform"
                      type {
                        "isolated procedure" {
                          parameters [
                            "some Element"
                            "Int"
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
                      procedure "Standard.Concurrent.all"
                    }
                  }
                  returns "Array<some Answer>"
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
                "Standard.Collection.count"
                "Standard.Comparable.lessThan"
                "Standard.Logic.equal"
              ]
              procedures {
                "Standard.Logic.and" {
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
                                      ]
                                      procedure "Standard.Logic.not"
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
                                    procedure "Standard.Collection.count"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                            returns "Bool"
                          }
                        }
                      }
                    }
                  ]
                  result true
                  returns "Bool"
                }
                "Standard.Logic.not" {
                  description "The opposite of a truth."
                  parameters [
                    {
                      name "value"
                      type "Bool"
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
                      procedure "Standard.Logic.equal"
                    }
                  }
                  returns "Bool"
                }
                "Standard.Logic.notEqual" {
                  description "Whether two values differ."
                  parameters [
                    {
                      name "lhs"
                    }
                    {
                      name "rhs"
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
                            procedure "Standard.Logic.equal"
                          }
                        }
                        false
                      ]
                      procedure "Standard.Logic.equal"
                    }
                  }
                  returns "Bool"
                }
                "Standard.Logic.or" {
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
                                    procedure "Standard.Collection.count"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                            returns "Bool"
                          }
                        }
                      }
                    }
                  ]
                  result false
                  returns "Bool"
                }
                "Standard.Logic.select" {
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
                      type "Bool"
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
              description "Ordering the other way round, choosing between two and dropping a sign, written from lessThan and minus."
              imports [
                "Standard.Comparable"
                "Standard.Comparable.lessThan"
                "Standard.Numeric"
                "Standard.Numeric.minus"
              ]
              procedures {
                "Standard.Math.absolute" {
                  body [
                    {
                      let "zero"
                      value {
                        call {
                          arguments [
                            {
                              ref "number"
                            }
                            {
                              ref "number"
                            }
                          ]
                          procedure "Standard.Numeric.minus"
                        }
                      }
                    }
                    {
                      value {
                        conditional {
                          then [
                            {
                              value {
                                return {
                                  ref "number"
                                }
                              }
                            }
                          ]
                          when {
                            call {
                              arguments [
                                {
                                  ref "zero"
                                }
                                {
                                  ref "number"
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  bounds {
                    N "Standard.Comparable & Standard.Numeric"
                  }
                  description "The number without its sign."
                  parameters [
                    {
                      name "number"
                      type "some N"
                    }
                  ]
                  result {
                    call {
                      arguments [
                        {
                          ref "zero"
                        }
                        {
                          ref "number"
                        }
                      ]
                      procedure "Standard.Numeric.minus"
                    }
                  }
                  returns "some N"
                }
                "Standard.Math.greaterThan" {
                  bounds {
                    T "Standard.Comparable"
                  }
                  description "Whether the first is larger, by the one order."
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
                      procedure "Standard.Comparable.lessThan"
                    }
                  }
                  returns "Bool"
                }
                "Standard.Math.max" {
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
                                  ref "rhs"
                                }
                                {
                                  ref "lhs"
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  bounds {
                    T "Standard.Comparable"
                  }
                  description "The larger of two of one type, by the one order."
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
                "Standard.Math.min" {
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
                                  ref "rhs"
                                }
                                {
                                  ref "lhs"
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
                            }
                          }
                        }
                      }
                    }
                  ]
                  bounds {
                    T "Standard.Comparable"
                  }
                  description "The smaller of two of one type, by the one order."
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
              }
              warp 1
            }
            """,
        "text": """
            warpt 1
            {
              description "Scanning text, written from its characters."
              imports [
                "Standard.Collection.appending"
                "Standard.Collection.count"
                "Standard.Comparable.lessThan"
                "Standard.Control.abort"
                "Standard.Logic.equal"
                "Standard.Logic.not"
                "Standard.Numeric.minus"
                "Standard.Numeric.plus"
                "Standard.Text.characters"
                "Standard.Text.joined"
              ]
              procedures {
                "Standard.Text.contains" {
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
                          procedure "Standard.Text.characters"
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
                          procedure "Standard.Text.characters"
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
                                          procedure "Standard.Numeric.plus"
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
                                                    procedure "Standard.Logic.equal"
                                                  }
                                                }
                                              ]
                                              procedure "Standard.Logic.not"
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
                                            procedure "Standard.Collection.count"
                                          }
                                        }
                                      ]
                                      procedure "Standard.Comparable.lessThan"
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
                                                procedure "Standard.Collection.count"
                                              }
                                            }
                                            {
                                              call {
                                                arguments [
                                                  {
                                                    ref "wanted"
                                                  }
                                                ]
                                                procedure "Standard.Collection.count"
                                              }
                                            }
                                          ]
                                          procedure "Standard.Numeric.minus"
                                        }
                                      }
                                      1
                                    ]
                                    procedure "Standard.Numeric.plus"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                      type "String"
                    }
                    {
                      name "other"
                      type "String"
                    }
                  ]
                  result false
                  returns "Bool"
                }
                "Standard.Text.replacing" {
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
                                  procedure "Standard.Control.abort"
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
                              procedure "Standard.Logic.equal"
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
                      type "String"
                    }
                    {
                      name "target"
                      type "String"
                    }
                    {
                      name "replacement"
                      type "String"
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
                            procedure "Standard.Text.split"
                          }
                        }
                        {
                          ref "replacement"
                        }
                      ]
                      procedure "Standard.Text.joined"
                    }
                  }
                  returns "String"
                }
                "Standard.Text.split" {
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
                          procedure "Standard.Text.characters"
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
                          procedure "Standard.Collection.count"
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
                          procedure "Standard.Text.characters"
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
                          procedure "Standard.Collection.count"
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
                                  procedure "Standard.Control.abort"
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
                              procedure "Standard.Logic.equal"
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
                                              procedure "Standard.Numeric.plus"
                                            }
                                          }
                                        ]
                                        procedure "Standard.Comparable.lessThan"
                                      }
                                    }
                                  ]
                                  procedure "Standard.Logic.not"
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
                                                  procedure "Standard.Numeric.plus"
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
                                                            procedure "Standard.Logic.equal"
                                                          }
                                                        }
                                                      ]
                                                      procedure "Standard.Logic.not"
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
                                              procedure "Standard.Comparable.lessThan"
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
                                          procedure "Standard.Collection.appending"
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
                                          procedure "Standard.Numeric.plus"
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
                                                procedure "Standard.Text.joined"
                                              }
                                            }
                                          ]
                                          procedure "Standard.Collection.appending"
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
                                          procedure "Standard.Numeric.plus"
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
                              procedure "Standard.Comparable.lessThan"
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
                      type "String"
                    }
                    {
                      name "separator"
                      type "String"
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
                            procedure "Standard.Text.joined"
                          }
                        }
                      ]
                      procedure "Standard.Collection.appending"
                    }
                  }
                  returns "Array<String>"
                }
                "Standard.Text.startsWith" {
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
                          procedure "Standard.Text.characters"
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
                          procedure "Standard.Text.characters"
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
                                    procedure "Standard.Collection.count"
                                  }
                                }
                                {
                                  call {
                                    arguments [
                                      {
                                        ref "wanted"
                                      }
                                    ]
                                    procedure "Standard.Collection.count"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                                            procedure "Standard.Logic.equal"
                                          }
                                        }
                                      ]
                                      procedure "Standard.Logic.not"
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
                                    procedure "Standard.Collection.count"
                                  }
                                }
                              ]
                              procedure "Standard.Comparable.lessThan"
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
                      type "String"
                    }
                    {
                      name "prefix"
                      type "String"
                    }
                  ]
                  result true
                  returns "Bool"
                }
              }
              warp 1
            }
            """
    ]
}
