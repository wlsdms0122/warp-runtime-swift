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
                "std.collection.appending"
                "std.collection.count"
                "std.collection.gathering"
                "std.collection.keys"
                "std.math.lessThan"
                "std.math.minus"
                "std.math.plus"
              ]
              procedures {
                "std.collection.append" {
                  body [
                    {
                      set "to"
                      value {
                        call {
                          arguments {
                            value {
                              ref "value"
                            }
                          }
                          of {
                            ref "to"
                          }
                          procedure "std.collection.appending"
                        }
                      }
                    }
                  ]
                  description "Writes one element onto the end of the array a variable holds, in place."
                  parameters {
                    to "inout array<some Element>"
                    value "some Element"
                  }
                  receiver "to"
                  result null
                  returns "null"
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
                                  arguments {
                                    value {
                                      call {
                                        arguments {
                                          value 1
                                        }
                                        of {
                                          ref "walk.index"
                                        }
                                        procedure "std.math.plus"
                                      }
                                    }
                                  }
                                  of {
                                    ref "places"
                                  }
                                  procedure "std.collection.appending"
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments {
                                value {
                                  call {
                                    arguments {
                                      value 1
                                    }
                                    of {
                                      call {
                                        of {
                                          ref "of"
                                        }
                                        procedure "std.collection.count"
                                      }
                                    }
                                    procedure "std.math.minus"
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
                  description "The elements after the first."
                  parameters {
                    of "array<some Element>"
                  }
                  receiver "of"
                  result {
                    call {
                      arguments {
                        value {
                          ref "places"
                        }
                      }
                      of {
                        ref "of"
                      }
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
                                  arguments {
                                    value {
                                      ref "walk.index"
                                    }
                                  }
                                  of {
                                    ref "places"
                                  }
                                  procedure "std.collection.appending"
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments {
                                value {
                                  call {
                                    arguments {
                                      value 1
                                    }
                                    of {
                                      call {
                                        of {
                                          ref "of"
                                        }
                                        procedure "std.collection.count"
                                      }
                                    }
                                    procedure "std.math.minus"
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
                  description "The elements before the last."
                  parameters {
                    of "array<some Element>"
                  }
                  receiver "of"
                  result {
                    call {
                      arguments {
                        value {
                          ref "places"
                        }
                      }
                      of {
                        ref "of"
                      }
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
                                apply {
                                  arguments {
                                    item {
                                      ref "of[walk.index]"
                                    }
                                  }
                                  procedure {
                                    ref "value"
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
                                          arguments {
                                            value {
                                              ref "walk.index"
                                            }
                                          }
                                          of {
                                            ref "places"
                                          }
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
                  description "The elements a procedure answers true for."
                  parameters {
                    of "array<some Element>"
                    value {
                      type {
                        "pure procedure" {
                          parameters {
                            item "some Element"
                          }
                          returns "bool"
                        }
                      }
                    }
                  }
                  receiver "of"
                  result {
                    call {
                      arguments {
                        value {
                          ref "places"
                        }
                      }
                      of {
                        ref "of"
                      }
                      procedure "std.collection.gathering"
                    }
                  }
                  returns "array<some Element>"
                }
                "std.collection.first" {
                  description "The first element, or nothing."
                  parameters {
                    of "array<some Element>"
                  }
                  receiver "of"
                  result {
                    ref "of[0]"
                  }
                  returns "some Element"
                }
                "std.collection.last" {
                  body [
                    {
                      let "at"
                      value {
                        call {
                          arguments {
                            value 1
                          }
                          of {
                            call {
                              of {
                                ref "of"
                              }
                              procedure "std.collection.count"
                            }
                          }
                          procedure "std.math.minus"
                        }
                      }
                    }
                  ]
                  description "The last element, or nothing."
                  parameters {
                    of "array<some Element>"
                  }
                  receiver "of"
                  result {
                    ref "of[at]"
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
                                apply {
                                  arguments {
                                    item {
                                      ref "of[walk.index]"
                                    }
                                  }
                                  procedure {
                                    ref "value"
                                  }
                                }
                              }
                            }
                            {
                              set "answers"
                              value {
                                call {
                                  arguments {
                                    value {
                                      ref "answered"
                                    }
                                  }
                                  of {
                                    ref "answers"
                                  }
                                  procedure "std.collection.appending"
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
                  description "Each element answered by a procedure, in order."
                  parameters {
                    of "array<some Element>"
                    value {
                      type {
                        "pure procedure" {
                          parameters {
                            item "some Element"
                          }
                          returns "some Answer"
                        }
                      }
                    }
                  }
                  receiver "of"
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
                          of {
                            ref "of"
                          }
                          procedure "std.collection.reversed"
                        }
                      }
                    }
                    {
                      let "grown"
                      value {
                        call {
                          arguments {
                            value {
                              ref "value"
                            }
                          }
                          of {
                            ref "back"
                          }
                          procedure "std.collection.appending"
                        }
                      }
                    }
                  ]
                  description "The elements with one more at the front."
                  parameters {
                    of "array<some Element>"
                    value "some Element"
                  }
                  receiver "of"
                  result {
                    call {
                      of {
                        ref "grown"
                      }
                      procedure "std.collection.reversed"
                    }
                  }
                  returns "array<some Element>"
                }
                "std.collection.reduce" {
                  body [
                    {
                      value {
                        ref "from"
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
                                apply {
                                  arguments {
                                    carried {
                                      ref "carried"
                                    }
                                    item {
                                      ref "of[walk.index]"
                                    }
                                  }
                                  procedure {
                                    ref "value"
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
                  description "The elements folded into one, starting from a value."
                  parameters {
                    from "some Carried"
                    of "array<some Element>"
                    value {
                      type {
                        "pure procedure" {
                          parameters {
                            carried "some Carried"
                            item "some Element"
                          }
                          returns "some Carried"
                        }
                      }
                    }
                  }
                  receiver "of"
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
                                  arguments {
                                    value {
                                      call {
                                        arguments {
                                          value {
                                            call {
                                              arguments {
                                                value 1
                                              }
                                              of {
                                                ref "walk.index"
                                              }
                                              procedure "std.math.plus"
                                            }
                                          }
                                        }
                                        of {
                                          call {
                                            of {
                                              ref "of"
                                            }
                                            procedure "std.collection.count"
                                          }
                                        }
                                        procedure "std.math.minus"
                                      }
                                    }
                                  }
                                  of {
                                    ref "places"
                                  }
                                  procedure "std.collection.appending"
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
                  description "The elements back to front."
                  parameters {
                    of "array<some Element>"
                  }
                  receiver "of"
                  result {
                    call {
                      arguments {
                        value {
                          ref "places"
                        }
                      }
                      of {
                        ref "of"
                      }
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
                          of {
                            ref "of"
                          }
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
                                        arguments {
                                          value 1
                                        }
                                        of {
                                          ref "rank"
                                        }
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
                                      arguments {
                                        value {
                                          ref "of[outer.index]"
                                        }
                                      }
                                      of {
                                        ref "of[inner.index]"
                                      }
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
                                      arguments {
                                        value {
                                          ref "of[inner.index]"
                                        }
                                      }
                                      of {
                                        ref "of[outer.index]"
                                      }
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
                                            arguments {
                                              value 1
                                            }
                                            of {
                                              ref "rank"
                                            }
                                            procedure "std.math.plus"
                                          }
                                        }
                                      }
                                        ]
                                        when {
                                        call {
                                          arguments {
                                            value {
                                              ref "outer.index"
                                            }
                                          }
                                          of {
                                            ref "inner.index"
                                          }
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
                                      arguments {
                                        value {
                                          ref "total"
                                        }
                                      }
                                      of {
                                        ref "inner.index"
                                      }
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
                                  arguments {
                                    value {
                                      ref "rank"
                                    }
                                  }
                                  of {
                                    ref "ranks"
                                  }
                                  procedure "std.collection.appending"
                                }
                              }
                            }
                          ]
                          while {
                            call {
                              arguments {
                                value {
                                  ref "total"
                                }
                              }
                              of {
                                ref "outer.index"
                              }
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
                                      arguments {
                                        value {
                                          ref "pick.index"
                                        }
                                      }
                                      of {
                                        ref "ranks[scan.index]"
                                      }
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
                                      arguments {
                                        value {
                                          ref "ranks[scan.index]"
                                        }
                                      }
                                      of {
                                        ref "pick.index"
                                      }
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
                                        arguments {
                                          value {
                                            ref "scan.index"
                                          }
                                        }
                                        of {
                                          ref "places"
                                        }
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
                                      arguments {
                                        value {
                                          ref "total"
                                        }
                                      }
                                      of {
                                        ref "scan.index"
                                      }
                                      procedure "std.math.lessThan"
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
                                  ref "total"
                                }
                              }
                              of {
                                ref "pick.index"
                              }
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
                  parameters {
                    of "array<some Element>"
                  }
                  receiver "of"
                  result {
                    call {
                      arguments {
                        value {
                          ref "places"
                        }
                      }
                      of {
                        ref "of"
                      }
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
                          of {
                            ref "of"
                          }
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
                                  arguments {
                                    value {
                                      ref "of[name]"
                                    }
                                  }
                                  of {
                                    ref "held"
                                  }
                                  procedure "std.collection.appending"
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
                                      ref "names"
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
                  description "What a record holds, by its names in order."
                  parameters {
                    of "dictionary<some Entry>"
                  }
                  receiver "of"
                  result {
                    ref "held"
                  }
                  returns "array<some Entry>"
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
                "std.logic.select" {
                  body [
                    {
                      value {
                        conditional {
                          then [
                            {
                              let "taken"
                              value {
                                apply {
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
                            ref "of"
                          }
                        }
                      }
                    }
                    {
                      let "left"
                      value {
                        apply {
                          procedure {
                            ref "else"
                          }
                        }
                      }
                    }
                  ]
                  description "The value one of two sides answers, chosen by a truth."
                  parameters {
                    else {
                      type {
                        "pure procedure" {
                          returns "some Answer"
                        }
                      }
                    }
                    of "bool"
                    then {
                      type {
                        "pure procedure" {
                          returns "some Answer"
                        }
                      }
                    }
                  }
                  receiver "of"
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
