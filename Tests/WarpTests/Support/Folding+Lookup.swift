//
//  Folding+Lookup.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
@testable import Warp

extension Folding {
    func lookup(_ path: Path) async -> Lookup {
        do {
            return .found(try await read(path, at: .given("test")))
        } catch let unfit as ReferenceUnfit {
            return .unfit(reason: unfit.reason)
        } catch {
            return .unfit(reason: "\(error)")
        }
    }
}
