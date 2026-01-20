import Foundation
import XCTest
@testable import Gito

final class GitStorageTests: XCTestCase {

    var tempDir: URL!
    var sut: GitStorage!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("gito_test_\(UUID().uuidString)")
        sut = GitStorage(localPath: tempDir.path, branch: "main")
    }

    override func tearDown() async throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Initialization Tests

    func testLocalInitialization() async throws {
        // When
        try await sut.cloneOrPull()

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent(".git").path))
    }

    func testLocalInitializationIsIdempotent() async throws {
        // Given
        try await sut.cloneOrPull()

        // When - call again
        try await sut.cloneOrPull()

        // Then - should not throw, repo still exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
    }

    // MARK: - File Operations Tests

    func testFileExists_WhenFileDoesNotExist() async throws {
        // Given
        try await sut.cloneOrPull()

        // When
        let exists = await sut.fileExists(path: "nonexistent.txt")

        // Then
        XCTAssertFalse(exists)
    }

    func testFileExists_WhenFileExists() async throws {
        // Given
        try await sut.cloneOrPull()
        try await sut.writeFile(path: "test.txt", content: "Hello".data(using: .utf8)!)

        // When
        let exists = await sut.fileExists(path: "test.txt")

        // Then
        XCTAssertTrue(exists)
    }

    func testWriteAndReadFile() async throws {
        // Given
        try await sut.cloneOrPull()
        let content = "Hello, World!".data(using: .utf8)!

        // When
        try await sut.writeFile(path: "test.txt", content: content)
        let readContent = try await sut.readFile(path: "test.txt")

        // Then
        XCTAssertEqual(content, readContent)
    }

    func testWriteFileCreatesIntermediateDirectories() async throws {
        // Given
        try await sut.cloneOrPull()
        let content = "Nested content".data(using: .utf8)!

        // When
        try await sut.writeFile(path: "nested/deep/file.txt", content: content)

        // Then
        let exists = await sut.fileExists(path: "nested/deep/file.txt")
        XCTAssertTrue(exists)
    }

    // MARK: - Remote Tests

    func testHasRemote_WhenNoRemote() async throws {
        // Given
        try await sut.cloneOrPull()

        // When
        let hasRemote = await sut.hasRemote()

        // Then
        XCTAssertFalse(hasRemote)
    }

    func testSetRemote() async throws {
        // Given
        try await sut.cloneOrPull()

        // When
        try await sut.setRemote(url: "https://github.com/example/test.git")

        // Then
        let hasRemote = await sut.hasRemote()
        XCTAssertTrue(hasRemote)
    }

    func testSetRemoteUpdatesExisting() async throws {
        // Given
        try await sut.cloneOrPull()
        try await sut.setRemote(url: "https://github.com/example/old.git")

        // When
        try await sut.setRemote(url: "https://github.com/example/new.git")

        // Then
        let hasRemote = await sut.hasRemote()
        XCTAssertTrue(hasRemote)
    }

    // MARK: - Commit Tests

    func testCommitAndPush_LocalOnly() async throws {
        // Given
        try await sut.cloneOrPull()
        try await sut.writeFile(path: "newfile.txt", content: "Content".data(using: .utf8)!)

        // When - should not throw even without remote
        try await sut.commitAndPush(message: "Add new file")

        // Then
        let sha = try await sut.currentShortSHA()
        XCTAssertFalse(sha.isEmpty)
    }

    func testCommitAndPush_NoChanges() async throws {
        // Given
        try await sut.cloneOrPull()

        // When - should not throw when there's nothing to commit
        try await sut.commitAndPush(message: "No changes")

        // Then - no assertion needed, just verifying no throw
    }

    // MARK: - SHA Tests

    func testCurrentCommitSHA() async throws {
        // Given
        try await sut.cloneOrPull()

        // When
        let sha = try await sut.currentCommitSHA()

        // Then
        XCTAssertEqual(sha.count, 40) // Full SHA is 40 characters
    }

    func testCurrentShortSHA() async throws {
        // Given
        try await sut.cloneOrPull()

        // When
        let sha = try await sut.currentShortSHA()

        // Then
        XCTAssertTrue(sha.count >= 7 && sha.count <= 12) // Short SHA is typically 7-12 chars
    }

    // MARK: - LocalURL Tests

    func testLocalURL_Remote() async throws {
        // Given
        let storage = GitStorage(url: "https://github.com/example/test.git", branch: "main")

        // Then
        let localURL = await storage.localURL
        XCTAssertTrue(localURL.path.contains("gito_storage_"))
    }

    func testLocalURL_Local() async throws {
        // Given
        let path = "/custom/path"
        let storage = GitStorage(localPath: path, branch: "main")

        // Then
        let localURL = await storage.localURL
        XCTAssertEqual(localURL.path, path)
    }
}
