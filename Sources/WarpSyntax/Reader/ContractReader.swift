//
//  ContractReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Warp

// A contract: the procedures a type that answers it declares, by name.
struct ContractReader: Decodable {
    // MARK: - Property
    let procedures: [Name: ContractProcedure]

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        self.procedures = try decoder.read([Name: ContractProcedureReader].self).mapValues(\.procedure)
    }

    // MARK: - Public
    // MARK: - Private
}
