import Foundation
import Corredor
import Cronista

/// Wraps various git commands.
/// Uses some of GitLab and GitHub predefined variables for CI/CD
///
/// [GitHub variables](https://docs.github.com/en/actions/reference/workflows-and-actions/variables)
/// [GitLab variables](https://docs.gitlab.com/ci/variables/predefined_variables/)
public class Gito {
    private var logger = Cronista(module: "Gito", category: "default")
    private var env: [String: String] { ProcessInfo.processInfo.environment }
    
    private let folder: URL
    
    public nonisolated init(
        in folder: URL = URL(filePath: FileManager.default.currentDirectoryPath)
    ) {
        self.folder = folder
    }
}

// MARK: - Public

public extension Gito {

    func ensureGitStatusClean() throws {
        let result = try Shell.command("git status --porcelain", in: folder, options: [.printOutput]).run()

        if !result.isEmpty {
            logger.error("Git status should be clean! Check your files:")
            logger.error(result)
            
            throw Error.statusDirty(output: result)
        }
    }
    
    /// Branch name for shallow clones
    func currentBranchName() throws -> String {
        if let mrBranch = env["CI_MERGE_REQUEST_SOURCE_BRANCH_NAME"] {
            return mrBranch
        }
        
        if let pushBranch = env["CI_COMMIT_BRANCH"] {
            return pushBranch
        }

        if let prBranch = env["GITHUB_HEAD_REF"] { // Pull request
            return prBranch
        }

        if let pushRef = env["GITHUB_REF"], env["GITHUB_REF_TYPE"] == "branch" { // Push
            return pushRef
        }

        return try Shell.command("git rev-parse --abbrev-ref HEAD", in: folder).run()
    }
    
    /// A "stable" branch to set a tag to. Feature branches are usually ignored for tags
    func isBranchStable(whenIn list: [String] = ["main", "release"]) throws -> Bool {
        let currentBranch = try currentBranchName()
        
        return list.contains(currentBranch)
    }
    
    /// Returns an array of the local tags that reference the current commit (HEAD)
    func getHeadTags() throws -> [String] {
        let output = try Shell.command("git tag --points-at HEAD", in: folder, options: [.printOutput]).run()
        return output.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
    }
    
    /// Sets a tag, does not push
    func setTag(_ tag: String) throws {
        try Shell.command("git tag -a '\(tag)' -m 'plata_swift_tools_\(tag)'", in: folder, options: [.printOutput]).run()
    }
    
    /// Removes the local tag
    func removeTag(_ tag: String) throws {
        try Shell.command("git tag -d '\(tag)'", in: folder, options: [.printOutput]).run()
    }
    
    /// Pushes the tag if present
    func pushTag(_ tag: String) throws {
        try Shell.command("git rev-parse '\(tag)'", in: folder, options: [.printOutput]).run() // Check if the tag exists
        try Shell.command("git push origin '\(tag)'", in: folder, options: [.printOutput]).run()
    }
    
    func commitSHA() throws -> String {
        if let gitlabSHA = env["CI_COMMIT_SHORT_SHA"] {
            return gitlabSHA
        }

        if let githubSHA = env["GITHUB_SHA"] {
            return githubSHA
        }

        let sha = try Shell.command("git log -1 --pretty=format:'%h' | xargs echo", in: folder, options: [.printOutput]).run()
        return sha.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func clone(branch: String, depth: String = "1", url: String, targetFolder: String) throws {
        try Shell.command("git clone --branch \(branch) --depth \(depth) \(url) \(targetFolder)", in: folder, options: [.printOutput]).run()
    }
    
    func add(file: String = ".") throws {
        try Shell.command("git add \(file)", in: folder, options: [.printOutput]).run()
    }
    
    func commit(message: String) throws {
        try Shell.command("git commit -m \"\(message)\"", in: folder, options: [.printOutput]).run()
    }
    
    func push(options: [String], dst: String = "", branch: String = "") throws {
        try Shell.command("git push \(options.joined(separator: " ")) \(dst) \(branch)", in: folder, options: [.printOutput]).run()
    }
    
    func branch(name: String, options: [String] = []) throws {
        try Shell.command("git branch \(options.joined(separator: " ")) \(name)", in: folder, options: [.printOutput]).run()
    }
    
    func checkout(branch: String, options: [String] = []) throws {
        try Shell.command("git checkout \(options.joined(separator: " ")) \(branch)", in: folder, options: [.printOutput]).run()
    }
    
    /// Fetches from remote repositories.
    ///
    /// - Parameters:
    ///   - all: If true, fetches all remotes. Defaults to `true`.
    ///   - prune: If true, removes any remote-tracking references that no longer exist on the remote before fetching. Defaults to `true`.
    ///   - tags: If true, all tags are fetched from the remote (in addition to whatever else is being fetched). Defaults to `false`.
    ///   - depth: If specified, creates a shallow clone with a history truncated to the specified number of commits. If the value is `0` or less, the full history is fetched by unshallowing.
    func fetch(all: Bool = true, prune: Bool = true, tags: Bool = false, depth: Int? = nil) throws {
        let command: [String?] = [
            "git fetch",
            all ? "--all" : nil,
            prune ? "--prune" : nil,
            tags ? "--tags" : nil,
            depth.map { $0 > 0 ? "--depth \($0)" : "--unshallow" }
        ]

        try Shell.command(command.compactMap { $0 }.joined(separator: " "), in: folder, options: [.printOutput]).run()
    }
    
    func mergedRemoteBranches(stripOrigin: Bool = true) throws -> [String] {
        try Shell.command("git --no-pager branch -r --merged origin/main | grep -v HEAD || echo \"\"", in: folder, options: [.printOutput])
            .run()
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map {
                guard stripOrigin else { return $0 }
                return $0.replacingOccurrences(of: "origin/", with: "")
            }
    }
    
    func unmergedRemoteBranches(stripOrigin: Bool = true) throws -> [String] {
        try Shell.command("git --no-pager branch -r --no-merged | grep -v HEAD || echo \"\"", in: folder, options: [.printOutput])
            .run()
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map {
                guard stripOrigin else { return $0 }
                return $0.replacingOccurrences(of: "origin/", with: "")
            }
    }
    
    /// Returns the last commit date and author
    func lastCommitInfo(branch: String) throws -> String {
        try Shell.command(
            "git --no-pager log --no-merges -n 1 --format=\"%cr, %an\" \(branch)",
            in: folder,
            options: [.printOutput]
        )
        .run()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Returns the list of branches when the last commit is older than `daysThreshold`.
    /// 30 days by default.
    func staleBranches(daysThreshold: Int = 30) throws -> [(branchName: String, info: String)] {
        var stale: [(String, String)] = []
        
        let unmerged = try unmergedRemoteBranches(stripOrigin: false)
        for branch in unmerged {
            let lastCommitDate = try Shell.command(
                "git --no-pager log -1 --format=%cd --date=iso-strict \(branch)",
                in: folder,
                options: [.printOutput]
            )
            .run()

            let trimmedLastCommitDate = lastCommitDate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLastCommitDate.isEmpty else {
                continue
            }
            
            let date = try Date(trimmedLastCommitDate, strategy: .iso8601)
            if Date.now.days(from: date) > daysThreshold {
                let commitInfo = try lastCommitInfo(branch: branch)
                stale.append((branchName: branch, info: commitInfo))
            }
        }
        
        return stale
    }
    
    /// Removes the branch from remote (origin)
    func removeRemoteBranch(_ branch: String) throws {
        try Shell.command("git push --delete origin \(branch)", in: folder, options: [.printOutput]).run()
    }
    
    enum CommitComponent: String, CaseIterable {
        case hash = "h"
        case fullHash = "H"
        case authorName = "an"
        case authorEmail = "ae"
        case subject = "s"
    }
    
    func getCommits(
        since: Date,
        until: Date,
        components: [CommitComponent]
    ) throws -> [[CommitComponent: String]] {
        func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
        let sinceString = formatDate(since)
        let untilString = formatDate(until)
        let componentsString = components.map { "%\($0.rawValue)" }.joined(separator: "~")
        
        let result = try Shell.command(
            """
            git log \
            --since="\(sinceString)" \
            --until="\(untilString)" \
            --pretty=format:"\(componentsString)"
            """,
            in: folder,
            options: [.printOutput]
        )
        .run()

        return result
            .split(separator: "\n")
            .map { String($0) }
            .map { commit in
                commit
                    .split(separator: "~")
                    .map { String($0) }
                    .enumerated()
                    .reduce(into: [CommitComponent: String]()) { result, element in
                        let component = components[element.offset]
                        result[component] = element.element
                    }
            }
    }
    
    /// Returns total number of changed lines by an author.
    /// 
    /// Example:
    /// ```
    /// ["email@dif.tech": 1]
    /// ```
    func getChangedLinesCount(since: Date, until: Date) throws -> [String: Int] {
        let commits = try getCommits(
            since: since,
            until: until,
            components: [.fullHash, .authorEmail]
        )
        
        var changedLines = [String: Int]()
                
        for commit in commits {
            guard
                let hash = commit[.fullHash],
                let authorEmail = commit[.authorEmail]
            else { continue }
            
            let linesCount = try Shell.command(
                """
                git show --numstat \
                --pretty="format:" \
                "\(hash)" | awk '{added+=$1; deleted+=$2} END {print added+deleted}'
                """,
                in: folder,
                options: [.printOutput]
            )
            .run()
            .trimmingCharacters(in: .whitespacesAndNewlines)

            changedLines[authorEmail, default: 0] += Int(linesCount) ?? 0
        }
        
        return changedLines
    }
}

// MARK: - Extensions

extension Date {
    func days(from date: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }
}

// MARK: - Subtypes

extension Gito {
    enum Error: LocalizedError {
        case statusDirty(output: String)
    }
}
