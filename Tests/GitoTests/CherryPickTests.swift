import Foundation
import XCTest
import Corredor
@testable import Gito

final class CherryPickTests: XCTestCase {
    var repo: TempRepo!
    var sut: Gito!

    override func setUpWithError() throws {
        repo = try TempRepo()
        sut = Gito(in: repo.url)
    }

    override func tearDownWithError() throws {
        try repo.tearDown()
    }

    func test_pick_appliesCleanly() throws {
        let main = try repo.head()
        try repo.git("checkout", "-b", "feature")
        let featureHash = try repo.commitFile(path: "a.txt", content: "x", message: "feature commit")
        try repo.git("checkout", "main")
        XCTAssertEqual(try repo.head(), main)

        let outcome = try sut.cherryPick(hash: featureHash)

        XCTAssertEqual(outcome, .applied)
        XCTAssertNotEqual(try repo.head(), main)
        let log = try repo.git("log", "-1", "--format=%s")
        XCTAssertTrue(log.contains("feature commit"))
    }

    func test_pick_recordOriginAddsXLine() throws {
        try repo.git("checkout", "-b", "feature")
        let featureHash = try repo.commitFile(path: "a.txt", content: "x", message: "with -x")
        try repo.git("checkout", "main")

        try sut.cherryPick(hash: featureHash, recordOrigin: true)

        let body = try repo.git("log", "-1", "--format=%B")
        XCTAssertTrue(body.contains("(cherry picked from commit"))
    }

    func test_pick_conflict_returnsConflictOutcome() throws {
        try repo.commitFile(path: "shared.txt", content: "main\n", message: "main version")
        let mainTip = try repo.head()
        try repo.git("checkout", "-b", "other", "HEAD~1")
        let otherHash = try repo.commitFile(path: "shared.txt", content: "other\n", message: "other version")
        try repo.git("checkout", "main")
        XCTAssertEqual(try repo.head(), mainTip)

        let outcome = try sut.cherryPick(hash: otherHash)

        guard case .conflict = outcome else {
            return XCTFail("expected .conflict, got \(outcome)")
        }
        let cherryPickHead = repo.url.appendingPathComponent(".git/CHERRY_PICK_HEAD")
        XCTAssertTrue(FileManager.default.fileExists(atPath: cherryPickHead.path))
    }

    func test_pick_emptyCommit_returnsEmpty() throws {
        try repo.commitFile(path: "a.txt", content: "shared\n", message: "main writes shared")
        try repo.git("checkout", "-b", "branch", "HEAD~1")
        let dupHash = try repo.commitFile(path: "a.txt", content: "shared\n", message: "branch writes the same")
        try repo.git("checkout", "main")

        let outcome = try sut.cherryPick(hash: dupHash)
        XCTAssertEqual(outcome, .empty)

        try sut.cherryPickSkip()
        XCTAssertFalse(FileManager.default.fileExists(atPath: repo.url.appendingPathComponent(".git/CHERRY_PICK_HEAD").path))
    }

    func test_skip_clearsConflictedState() throws {
        try repo.commitFile(path: "f.txt", content: "main\n", message: "m")
        try repo.git("checkout", "-b", "b", "HEAD~1")
        let h = try repo.commitFile(path: "f.txt", content: "b\n", message: "b")
        try repo.git("checkout", "main")
        _ = try sut.cherryPick(hash: h)

        try sut.cherryPickSkip()
        XCTAssertFalse(FileManager.default.fileExists(atPath: repo.url.appendingPathComponent(".git/CHERRY_PICK_HEAD").path))
    }

    func test_abort_restoresWorkingTree() throws {
        try repo.commitFile(path: "f.txt", content: "main\n", message: "m")
        let mainTip = try repo.head()
        try repo.git("checkout", "-b", "b", "HEAD~1")
        let h = try repo.commitFile(path: "f.txt", content: "b\n", message: "b")
        try repo.git("checkout", "main")
        _ = try sut.cherryPick(hash: h)

        try sut.cherryPickAbort()
        XCTAssertEqual(try repo.head(), mainTip)
        let content = try String(contentsOf: repo.url.appendingPathComponent("f.txt"))
        XCTAssertEqual(content, "main\n")
    }

    func test_pick_invalidHash_throws() throws {
        XCTAssertThrowsError(try sut.cherryPick(hash: "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef")) { error in
            guard case ShellRunner.Error.commandFailed = error else {
                return XCTFail("expected ShellRunner.Error.commandFailed, got \(error)")
            }
        }
    }
}
