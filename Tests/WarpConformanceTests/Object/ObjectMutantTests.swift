//
//  ObjectMutantTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 9/15/26.
//

import Foundation
import Testing
import Warp
import WarpSyntax
import WarpTestSupport

// An object with one place of it replaced, taken as far as it goes.
//
// `ObjectMutationTests`, in the core tests, asks the reading the same question
// and stops there, which leaves half the standard unasked: a reading that traps
// ends the host, and so does a link or a run standing on what that reading
// admitted. What is asked here is the whole way. A mutant is read, and if it
// reads it is linked, and if it links it is run.
//
// A refusal is an outcome at every stage. So is a return value. A trap is
// neither, and the assertion this suite makes is the one nothing can be
// written down for: the process is still here when it ends.
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
    // The time one run is given. It counts from when the run starts rather than
    // from when it was asked for, since a run still waiting for a thread has used
    // none of it. It rings on a queue of its own: a run that does not finish holds
    // its thread until it is stopped, and enough of them hold every thread of the
    // pool they run on, so a clock waiting for one of those would wait on them.
    private final class RunClock: @unchecked Sendable {
        // MARK: - Property
        // What every mutant is given first, and what one is given again where no
        // mutant of its object finished within the first.
        static let short = DispatchTimeInterval.milliseconds(50)
        static let long = DispatchTimeInterval.seconds(10)

        private static let ringing = DispatchQueue(label: "ObjectMutantTests.RunClock")

        private let time: DispatchTimeInterval
        private let lock = NSLock()
        private var run: Task<Value, any Error>?
        private var rang = false

        // MARK: - Initializer
        init(_ time: DispatchTimeInterval) {
            self.time = time
        }

        // MARK: - Public
        func start() {
            Self.ringing.asyncAfter(deadline: .now() + time) { self.ring() }
        }

        func stops(_ run: Task<Value, any Error>) {
            let rang = lock.withLock {
                self.run = run

                return self.rang
            }

            if rang { run.cancel() }
        }

        // MARK: - Private
        private func ring() {
            let run = lock.withLock {
                rang = true

                return self.run
            }

            run?.cancel()
        }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused or finishes at every stage it reaches", arguments: try Case.all())
    func everyMutantIsRefusedOrFinishes(_ sut: Case) async throws {
        // Given. A case the build refuses has no object to mutate, and that
        // it is refused is the runner's question rather than this one.
        guard case let .program(program) = sut.asked, case .answers = program.expectation else { return }

        let builder = Builder(fingerprinting: Fingerprint.of)
        let supplying = try await Supplying(program.modules())
        let behind = try await builder.compile(try program.brought + program.beside + Module.standard, against: [], supplying: supplying)
        let own = try await builder.compile(
            [try Loader().load(program.document)],
            against: behind,
            supplying: supplying
        )

        guard own.count == 1, let written = try? own[0].object() else {
            Issue.record("\(sut.name): a document of the specification's is one an object can hold")

            return
        }

        var ran = 0
        var finished = 0
        var clocked: [(path: String, image: Image)] = []

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
                image = try builder.link(behind + [read], supplying: supplying)
            } catch is WarpError {
                continue
            } catch {
                Issue.record("\(sut.name) at \(path): the link refused as \(type(of: error))")

                continue
            }

            ran += 1

            if await running(image, arguments: program.arguments, of: sut, at: path, given: RunClock.short) {
                finished += 1
            } else {
                clocked.append((path, image))
            }
        }

        // A machine under load can hold every run past the short clock. So
        // where none finished, the mutants that met it run again on the long
        // one, one at a time, until one finishes: a run that does not finish
        // still meets it, and one that does is not told apart by the load.
        for (path, image) in clocked where finished == 0 {
            if await running(image, arguments: program.arguments, of: sut, at: path, given: RunClock.long) { finished += 1 }
        }

        // Then. Mutants reached the run, and the run reached an end. A walk
        // that read nothing would make every sentence above true by asking
        // nothing, and so would one whose every mutant met the clock instead.
        #expect(ran > 0, "\(sut.name): no mutant of this object was read back and linked")
        #expect(finished > 0, "\(sut.name): every one of \(ran) mutants met the clock rather than finishing")
    }

    // MARK: - Public
    // MARK: - Private
    // One mutant run, or the clock, whichever comes first. What the run
    // returns is not asked: a program whose object was mutated is a
    // different program, and what a different program returns is its own
    // business. What is asked is that it finished at all.
    private func running(
        _ image: Image,
        arguments: [Name: Value],
        of sut: Case,
        at path: String,
        given time: DispatchTimeInterval
    ) async -> Bool {
        let clock = RunClock(time)
        let run = Task {
            clock.start()

            return try await Executor().run(image, entry: "entry", arguments: arguments)
        }

        clock.stops(run)

        guard case let .failure(error) = await run.result else { return true }

        // The clock came first.
        guard !(error is CancellationError) else { return false }

        guard !(error is any WarpError) else { return true }

        Issue.record("\(sut.name) at \(path): the run refused as \(type(of: error))")

        return true
    }
}
