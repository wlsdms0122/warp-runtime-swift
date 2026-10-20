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
            (warp 1)
            (description "Reading a collection by walking it, written from its count and its index.")
            (import Standard.Collection.appending)
            (import Standard.Collection.count)
            (import Standard.Collection.gathering)
            (import Standard.Collection.keys)
            (import Standard.Comparable)
            (import Standard.Comparable.lessThan)
            (import Standard.Logic.equal)
            (import Standard.Numeric.minus)
            (import Standard.Numeric.plus)
            
            (procedure Standard.Collection.append
              (description "Writes one element onto the end of the array a variable holds, in place.")
              (isolated)
              (parameter array (type (inout (array (some Element)))))
              (parameter element (type (some Element)))
              (body
                (set array (call Standard.Collection.appending array element))))
            
            (procedure Standard.Collection.contains
              (description "Whether an array holds a value.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter element (type (some Element)))
              (returns Bool)
              (body
                (var found false)
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count array)))
                    (body
                      (conditional
                        (when (call Standard.Logic.equal (path array (index (path walk (field index)))) element))
                        (then
                          (set found true)
                          (break)))))))
              (result found))
            
            (procedure Standard.Collection.dropFirst
              (description "The elements after the first.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (returns (array (some Element)))
              (body
                (var places (array))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Numeric.minus (call Standard.Collection.count array) 1)))
                    (body
                      (set places (call Standard.Collection.appending places (call Standard.Numeric.plus (path walk (field index)) 1)))))))
              (result (call Standard.Collection.gathering array places)))
            
            (procedure Standard.Collection.dropLast
              (description "The elements before the last.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (returns (array (some Element)))
              (body
                (var places (array))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Numeric.minus (call Standard.Collection.count array) 1)))
                    (body
                      (set places (call Standard.Collection.appending places (path walk (field index))))))))
              (result (call Standard.Collection.gathering array places)))
            
            (procedure Standard.Collection.filter
              (description "The elements a procedure answers true for.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter isIncluded (type (procedure (const) (isolated) (parameters (some Element)) (returns Bool))))
              (returns (array (some Element)))
              (body
                (var places (array))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count array)))
                    (body
                      (let kept (apply isIncluded (path array (index (path walk (field index))))))
                      (conditional
                        (when kept)
                        (then
                          (set places (call Standard.Collection.appending places (path walk (field index))))))))))
              (result (call Standard.Collection.gathering array places)))
            
            (procedure Standard.Collection.first
              (description "The first element.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (returns (some Element))
              (result (path array (index 0))))
            
            (procedure Standard.Collection.last
              (description "The last element.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (returns (some Element))
              (body
                (let at (call Standard.Numeric.minus (call Standard.Collection.count array) 1)))
              (result (path array (index at))))
            
            (procedure Standard.Collection.map
              (description "Each element answered by a procedure, in order.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter transform (type (procedure (const) (isolated) (parameters (some Element)) (returns (some Answer)))))
              (returns (array (some Answer)))
              (body
                (var answers (array))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count array)))
                    (body
                      (let answered (apply transform (path array (index (path walk (field index))))))
                      (set answers (call Standard.Collection.appending answers answered))))))
              (result answers))
            
            (procedure Standard.Collection.prepending
              (description "The elements with one more at the front.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter element (type (some Element)))
              (returns (array (some Element)))
              (body
                (let back (call Standard.Collection.reversed array))
                (let grown (call Standard.Collection.appending back element)))
              (result (call Standard.Collection.reversed grown)))
            
            (procedure Standard.Collection.reduce
              (description "The elements folded into one, starting from a value.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter initialResult (type (some Carried)))
              (parameter nextPartialResult (type (procedure (const) (isolated) (parameters (some Carried) (some Element)) (returns (some Carried)))))
              (returns (some Carried))
              (body
                (var carried initialResult)
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count array)))
                    (body
                      (let answered (apply nextPartialResult carried (path array (index (path walk (field index))))))
                      (set carried answered)))))
              (result carried))
            
            (procedure Standard.Collection.reversed
              (description "The elements back to front.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (returns (array (some Element)))
              (body
                (var places (array))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count array)))
                    (body
                      (set places (call Standard.Collection.appending places (call Standard.Numeric.minus (call Standard.Collection.count array) (call Standard.Numeric.plus (path walk (field index)) 1))))))))
              (result (call Standard.Collection.gathering array places)))
            
            (procedure Standard.Collection.sorted
              (description "The elements in the order lessThan puts them in, for any type that orders.")
              (const)
              (isolated)
              (parameter array (type (array (some Element Standard.Comparable))))
              (returns (array (some Element)))
              (body
                (let total (call Standard.Collection.count array))
                (var ranks (array))
                (let outer
                  (loop
                    (while (call Standard.Comparable.lessThan (path outer (field index)) total))
                    (body
                      (var rank 0)
                      (let inner
                        (loop
                          (while (call Standard.Comparable.lessThan (path inner (field index)) total))
                          (body
                            (var tie true)
                            (conditional
                              (when (call Standard.Comparable.lessThan (path array (index (path inner (field index)))) (path array (index (path outer (field index))))))
                              (then
                                (set rank (call Standard.Numeric.plus rank 1))
                                (set tie false)))
                            (conditional
                              (when (call Standard.Comparable.lessThan (path array (index (path outer (field index)))) (path array (index (path inner (field index))))))
                              (then
                                (set tie false)))
                            (conditional
                              (when tie)
                              (then
                                (conditional
                                  (when (call Standard.Comparable.lessThan (path inner (field index)) (path outer (field index))))
                                  (then
                                    (set rank (call Standard.Numeric.plus rank 1)))))))))
                      (set ranks (call Standard.Collection.appending ranks rank)))))
                (var places (array))
                (let pick
                  (loop
                    (while (call Standard.Comparable.lessThan (path pick (field index)) (call Standard.Numeric.plus total 1)))
                    (body
                      (let scan
                        (loop
                          (while (call Standard.Comparable.lessThan (path scan (field index)) total))
                          (body
                            (var same true)
                            (conditional
                              (when (call Standard.Comparable.lessThan (path ranks (index (path scan (field index)))) (path pick (field index))))
                              (then
                                (set same false)))
                            (conditional
                              (when (call Standard.Comparable.lessThan (path pick (field index)) (path ranks (index (path scan (field index))))))
                              (then
                                (set same false)))
                            (conditional
                              (when same)
                              (then
                                (set places (call Standard.Collection.appending places (path scan (field index)))))))))))))
              (result (call Standard.Collection.gathering array places)))
            
            (procedure Standard.Collection.tryFilter
              (description "The elements a procedure that may fail answers true for.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter isIncluded (type (procedure (const) (isolated) (parameters (some Element)) (failing (anything)) (returns Bool))))
              (returns (array (some Element)))
              (failing (anything))
              (body
                (var places (array))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count array)))
                    (body
                      (let kept (apply isIncluded (path array (index (path walk (field index))))))
                      (conditional
                        (when kept)
                        (then
                          (set places (call Standard.Collection.appending places (path walk (field index))))))))))
              (result (call Standard.Collection.gathering array places)))
            
            (procedure Standard.Collection.tryMap
              (description "Each element answered by a procedure that may fail, in order.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter transform (type (procedure (const) (isolated) (parameters (some Element)) (failing (anything)) (returns (some Answer)))))
              (returns (array (some Answer)))
              (failing (anything))
              (body
                (var answers (array))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count array)))
                    (body
                      (let answered (apply transform (path array (index (path walk (field index))))))
                      (set answers (call Standard.Collection.appending answers answered))))))
              (result answers))
            
            (procedure Standard.Collection.tryReduce
              (description "The elements folded into one by a procedure that may fail, starting from a value.")
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter initialResult (type (some Carried)))
              (parameter nextPartialResult (type (procedure (const) (isolated) (parameters (some Carried) (some Element)) (failing (anything)) (returns (some Carried)))))
              (returns (some Carried))
              (failing (anything))
              (body
                (var carried initialResult)
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count array)))
                    (body
                      (let answered (apply nextPartialResult carried (path array (index (path walk (field index))))))
                      (set carried answered)))))
              (result carried))
            
            (procedure Standard.Collection.values
              (description "What a map holds, by its keys in the key order.")
              (const)
              (isolated)
              (parameter dictionary (type (dictionary (some Key Hashable) (some Entry))))
              (returns (array (some Entry)))
              (body
                (let keys (call Standard.Collection.keys dictionary))
                (var held (array))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count keys)))
                    (body
                      (let key (path keys (index (path walk (field index)))))
                      (set held (call Standard.Collection.appending held (path dictionary (index key))))))))
              (result held))
            """,
        "concurrent": """
            (warp 1)
            (description "Running one closure once per element, written from the fan-out that runs a list of them.")
            (import Standard.Collection.appending)
            (import Standard.Collection.count)
            (import Standard.Comparable.lessThan)
            (import Standard.Concurrent.all)
            
            (procedure Standard.Concurrent.map
              (description "Each element answered by a procedure, run at once, in the collection's order.")
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter transform (type (procedure (isolated) (parameters (some Element) Int) (failing (anything)) (returns (some Answer)))))
              (returns (array (some Answer)))
              (failing concurrent_failed)
              (body
                (var pieces (array))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count array)))
                    (body
                      (let item (path array (index (path walk (field index)))))
                      (let index (path walk (field index)))
                      (let piece
                        (closure
                          (isolated)
                          (returns (some Answer))
                          (failing (anything))
                          (body
                            (let answered (apply transform item index)))
                          (result answered)))
                      (set pieces (call Standard.Collection.appending pieces piece))))))
              (result (call Standard.Concurrent.all pieces)))
            """,
        "logic": """
            (warp 1)
            (description "Negation, difference, choosing and the connectives, written from equality.")
            (import Standard.Collection.count)
            (import Standard.Comparable.lessThan)
            (import Standard.Logic.equal)
            
            (procedure Standard.Logic.and
              (description "Whether every one answers true, asked until one does not.")
              (const)
              (isolated)
              (parameter conditions (type (array (procedure (const) (isolated) (parameters) (returns Bool)))))
              (returns Bool)
              (body
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count conditions)))
                    (body
                      (let side (path conditions (index (path walk (field index)))))
                      (let answered (apply side))
                      (conditional
                        (when (call Standard.Logic.not answered))
                        (then
                          (return false)))))))
              (result true))
            
            (procedure Standard.Logic.not
              (description "The opposite of a truth.")
              (const)
              (isolated)
              (parameter value (type Bool))
              (returns Bool)
              (result (call Standard.Logic.equal value false)))
            
            (procedure Standard.Logic.notEqual
              (description "Whether two values differ.")
              (const)
              (isolated)
              (parameter lhs)
              (parameter rhs)
              (returns Bool)
              (result (call Standard.Logic.equal (call Standard.Logic.equal lhs rhs) false)))
            
            (procedure Standard.Logic.or
              (description "Whether one answers true, asked until one does.")
              (const)
              (isolated)
              (parameter conditions (type (array (procedure (const) (isolated) (parameters) (returns Bool)))))
              (returns Bool)
              (body
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count conditions)))
                    (body
                      (let side (path conditions (index (path walk (field index)))))
                      (let answered (apply side))
                      (conditional
                        (when answered)
                        (then
                          (return true)))))))
              (result false))
            
            (procedure Standard.Logic.select
              (description "The value one of two sides answers, chosen by a truth.")
              (const)
              (isolated)
              (parameter condition (type Bool))
              (parameter then (type (procedure (const) (isolated) (parameters) (returns (some Answer)))))
              (parameter else (type (procedure (const) (isolated) (parameters) (returns (some Answer)))))
              (returns (some Answer))
              (body
                (conditional
                  (when condition)
                  (then
                    (let taken (apply then))
                    (return taken)))
                (let left (apply else)))
              (result left))
            
            (procedure Standard.Logic.tryAnd
              (description "Whether every side, each of which may fail, answers true, asked until one does not.")
              (const)
              (isolated)
              (parameter conditions (type (array (procedure (const) (isolated) (parameters) (failing (anything)) (returns Bool)))))
              (returns Bool)
              (failing (anything))
              (body
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count conditions)))
                    (body
                      (let side (path conditions (index (path walk (field index)))))
                      (let answered (apply side))
                      (conditional
                        (when (call Standard.Logic.not answered))
                        (then
                          (return false)))))))
              (result true))
            
            (procedure Standard.Logic.tryOr
              (description "Whether one side, each of which may fail, answers true, asked until one does.")
              (const)
              (isolated)
              (parameter conditions (type (array (procedure (const) (isolated) (parameters) (failing (anything)) (returns Bool)))))
              (returns Bool)
              (failing (anything))
              (body
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count conditions)))
                    (body
                      (let side (path conditions (index (path walk (field index)))))
                      (let answered (apply side))
                      (conditional
                        (when answered)
                        (then
                          (return true)))))))
              (result false))
            
            (procedure Standard.Logic.trySelect
              (description "The value one of two sides, each of which may fail, answers, chosen by a truth.")
              (const)
              (isolated)
              (parameter condition (type Bool))
              (parameter then (type (procedure (const) (isolated) (parameters) (failing (anything)) (returns (some Answer)))))
              (parameter else (type (procedure (const) (isolated) (parameters) (failing (anything)) (returns (some Answer)))))
              (returns (some Answer))
              (failing (anything))
              (body
                (conditional
                  (when condition)
                  (then
                    (let taken (apply then))
                    (return taken)))
                (let left (apply else)))
              (result left))
            """,
        "math": """
            (warp 1)
            (description "Ordering the other way round, choosing between two and dropping a sign, written from lessThan and minus.")
            (import Standard.Comparable)
            (import Standard.Comparable.lessThan)
            (import Standard.Numeric)
            (import Standard.Numeric.minus)
            
            (procedure Standard.Math.absolute
              (description "The number without its sign.")
              (const)
              (isolated)
              (parameter number (type (some N Standard.Comparable Standard.Numeric)))
              (returns (some N))
              (body
                (let zero (call Standard.Numeric.minus number number))
                (conditional
                  (when (call Standard.Comparable.lessThan zero number))
                  (then
                    (return number))))
              (result (call Standard.Numeric.minus zero number)))
            
            (procedure Standard.Math.greaterThan
              (description "Whether the first is larger, by the one order.")
              (const)
              (isolated)
              (parameter lhs (type (some T Standard.Comparable)))
              (parameter rhs (type (some T)))
              (returns Bool)
              (result (call Standard.Comparable.lessThan rhs lhs)))
            
            (procedure Standard.Math.max
              (description "The larger of two of one type, by the one order.")
              (const)
              (isolated)
              (parameter lhs (type (some T Standard.Comparable)))
              (parameter rhs (type (some T)))
              (returns (some T))
              (body
                (conditional
                  (when (call Standard.Comparable.lessThan rhs lhs))
                  (then
                    (return lhs))))
              (result rhs))
            
            (procedure Standard.Math.min
              (description "The smaller of two of one type, by the one order.")
              (const)
              (isolated)
              (parameter lhs (type (some T Standard.Comparable)))
              (parameter rhs (type (some T)))
              (returns (some T))
              (body
                (conditional
                  (when (call Standard.Comparable.lessThan rhs lhs))
                  (then
                    (return rhs))))
              (result lhs))
            """,
        "text": """
            (warp 1)
            (description "Scanning text, written from its characters.")
            (import Standard.Collection.appending)
            (import Standard.Collection.count)
            (import Standard.Comparable.lessThan)
            (import Standard.Control.abort)
            (import Standard.Logic.equal)
            (import Standard.Logic.not)
            (import Standard.Numeric.minus)
            (import Standard.Numeric.plus)
            (import Standard.Text.characters)
            (import Standard.Text.joined)
            
            (procedure Standard.Text.contains
              (description "Whether a string holds another inside it.")
              (const)
              (isolated)
              (parameter text (type String))
              (parameter other (type String))
              (returns Bool)
              (body
                (let held (call Standard.Text.characters text))
                (let wanted (call Standard.Text.characters other))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Numeric.plus (call Standard.Numeric.minus (call Standard.Collection.count held) (call Standard.Collection.count wanted)) 1)))
                    (body
                      (var same true)
                      (let probe
                        (loop
                          (while (call Standard.Comparable.lessThan (path probe (field index)) (call Standard.Collection.count wanted)))
                          (body
                            (let at (call Standard.Numeric.plus (path walk (field index)) (path probe (field index))))
                            (conditional
                              (when (call Standard.Logic.not (call Standard.Logic.equal (path held (index at)) (path wanted (index (path probe (field index)))))))
                              (then
                                (set same false)
                                (break))))))
                      (conditional
                        (when same)
                        (then
                          (return true)))))))
              (result false))
            
            (procedure Standard.Text.replacing
              (description "Every occurrence of a piece swapped for another.")
              (const)
              (isolated)
              (parameter text (type String))
              (parameter target (type String))
              (parameter replacement (type String))
              (returns String)
              (failing aborted)
              (body
                (conditional
                  (when (call Standard.Logic.equal target ""))
                  (then
                    (call Standard.Control.abort "replacing asks an empty piece"))))
              (result (call Standard.Text.joined (call Standard.Text.split text target) replacement)))
            
            (procedure Standard.Text.split
              (description "The text cut on a separator.")
              (const)
              (isolated)
              (parameter text (type String))
              (parameter separator (type String))
              (returns (array String))
              (failing aborted)
              (body
                (let held (call Standard.Text.characters text))
                (let heldCount (call Standard.Collection.count held))
                (let wanted (call Standard.Text.characters separator))
                (let wantedCount (call Standard.Collection.count wanted))
                (conditional
                  (when (call Standard.Logic.equal wantedCount 0))
                  (then
                    (call Standard.Control.abort "split asks an empty separator")))
                (var pieces (array))
                (var current (array))
                (var at 0)
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan at heldCount))
                    (body
                      (var matched (call Standard.Logic.not (call Standard.Comparable.lessThan heldCount (call Standard.Numeric.plus at wantedCount))))
                      (conditional
                        (when matched)
                        (then
                          (let probe
                            (loop
                              (while (call Standard.Comparable.lessThan (path probe (field index)) wantedCount))
                              (body
                                (let offset (call Standard.Numeric.plus at (path probe (field index))))
                                (conditional
                                  (when (call Standard.Logic.not (call Standard.Logic.equal (path held (index offset)) (path wanted (index (path probe (field index)))))))
                                  (then
                                    (set matched false)
                                    (break))))))))
                      (conditional
                        (when matched)
                        (then
                          (set pieces (call Standard.Collection.appending pieces (call Standard.Text.joined current "")))
                          (set current (array))
                          (set at (call Standard.Numeric.plus at wantedCount)))
                        (else
                          (set current (call Standard.Collection.appending current (path held (index at))))
                          (set at (call Standard.Numeric.plus at 1))))))))
              (result (call Standard.Collection.appending pieces (call Standard.Text.joined current ""))))
            
            (procedure Standard.Text.startsWith
              (description "Whether a string begins with another.")
              (const)
              (isolated)
              (parameter text (type String))
              (parameter prefix (type String))
              (returns Bool)
              (body
                (let held (call Standard.Text.characters text))
                (let wanted (call Standard.Text.characters prefix))
                (conditional
                  (when (call Standard.Comparable.lessThan (call Standard.Collection.count held) (call Standard.Collection.count wanted)))
                  (then
                    (return false)))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count wanted)))
                    (body
                      (conditional
                        (when (call Standard.Logic.not (call Standard.Logic.equal (path held (index (path walk (field index)))) (path wanted (index (path walk (field index)))))))
                        (then
                          (return false)))))))
              (result true))
            """
    ]
}
