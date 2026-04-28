import Foundation
import XCTest
import Corredor
@testable import Gito

final class MergeBaseTests: XCTestCase {
    var repo: TempRepo!
    var sut: Gito!

    override func setUpWithError() throws {
        repo = try TempRepo()
        sut = Gito(in: repo.url)
    }

    override func tearDownWithError() throws {
        try repo.tearDown()
    }

    func test_mergeBase_returnsForkPoint() throws {
        let base = try repo.head()
        try repo.git("checkout", "-b", "a")
        try repo.commitFile(path: "a.txt", content: "a", message: "a1")
        let aTip = try repo.head()
        try repo.git("checkout", "-b", "b", base)
        try repo.commitFile(path: "b.txt", content: "b", message: "b1")
        let bTip = try repo.head()

        let result = try sut.mergeBase(aTip, bTip)
        XCTAssertEqual(result, base)
    }

    func test_mergeBase_unrelatedHistories_returnsNil() throws {
        // Establish a real commit on main first so the orphan branch has
        // something to diverge from (empty-tree merge-base behaviour varies).
        try repo.commitFile(path: "main.txt", content: "m\n", message: "main commit")
        let main = try repo.head()

        try repo.git("checkout", "--orphan", "alien")
        try repo.git("rm", "-rf", "--cached", ".")
        try "alien\n".write(to: repo.url.appendingPathComponent("alien.txt"), atomically: true, encoding: .utf8)
        try repo.git("add", "alien.txt")
        try repo.git("commit", "-m", "alien root")
        let alien = try repo.head()

        let result = try sut.mergeBase(alien, main)
        XCTAssertNil(result)
    }

    func test_mergeBase_invalidRef_throws() throws {
        XCTAssertThrowsError(try sut.mergeBase("nope", "HEAD")) { error in
            guard case ShellRunner.Error.commandFailed = error else {
                return XCTFail("expected ShellRunner.Error.commandFailed, got \(error)")
            }
        }
    }

    func test_isAncestor_trueForReachable() throws {
        let base = try repo.head()
        try repo.commitFile(path: "x.txt", content: "x", message: "x1")
        let result = try sut.isAncestor(base, of: "HEAD")
        XCTAssertTrue(result)
    }

    func test_isAncestor_falseForUnreachable() throws {
        let base = try repo.head()
        try repo.git("checkout", "-b", "side")
        let sideTip = try repo.commitFile(path: "s.txt", content: "s", message: "s1")
        try repo.git("checkout", "main")
        _ = base

        let result = try sut.isAncestor(sideTip, of: "main")
        XCTAssertFalse(result)
    }

    func test_isAncestor_invalidRef_throws() throws {
        XCTAssertThrowsError(try sut.isAncestor("HEAD", of: "no-such-branch")) { error in
            guard case ShellRunner.Error.commandFailed = error else {
                return XCTFail("expected ShellRunner.Error.commandFailed, got \(error)")
            }
        }
    }
}
