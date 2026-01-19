import Foundation

/// Protocol for git repository management operations.
/// Enables dependency injection and testing.
public protocol GitManaging: Sendable {
    /// The local URL of the repository
    var localURL: URL { get }

    /// Clone from remote or initialize/pull local repo
    func cloneOrPull() async throws

    /// Set or update the remote origin URL
    func setRemote(url: String) async throws

    /// Check if a remote origin is configured
    func hasRemote() async -> Bool

    /// Commit all changes and push to remote (if configured)
    func commitAndPush(message: String) async throws

    /// Check if a file exists at the given path (relative to repo root)
    func fileExists(path: String) async -> Bool

    /// Read file contents from the given path (relative to repo root)
    func readFile(path: String) async throws -> Data

    /// Write data to a file at the given path (relative to repo root)
    /// Creates intermediate directories if needed
    func writeFile(path: String, content: Data) async throws
}
