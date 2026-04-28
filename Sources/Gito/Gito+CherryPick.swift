import Foundation
import Corredor

public enum CherryPickOutcome: Sendable, Equatable {
    case applied
    case conflict(output: String)
    case empty
}

// Three separate methods. cherryPick has meaningful exit-1 outcomes
// (conflict, empty); skip and abort don't.
public extension Gito {
    @discardableResult
    func cherryPick(hash: String, recordOrigin: Bool = true) throws -> CherryPickOutcome {
        let cmd = recordOrigin ? "git cherry-pick -x \(hash)" : "git cherry-pick \(hash)"
        do {
            try Shell.command(cmd, in: folder, options: [.printOutput]).run()
            return .applied
        } catch {
            if case let ShellRunner.Error.commandFailed(_, 1, output) = error {
                if output.contains("now empty") { return .empty }
                return .conflict(output: output)
            }
            throw error
        }
    }

    func cherryPickSkip() throws {
        try Shell.command("git cherry-pick --skip", in: folder, options: [.printOutput]).run()
    }

    func cherryPickAbort() throws {
        try Shell.command("git cherry-pick --abort", in: folder, options: [.printOutput]).run()
    }
}
