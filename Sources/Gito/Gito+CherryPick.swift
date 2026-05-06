import Foundation
import Corredor

public enum CherryPickOutcome: Sendable, Equatable {
    case applied
    case conflict(output: String)
    case empty
}

public extension Gito {
    @discardableResult
    func cherryPick(hash: String, recordOrigin: Bool = true) throws -> CherryPickOutcome {
        let cmd = recordOrigin ? "git cherry-pick -x \(hash)" : "git cherry-pick \(hash)"
        do {
            try Shell.command(cmd, in: folder, options: [.printOutput]).run()
            return .applied
        } catch {
            guard case let .commandFailed(_, exitCode, output) = error, exitCode == 1 else {
                throw error
            }
            let unmerged = (try? Shell.command("git ls-files --unmerged", in: folder).run()) ?? ""
            return unmerged.isEmpty ? .empty : .conflict(output: output)
        }
    }

    func cherryPickSkip() throws {
        try Shell.command("git cherry-pick --skip", in: folder, options: [.printOutput]).run()
    }

    func cherryPickAbort() throws {
        try Shell.command("git cherry-pick --abort", in: folder, options: [.printOutput]).run()
    }
}
