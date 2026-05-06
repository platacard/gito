import Foundation
import Corredor

public enum CherryPickOutcome: Sendable, Equatable {
    case applied
    case conflict(output: String)
    case empty
    case skipped
    case aborted
}

public enum CherryPickAction: Sendable, Equatable {
    case apply(hash: String, recordOrigin: Bool = true)
    case skip
    case abort
}

public extension Gito {
    @discardableResult
    func cherryPick(_ action: CherryPickAction) throws -> CherryPickOutcome {
        switch action {
        case let .apply(hash, recordOrigin):
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
        case .skip:
            try Shell.command("git cherry-pick --skip", in: folder, options: [.printOutput]).run()
            return .skipped
        case .abort:
            try Shell.command("git cherry-pick --abort", in: folder, options: [.printOutput]).run()
            return .aborted
        }
    }
}
