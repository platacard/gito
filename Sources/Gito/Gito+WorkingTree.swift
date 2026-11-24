import Foundation
import Corredor

/// Files of the working tree and the index, for tools that search or watch a repository.
///
/// Unlike the rest of `Gito`, these run git with an argument list (no shell: any path is safe), print nothing
/// whatever `GITO_QUIET` says (the caller may own stdout, e.g. an MCP server speaking JSON-RPC over it), and read
/// git's `-z` output, so paths come back verbatim, unquoted, even with spaces or non-ASCII characters.
///
/// Paths are relative to the toplevel: create the `Gito` in the repository's toplevel (see `topLevel()`).
/// `paths` arguments are literal repo-relative paths, folders included recursively; empty means everything.
public extension Gito {

    /// The toplevel of the repository containing `folder`, or nil outside a repository.
    func topLevel() -> String? {
        let output = try? git(["rev-parse", "--show-toplevel"])
        return output.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Whether `commit` names a commit of this repository.
    func containsCommit(_ commit: String) -> Bool {
        (try? git(["cat-file", "-e", commit + "^{commit}"])) != nil
    }

    /// Files that differ between `commit` and the working tree, deletions included; a rename is its two paths.
    func changedFiles(since commit: String, under paths: [String] = []) throws -> [String] {
        try files(["diff", "--name-only", "--no-renames", "-z", commit], under: paths)
    }

    /// Untracked files git does not ignore.
    func untrackedFiles(under paths: [String] = []) throws -> [String] {
        try files(["ls-files", "-z", "--others", "--exclude-standard"], under: paths)
    }

    /// Tracked files (the index).
    func trackedFiles(under paths: [String] = []) throws -> [String] {
        try files(["ls-files", "-z"], under: paths)
    }

    /// Tracked files plus untracked files git does not ignore: every file `git add .` would consider.
    func listedFiles(under paths: [String] = []) throws -> [String] {
        try files(["ls-files", "-z", "--cached", "--others", "--exclude-standard"], under: paths)
    }

    /// Folders git ignores as a whole, e.g. `.build`: nothing inside them is ever listed.
    func ignoredFolders() throws -> [String] {
        try files(["ls-files", "-z", "--others", "--ignored", "--exclude-standard", "--directory"])
            .filter { $0.hasSuffix("/") }
            .map { String($0.dropLast()) }
    }

    /// Git's index file, which `add`, `rm`, `commit` and `checkout` rewrite: its modification time tells
    /// a watcher that the tracked files may have changed. Nil outside a repository.
    func indexFile() -> URL? {
        guard let path = try? git(["rev-parse", "--git-path", "index"]), !path.isEmpty else {
            return nil
        }
        return path.hasPrefix("/") ? URL(filePath: path) : folder.appending(path: path)
    }
}

// MARK: - Private

private extension Gito {

    /// `git <arguments> -- <paths>`, its output split on the NUL bytes of `-z`.
    func files(_ arguments: [String], under paths: [String] = []) throws -> [String] {
        // Literal pathspecs: a folder named `[a]` or `*` is that folder, not a glob.
        let output = try git(["--literal-pathspecs"] + arguments + ["--"] + paths)
        // Split the bytes: splitting a String walks grapheme clusters, slow on tens of thousands of paths.
        return output.utf8.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
    }

    /// Runs git without a shell and without printing. `core.quotePath` only affects output without `-z`,
    /// but keeps any path git prints verbatim.
    func git(_ arguments: [String]) throws -> String {
        try Shell.arguments(["git", "-c", "core.quotePath=false"] + arguments, in: folder).run()
    }
}
