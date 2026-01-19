import Foundation
import Corredor
import Cronista

/// Actor for managing a git repository as encrypted storage.
/// Supports both remote-first and local-first workflows.
public actor GitStorage: GitManaging {
    /// Remote repository URL (nil for local-only repos)
    public let remoteURL: String?

    /// Branch name to work with
    public let branch: String

    /// Local path where the repository is stored
    public let localURL: URL

    private let logger = Cronista(module: "Gito", category: "GitStorage")

    // MARK: - Initializers

    /// Initialize with a remote URL (will clone/pull from remote)
    /// - Parameters:
    ///   - url: Remote repository URL
    ///   - branch: Branch name (defaults to "main")
    public init(url: String, branch: String = "main") {
        self.remoteURL = url
        self.branch = branch
        let hash = String(format: "%02x", url.hashValue)
        self.localURL = FileManager.default.temporaryDirectory.appendingPathComponent("gito_storage_\(hash)")
    }

    /// Initialize with a local path only (local-first, no remote)
    /// - Parameters:
    ///   - localPath: Local filesystem path for the repository
    ///   - branch: Branch name (defaults to "main")
    public init(localPath: String, branch: String = "main") {
        self.remoteURL = nil
        self.branch = branch
        self.localURL = URL(fileURLWithPath: localPath)
    }

    /// Initialize with a remote URL and a specific local path (clone remote to local)
    /// - Parameters:
    ///   - url: Remote repository URL
    ///   - localPath: Local filesystem path for the repository
    ///   - branch: Branch name (defaults to "main")
    public init(url: String, localPath: String, branch: String = "main") {
        self.remoteURL = url
        self.branch = branch
        self.localURL = URL(fileURLWithPath: localPath)
    }

    // MARK: - GitManaging

    public func cloneOrPull() throws {
        if let url = remoteURL {
            try cloneOrPullFromRemote(url: url)
        } else {
            try initLocalIfNeeded()
        }
    }

    public func setRemote(url: String) throws {
        let hasExistingRemote = hasRemoteSync()
        if hasExistingRemote {
            try run("git remote set-url origin \(url)")
        } else {
            try run("git remote add origin \(url)")
        }
        logger.info("Remote set to \(url)")
    }

    public func hasRemote() -> Bool {
        return hasRemoteSync()
    }

    public func commitAndPush(message: String, push: Bool = false) throws {
        logger.info("Committing changes: \(message)")
        try run("git add .")

        // Check if there are changes to commit
        let status = try run("git status --porcelain")
        guard !status.isEmpty else {
            logger.info("No changes to commit")
            return
        }

        try run("git commit -m \"\(message)\"")

        guard push else { return }

        if hasRemoteSync() {
            logger.info("Pushing to remote...")
            try run("git push origin \(branch)")
        } else {
            logger.info("No remote configured, changes committed locally only")
        }
    }

    public func fileExists(path: String) -> Bool {
        return FileManager.default.fileExists(atPath: localURL.appendingPathComponent(path).path)
    }

    public func readFile(path: String) throws -> Data {
        return try Data(contentsOf: localURL.appendingPathComponent(path))
    }

    public func writeFile(path: String, content: Data) throws {
        let fileURL = localURL.appendingPathComponent(path)
        let directory = fileURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try content.write(to: fileURL)
    }

    // MARK: - Additional Operations

    /// Pull latest changes from remote
    public func pull() throws {
        guard hasRemoteSync() else {
            logger.warning("No remote configured, cannot pull")
            return
        }
        try run("git pull origin \(branch)")
    }

    /// Reset local changes and match remote
    public func reset(hard: Bool = false) throws {
        if hard {
            try run("git reset --hard")
        } else {
            try run("git reset")
        }
    }

    /// Get current commit SHA
    public func currentCommitSHA() throws -> String {
        return try run("git rev-parse HEAD").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get short commit SHA
    public func currentShortSHA() throws -> String {
        return try run("git rev-parse --short HEAD").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    private func cloneOrPullFromRemote(url: String) throws {
        if FileManager.default.fileExists(atPath: localURL.path) {
            logger.info("Repo exists at \(localURL.path), pulling...")
            if !FileManager.default.fileExists(atPath: localURL.appendingPathComponent(".git").path) {
                try FileManager.default.removeItem(at: localURL)
                try clone(from: url)
            } else {
                try run("git reset --hard")
                try run("git pull origin \(branch)")
            }
        } else {
            try clone(from: url)
        }
    }

    private func initLocalIfNeeded() throws {
        if FileManager.default.fileExists(atPath: localURL.appendingPathComponent(".git").path) {
            logger.info("Local repo exists at \(localURL.path)")
            return
        }

        logger.info("Initializing local repo at \(localURL.path)...")
        try FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: true)
        try run("git init")
        try run("git checkout -b \(branch)")

        // Create initial .gitkeep to have something to commit
        let gitkeepPath = localURL.appendingPathComponent(".gitkeep")
        try "".write(to: gitkeepPath, atomically: true, encoding: .utf8)
        try run("git add .")
        try run("git commit -m \"Initialize storage\"")
    }

    private func clone(from url: String) throws {
        logger.info("Cloning \(url) to \(localURL.path)...")
        try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let parentDir = localURL.deletingLastPathComponent().path
        try Shell.command("cd \(parentDir) && git clone --branch \(branch) \(url) \(localURL.path)").run()
    }

    private func hasRemoteSync() -> Bool {
        return (try? run("git remote get-url origin")) != nil
    }

    @discardableResult
    private func run(_ command: String) throws -> String {
        do {
            return try Shell.command(command, in: localURL).run()
        } catch {
            throw Error.commandFailed(command: command, underlying: error)
        }
    }

    // MARK: - Error

    public enum Error: Swift.Error, LocalizedError {
        case commandFailed(command: String, underlying: Swift.Error)

        public var errorDescription: String? {
            switch self {
            case .commandFailed(let cmd, let err):
                return "Git command failed: \(cmd). Error: \(err.localizedDescription)"
            }
        }
    }
}
