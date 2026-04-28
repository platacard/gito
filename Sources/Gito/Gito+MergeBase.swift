import Foundation
import Corredor

public extension Gito {
    /// Best common ancestor of `a` and `b`. Returns `nil` when histories are
    /// unrelated (git exits 1 with no output).
    func mergeBase(_ a: String, _ b: String) throws -> String? {
        do {
            let out = try Shell.command("git merge-base \(a) \(b)", in: folder).run()
            return out.isEmpty ? nil : out
        } catch {
            if case ShellRunner.Error.commandFailed(_, 1, _) = error { return nil }
            throw error
        }
    }

    /// `true` if `commit` is reachable from `ref`. Distinguishes
    /// "not an ancestor" (exit 1, returns false) from a missing commit
    /// (exit >= 2, throws).
    func isAncestor(_ commit: String, of ref: String) throws -> Bool {
        do {
            try Shell.command("git merge-base --is-ancestor \(commit) \(ref)", in: folder).run()
            return true
        } catch {
            if case ShellRunner.Error.commandFailed(_, 1, _) = error { return false }
            throw error
        }
    }
}
