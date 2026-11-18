//
//  BodyWalk.swift
//  Warp
//
//  Created by JSilver on 11/2/26.
//

import Foundation

// What the statement walk hands back for a body.
struct BodyWalk {
    // MARK: - Property
    let body: Body
    let calls: [CallSite]
    let judgements: JudgementTable
    let environment: [Name: Binding]
    let reading: LoweredType
    let flow: Flow
    let locals: Set<Name>

    // MARK: - Initializer
    init(
        body: Body,
        calls: [CallSite],
        judgements: JudgementTable,
        environment: [Name: Binding],
        reading: LoweredType,
        flow: Flow,
        locals: Set<Name>
    ) {
        self.body = body
        self.calls = calls
        self.judgements = judgements
        self.environment = environment
        self.reading = reading
        self.flow = flow
        self.locals = locals
    }

    // MARK: - Public
    // MARK: - Private
}
