import Testing
@testable import Warp

@Suite("probe: does a host native reach the artifact")
struct NativeProbeTests {
    private func artifact(answering value: Int) throws -> Value? {
        let vocabulary = try Module(
            procedures: [
                "host.answer": Procedure(
                    signature: Signature(returns: .int),
                    implementation: .query(AnsweringQuery(value: value))
                )
            ]
        )
        let program = try Module(
            constants: ["app.settled": .call(Call(selector: "host.answer"))],
            procedures: [
                "app.main": Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .reference([.key("app.settled")])
                )
            ]
        )

        let builder = Builder { written in Fingerprint(Array("\(written)".utf8)) }
        let behind = try builder.compile([vocabulary])
        let compiled = try builder.compile(
            [program],
            against: behind,
            supplying: Supplying([vocabulary, program])
        )

        print("behind fingerprint:", behind[0].fingerprint?.short ?? "<none>")
        print("program fingerprint:", compiled[0].fingerprint?.short ?? "<none>")

        return compiled[0].written
    }

    @Test("the same document folded through two different natives")
    func foldedThroughANative() throws {
        let one = try artifact(answering: 1)
        let two = try artifact(answering: 2)

        #expect(one != nil)
        #expect(one == two, "the host's native changed the artifact and nothing in the key moved")
    }
}

private struct AnsweringQuery: Query {
    typealias Parameters = NoParameters

    let value: Int

    func evaluate(_ question: Question<Self>) throws -> Value? {
        .int(value)
    }
}
