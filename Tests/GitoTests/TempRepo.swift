import Foundation

/// Minimal temp git repo for tests. Initialises a repo, configures a user,
/// and exposes helpers for seeding commits. Cleaned up via `tearDown()`.
final class TempRepo {
    let url: URL

    init() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gito-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir
        try git("init", "-b", "main")
        try git("config", "user.email", "test@example.com")
        try git("config", "user.name", "Test")
        try git("commit", "--allow-empty", "-m", "root")
    }

    func tearDown() throws {
        try FileManager.default.removeItem(at: url)
    }

    @discardableResult
    func git(_ args: String...) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = url
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "TempRepo",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "git \(args.joined(separator: " ")) failed: \(String(data: data, encoding: .utf8) ?? "")"]
            )
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Writes a file and commits it. Returns the new HEAD hash.
    @discardableResult
    func commitFile(path: String, content: String, message: String) throws -> String {
        try content.write(to: url.appendingPathComponent(path), atomically: true, encoding: .utf8)
        try git("add", path)
        try git("commit", "-m", message)
        return try git("rev-parse", "HEAD").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func head() throws -> String {
        try git("rev-parse", "HEAD").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
