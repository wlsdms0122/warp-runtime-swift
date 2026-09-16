//
//  ObjectMutantTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 9/15/26.
//

import Foundation
import Testing
import Warp
import WarpMutation
import WarpSyntax

// An object with one place of it replaced, taken as far as it goes.
//
// The suite beside this one asks the reading the same question and stops there,
// which leaves half the standard unasked: a reading that traps ends the host,
// and so does a link or a run standing on what that reading admitted. What is
// asked here is the whole way. A mutant is read, and if it reads it is linked,
// and if it links it is run.
//
// A refusal is an answer at every stage. So is an answer. A trap is neither,
// and the assertion this suite makes is the one nothing can be written down
// for: the process is still here when it ends.
//
// A mutant that does not finish is not a defect. Stopping work that runs away
// is the host's, which is why the run is raced against a clock rather than
// waited on.
//
// The corpus is the specification's cases, because that is the widest body of
// programs there is. Each case's own document is compiled against the rest, so
// what is mutated is the object that case is about rather than the standard
// vocabulary read again for every one of them.
@Suite("An object mutant, built and run")
struct ObjectMutantTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused or answered at every stage it reaches", arguments: try Case.all())
    func everyMutantIsAnswered(_ sut: Case) async throws {
        // Given. A case the build refuses has no object to mutate, and that
        // it is refused is the runner's question rather than this one.
        guard case .answers = sut.expectation else { return }

        let builder = Builder(fingerprinting: Fingerprint.of)
        let supplying = try await Supplying(sut.modules())
        let behind = try await builder.compile(try sut.brought + Module.standard, against: [], supplying: supplying)
        let own = try await builder.compile(
            [try Loader().load(sut.program, identity: nil)],
            against: behind,
            supplying: supplying
        )

        guard own.count == 1, let written = own[0].written else {
            Issue.record("\(sut.name): a document of the specification's is one an object can hold")

            return
        }

        var ran = 0
        var answered = 0

        // When. Each place of the writing replaced in turn, and whatever
        // stands after that carried to the next stage.
        for (path, mutated) in Mutator().mutations(of: written) {
            let read: Compiled

            do {
                read = try Compiled(written: mutated, of: own[0].identity)
            } catch is ObjectRefused {
                continue
            } catch {
                Issue.record("\(sut.name) at \(path): the reading refused as \(type(of: error))")

                continue
            }

            let image: Image

            do {
                image = try builder.link(behind + [read], entry: "entry", supplying: supplying)
            } catch is WarpError {
                continue
            } catch {
                Issue.record("\(sut.name) at \(path): the link refused as \(type(of: error))")

                continue
            }

            ran += 1

            if await running(image, arguments: sut.arguments, of: sut, at: path) { answered += 1 }
        }

        // Then. Mutants reached the run, and the run reached an end. A walk
        // that read nothing would make every sentence above true by asking
        // nothing, and so would one whose every mutant met the clock instead.
        #expect(ran > 0, "\(sut.name): no mutant of this object was read back and linked")
        #expect(answered > 0, "\(sut.name): every one of \(ran) mutants met the clock rather than an answer")
    }

    // MARK: - Public
    // MARK: - Private
    // One mutant run, or the clock, whichever comes first. What the run
    // answers is not asked: a program whose object was mutated is a
    // different program, and what a different program answers is its own
    // business. What is asked is that it answered at all.
    private func running(
        _ image: Image,
        arguments: [Name: Value],
        of sut: Case,
        at path: String
    ) async -> Bool {
        let raced: Result<Value, any Error>?? = await withTaskGroup(of: Result<Value, any Error>?.self) { racing in
            racing.addTask {
                do {
                    return .success(try await Executor().run(image, arguments: arguments))
                } catch {
                    return .failure(error)
                }
            }
            racing.addTask {
                try? await Task.sleep(for: .milliseconds(50))

                return nil
            }

            let first = await racing.next() ?? nil

            racing.cancelAll()

            return first
        }

        // The clock came first. A mutant that does not finish is not a defect,
        // because stopping work that runs away is the host's.
        guard let raced, let answer = raced else { return false }

        guard case let .failure(error) = answer else { return true }

        guard !(error is any WarpError), !(error is CancellationError) else { return true }

        Issue.record("\(sut.name) at \(path): the run refused as \(type(of: error))")

        return true
    }
}
