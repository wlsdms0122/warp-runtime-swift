//
//  Library.swift
//  WarpStandard
//
//  Written by tool/embed-library.sh. Edit warp/lib/standard and run it again.
//

import Foundation

// The documents of `lib/standard`, as they stand in the `warp` submodule.
enum Library {
    static let documents: [String: String] = [
        "collection": """
            (warp 1)
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
              (isolated)
              (parameter array (type (inout (array (some Element)))))
              (parameter element (type (some Element)))
              (body
                (set array (call Standard.Collection.appending array element))))
            
            (procedure Standard.Collection.contains
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
                          (break))))))
                (return found)))
            
            (procedure Standard.Collection.dropFirst
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
                      (set places (call Standard.Collection.appending places (call Standard.Numeric.plus (path walk (field index)) 1))))))
                (return (call Standard.Collection.gathering array places))))
            
            (procedure Standard.Collection.dropLast
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
                      (set places (call Standard.Collection.appending places (path walk (field index)))))))
                (return (call Standard.Collection.gathering array places))))
            
            (procedure Standard.Collection.filter
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
                          (set places (call Standard.Collection.appending places (path walk (field index)))))))))
                (return (call Standard.Collection.gathering array places))))
            
            (procedure Standard.Collection.first
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (returns (optional (some Element)))
              (body
                (conditional
                  (when (call Standard.Logic.equal (call Standard.Collection.count array) 0))
                  (then
                    (return)))
                (return (path array (index 0)))))
            
            (procedure Standard.Collection.last
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (returns (optional (some Element)))
              (body
                (let total (call Standard.Collection.count array))
                (conditional
                  (when (call Standard.Logic.equal total 0))
                  (then
                    (return)))
                (let at (call Standard.Numeric.minus total 1))
                (return (path array (index at)))))
            
            (procedure Standard.Collection.map
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter transform (type (procedure (const) (isolated) (parameters (some Element)) (returns (some Result)))))
              (returns (array (some Result)))
              (body
                (var mapped (array))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count array)))
                    (body
                      (let returned (apply transform (path array (index (path walk (field index))))))
                      (set mapped (call Standard.Collection.appending mapped returned)))))
                (return mapped)))
            
            (procedure Standard.Collection.prepending
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter element (type (some Element)))
              (returns (array (some Element)))
              (body
                (let back (call Standard.Collection.reversed array))
                (let grown (call Standard.Collection.appending back element))
                (return (call Standard.Collection.reversed grown))))
            
            (procedure Standard.Collection.reduce
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
                      (let returned (apply nextPartialResult carried (path array (index (path walk (field index))))))
                      (set carried returned))))
                (return carried)))
            
            (procedure Standard.Collection.reversed
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
                      (set places (call Standard.Collection.appending places (call Standard.Numeric.minus (call Standard.Collection.count array) (call Standard.Numeric.plus (path walk (field index)) 1)))))))
                (return (call Standard.Collection.gathering array places))))
            
            (procedure Standard.Collection.sorted
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
                                (set places (call Standard.Collection.appending places (path scan (field index))))))))))))
                (return (call Standard.Collection.gathering array places))))
            
            (procedure Standard.Collection.tryFilter
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
                          (set places (call Standard.Collection.appending places (path walk (field index)))))))))
                (return (call Standard.Collection.gathering array places))))
            
            (procedure Standard.Collection.tryMap
              (const)
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter transform (type (procedure (const) (isolated) (parameters (some Element)) (failing (anything)) (returns (some Result)))))
              (returns (array (some Result)))
              (failing (anything))
              (body
                (var mapped (array))
                (let walk
                  (loop
                    (while (call Standard.Comparable.lessThan (path walk (field index)) (call Standard.Collection.count array)))
                    (body
                      (let returned (apply transform (path array (index (path walk (field index))))))
                      (set mapped (call Standard.Collection.appending mapped returned)))))
                (return mapped)))
            
            (procedure Standard.Collection.tryReduce
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
                      (let returned (apply nextPartialResult carried (path array (index (path walk (field index))))))
                      (set carried returned))))
                (return carried)))
            
            (procedure Standard.Collection.values
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
                      (set held (call Standard.Collection.appending held (path dictionary (index key)))))))
                (return held)))
            """,
        "concurrent": """
            (warp 1)
            (import Standard.Collection.appending)
            (import Standard.Collection.count)
            (import Standard.Comparable.lessThan)
            (import Standard.Concurrent.all)
            
            (procedure Standard.Concurrent.map
              (isolated)
              (parameter array (type (array (some Element))))
              (parameter transform (type (procedure (isolated) (parameters (some Element) Int) (failing (anything)) (returns (some Result)))))
              (returns (array (some Result)))
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
                          (returns (some Result))
                          (failing (anything))
                          (body
                            (let returned (apply transform item index))
                            (return returned))))
                      (set pieces (call Standard.Collection.appending pieces piece)))))
                (return (call Standard.Concurrent.all pieces))))
            """,
        "logic": """
            (warp 1)
            (import Standard.Collection.count)
            (import Standard.Comparable.lessThan)
            (import Standard.Logic.equal)
            
            (procedure Standard.Logic.and
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
                      (let returned (apply side))
                      (conditional
                        (when (call Standard.Logic.not returned))
                        (then
                          (return false))))))
                (return true)))
            
            (procedure Standard.Logic.not
              (const)
              (isolated)
              (parameter value (type Bool))
              (returns Bool)
              (body
                (return (call Standard.Logic.equal value false))))
            
            (procedure Standard.Logic.notEqual
              (const)
              (isolated)
              (parameter lhs)
              (parameter rhs)
              (returns Bool)
              (body
                (return (call Standard.Logic.equal (call Standard.Logic.equal lhs rhs) false))))
            
            (procedure Standard.Logic.or
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
                      (let returned (apply side))
                      (conditional
                        (when returned)
                        (then
                          (return true))))))
                (return false)))
            
            (procedure Standard.Logic.select
              (const)
              (isolated)
              (parameter condition (type Bool))
              (parameter then (type (procedure (const) (isolated) (parameters) (returns (some Result)))))
              (parameter else (type (procedure (const) (isolated) (parameters) (returns (some Result)))))
              (returns (some Result))
              (body
                (conditional
                  (when condition)
                  (then
                    (let taken (apply then))
                    (return taken)))
                (let left (apply else))
                (return left)))
            
            (procedure Standard.Logic.tryAnd
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
                      (let returned (apply side))
                      (conditional
                        (when (call Standard.Logic.not returned))
                        (then
                          (return false))))))
                (return true)))
            
            (procedure Standard.Logic.tryOr
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
                      (let returned (apply side))
                      (conditional
                        (when returned)
                        (then
                          (return true))))))
                (return false)))
            
            (procedure Standard.Logic.trySelect
              (const)
              (isolated)
              (parameter condition (type Bool))
              (parameter then (type (procedure (const) (isolated) (parameters) (failing (anything)) (returns (some Result)))))
              (parameter else (type (procedure (const) (isolated) (parameters) (failing (anything)) (returns (some Result)))))
              (returns (some Result))
              (failing (anything))
              (body
                (conditional
                  (when condition)
                  (then
                    (let taken (apply then))
                    (return taken)))
                (let left (apply else))
                (return left)))
            """,
        "math": """
            (warp 1)
            (import Standard.Comparable)
            (import Standard.Comparable.lessThan)
            (import Standard.Numeric)
            (import Standard.Numeric.minus)
            
            (procedure Standard.Math.absolute
              (const)
              (isolated)
              (parameter number (type (some N Standard.Comparable Standard.Numeric)))
              (returns (some N))
              (body
                (let zero (call Standard.Numeric.minus number number))
                (conditional
                  (when (call Standard.Comparable.lessThan zero number))
                  (then
                    (return number)))
                (return (call Standard.Numeric.minus zero number))))
            
            (procedure Standard.Math.greaterThan
              (const)
              (isolated)
              (parameter lhs (type (some T Standard.Comparable)))
              (parameter rhs (type (some T)))
              (returns Bool)
              (body
                (return (call Standard.Comparable.lessThan rhs lhs))))
            
            (procedure Standard.Math.max
              (const)
              (isolated)
              (parameter lhs (type (some T Standard.Comparable)))
              (parameter rhs (type (some T)))
              (returns (some T))
              (body
                (conditional
                  (when (call Standard.Comparable.lessThan rhs lhs))
                  (then
                    (return lhs)))
                (return rhs)))
            
            (procedure Standard.Math.min
              (const)
              (isolated)
              (parameter lhs (type (some T Standard.Comparable)))
              (parameter rhs (type (some T)))
              (returns (some T))
              (body
                (conditional
                  (when (call Standard.Comparable.lessThan rhs lhs))
                  (then
                    (return rhs)))
                (return lhs)))
            """,
        "optional": """
            (warp 1)
            
            (procedure Standard.Optional.tryUnwrapped
              (const)
              (isolated)
              (parameter optional (type (optional (some Wrapped))))
              (parameter else (type (procedure (const) (isolated) (parameters) (failing (anything)) (returns (some Wrapped)))))
              (returns (some Wrapped))
              (failing (anything))
              (body
                (let wrapped
                  (unwrap optional
                    (else
                      (let left (apply else))
                      (return left))))
                (return wrapped)))
            
            (procedure Standard.Optional.unwrapped
              (const)
              (isolated)
              (parameter optional (type (optional (some Wrapped))))
              (parameter else (type (procedure (const) (isolated) (parameters) (returns (some Wrapped)))))
              (returns (some Wrapped))
              (body
                (let wrapped
                  (unwrap optional
                    (else
                      (let left (apply else))
                      (return left))))
                (return wrapped)))
            """,
        "text": """
            (warp 1)
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
                          (return true))))))
                (return false)))
            
            (procedure Standard.Text.replacing
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
                    (call Standard.Control.abort "replacing asks an empty piece")))
                (return (call Standard.Text.joined (call Standard.Text.split text target) replacement))))
            
            (procedure Standard.Text.split
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
                          (set at (call Standard.Numeric.plus at 1)))))))
                (return (call Standard.Collection.appending pieces (call Standard.Text.joined current "")))))
            
            (procedure Standard.Text.startsWith
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
                          (return false))))))
                (return true)))
            """
    ]
}
