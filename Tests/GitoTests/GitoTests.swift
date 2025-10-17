import Foundation
import XCTest
import Corredor
@testable import Gito

final class GitoTests: XCTestCase {

    let sut = Gito(in: .testDirUrl())

    func test_CurrentBranchIsStableOnMR() throws {
        // Given
        setenv("CI_COMMIT_BRANCH", "main", 1)
        // When
        let isStable = try sut.isBranchStable()
        // Then
        XCTAssertTrue(isStable)
        // Teardown
        unsetenv("CI_COMMIT_BRANCH")
    }
    
    func test_CurrentBranchIsNotStableOnMR() throws {
        // Given
        setenv("CI_COMMIT_BRANCH", "feature-1", 1)
        // When
        let isStable = try sut.isBranchStable()
        // Then
        XCTAssertFalse(isStable)
        // Teardown
        unsetenv("CI_COMMIT_BRANCH")
    }
    
    func test_CurrentBranchIsStableOnPush() throws {
        // Given
        setenv("CI_MERGE_REQUEST_SOURCE_BRANCH_NAME", "main", 1)
        // When
        let isStable = try sut.isBranchStable()
        // Then
        XCTAssertTrue(isStable)
        // Teardown
        unsetenv("CI_MERGE_REQUEST_SOURCE_BRANCH_NAME")
    }
    
    func test_CurrentBranchIsNotStableOnPush() throws {
        // Given
        setenv("CI_MERGE_REQUEST_SOURCE_BRANCH_NAME", "feature-1", 1)
        // When
        let isStable = try sut.isBranchStable()
        // Then
        XCTAssertFalse(isStable)
        // Teardown
        unsetenv("CI_MERGE_REQUEST_SOURCE_BRANCH_NAME")
    }
    
    func test_CommitShaFromGitlab() throws {
        // Given
        let expected = "123"
        setenv("CI_COMMIT_SHORT_SHA", expected, 1)
        // When
        let actual = try sut.commitSHA()
        // Then
        XCTAssertEqual(expected, actual)
        // Teardown
        unsetenv("CI_COMMIT_SHORT_SHA")
    }
    
    func test_CommitShaFromGitHub() throws {
        // Given
        let expected = "abc123def456"
        setenv("GITHUB_SHA", expected, 1)
        // When
        let actual = try sut.commitSHA()
        // Then
        XCTAssertEqual(expected, actual)
        // Teardown
        unsetenv("GITHUB_SHA")
    }
    
    func test_CurrentBranchFromGitHubPullRequest() throws {
        // Given
        let expected = "feature-branch"
        setenv("GITHUB_HEAD_REF", expected, 1)
        // When
        let actual = try sut.currentBranchName()
        // Then
        XCTAssertEqual(expected, actual)
        // Teardown
        unsetenv("GITHUB_HEAD_REF")
    }
    
    func test_CurrentBranchFromGitHubPush() throws {
        // Given
        let expected = "refs/heads/main"
        setenv("GITHUB_REF", expected, 1)
        setenv("GITHUB_REF_TYPE", "branch", 1)
        // When
        let actual = try sut.currentBranchName()
        // Then
        XCTAssertEqual(expected, actual)
        // Teardown
        unsetenv("GITHUB_REF")
        unsetenv("GITHUB_REF_TYPE")
    }
    
    func test_CurrentBranchIsStableFromGitHubPullRequest() throws {
        // Given
        setenv("GITHUB_HEAD_REF", "main", 1)
        // When
        let isStable = try sut.isBranchStable()
        // Then
        XCTAssertTrue(isStable)
        // Teardown
        unsetenv("GITHUB_HEAD_REF")
    }
    
    func test_CurrentBranchIsNotStableFromGitHubPullRequest() throws {
        // Given
        setenv("GITHUB_HEAD_REF", "feature-branch", 1)
        // When
        let isStable = try sut.isBranchStable()
        // Then
        XCTAssertFalse(isStable)
        // Teardown
        unsetenv("GITHUB_HEAD_REF")
    }
    
    func test_CurrentBranchIsStableFromGitHubPush() throws {
        // Given
        setenv("GITHUB_REF", "main", 1)
        setenv("GITHUB_REF_TYPE", "branch", 1)
        // When
        let isStable = try sut.isBranchStable()
        // Then
        XCTAssertTrue(isStable)
        // Teardown
        unsetenv("GITHUB_REF")
        unsetenv("GITHUB_REF_TYPE")
    }
    
    func test_CurrentBranchIsNotStableFromGitHubPush() throws {
        // Given
        setenv("GITHUB_REF", "refs/heads/feature-branch", 1)
        setenv("GITHUB_REF_TYPE", "branch", 1)
        // When
        let isStable = try sut.isBranchStable()
        // Then
        XCTAssertFalse(isStable)
        // Teardown
        unsetenv("GITHUB_REF")
        unsetenv("GITHUB_REF_TYPE")
    }
    
    func testLastCommitShaDoesNotThrow() throws {
        XCTAssertNoThrow(try sut.commitSHA())
    }
    
    func testRemoteMergedBranchesNotEmpty() throws {
        let output = try sut.mergedRemoteBranches()
        XCTAssertFalse(output.isEmpty)
    }
    
    func testLastCommitInfoNoThrow() throws {
        XCTAssertNoThrow(try sut.lastCommitInfo(branch: "main"))
    }
    
    func testFetchNoThrow() throws {
        XCTAssertNoThrow(try sut.fetch(all: false, depth: 1))
        XCTAssertNoThrow(try sut.fetch(depth: 1))
        XCTAssertNoThrow(try sut.fetch())
        
        XCTAssertNoThrow(try sut.fetch(all: false, tags: true, depth: 1))
        XCTAssertNoThrow(try sut.fetch(tags: true, depth: 1))
        XCTAssertNoThrow(try sut.fetch(tags: true))
        
        XCTAssertNoThrow(try sut.fetch(tags: true, depth: 0))
    }
    
    func testStaleBranchesNoThrow() throws {
        XCTAssertNoThrow(try sut.staleBranches(daysThreshold: 30))
    }
    
    func testGetTags() throws {
        // Given
        let testTag = "testTag"
        try sut.setTag(testTag)
        // When
        let tags = try sut.getHeadTags()
        // Then
        XCTAssertTrue(tags.contains(testTag))
        // Teardown
        try sut.removeTag(testTag)
    }
    
    func testGetTagsNoThrow() throws {
        XCTAssertNoThrow(try sut.getHeadTags())
    }
    
    func testGetCommits() throws {
        let commits = try sut.getCommits(
            since: .now.advanced(by: -500000),
            until: .now,
            components: Gito.CommitComponent.allCases
        )
        
        XCTAssert(commits.count > 0)
    }
    
    func testChangedLinesCount() throws {
        let changedLines = try sut.getChangedLinesCount(
            since: .now.advanced(by: -500000),
            until: .now
        )
        
        print(changedLines)
        
        XCTAssert(changedLines.count > 0)
        XCTAssert(changedLines.allSatisfy { $0.value > 0 })
    }
}

private extension URL {
    /// Change this to test git tools in a different repo
    static func testDirUrl() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }
}
