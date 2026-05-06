import Foundation
import Testing
import Corredor
@testable import Gito

@Suite
final class CherryPickTests {
    let repo: TempRepo
    let sut: Gito

    init() throws {
        repo = try TempRepo()
        sut = Gito(in: repo.url)
    }

    deinit {
        try? repo.tearDown()
    }

    @Test
    func pick_appliesCleanly() throws {
        let main = try repo.head()
        try repo.git("checkout", "-b", "feature")
        let featureHash = try repo.commitFile(path: "a.txt", content: "x", message: "feature commit")
        try repo.git("checkout", "main")
        #expect(try repo.head() == main)

        let outcome = try sut.cherryPick(hash: featureHash)

        #expect(outcome == .applied)
        #expect(try repo.head() != main)
        let log = try repo.git("log", "-1", "--format=%s")
        #expect(log.contains("feature commit"))
    }

    @Test
    func pick_recordOriginAddsXLine() throws {
        try repo.git("checkout", "-b", "feature")
        let featureHash = try repo.commitFile(path: "a.txt", content: "x", message: "with -x")
        try repo.git("checkout", "main")

        try sut.cherryPick(hash: featureHash, recordOrigin: true)

        let body = try repo.git("log", "-1", "--format=%B")
        #expect(body.contains("(cherry picked from commit"))
    }

    @Test
    func pick_conflict_returnsConflictOutcome() throws {
        try repo.commitFile(path: "shared.txt", content: "main\n", message: "main version")
        let mainTip = try repo.head()
        try repo.git("checkout", "-b", "other", "HEAD~1")
        let otherHash = try repo.commitFile(path: "shared.txt", content: "other\n", message: "other version")
        try repo.git("checkout", "main")
        #expect(try repo.head() == mainTip)

        let outcome = try sut.cherryPick(hash: otherHash)

        guard case .conflict = outcome else {
            Issue.record("expected .conflict, got \(outcome)")
            return
        }
        let cherryPickHead = repo.url.appendingPathComponent(".git/CHERRY_PICK_HEAD")
        #expect(FileManager.default.fileExists(atPath: cherryPickHead.path))
    }

    @Test
    func pick_emptyCommit_returnsEmpty() throws {
        try repo.commitFile(path: "a.txt", content: "shared\n", message: "main writes shared")
        try repo.git("checkout", "-b", "branch", "HEAD~1")
        let dupHash = try repo.commitFile(path: "a.txt", content: "shared\n", message: "branch writes the same")
        try repo.git("checkout", "main")

        let outcome = try sut.cherryPick(hash: dupHash)
        #expect(outcome == .empty)

        try sut.cherryPickSkip()
        #expect(!FileManager.default.fileExists(atPath: repo.url.appendingPathComponent(".git/CHERRY_PICK_HEAD").path))
    }

    @Test
    func skip_clearsConflictedState() throws {
        try repo.commitFile(path: "f.txt", content: "main\n", message: "m")
        try repo.git("checkout", "-b", "b", "HEAD~1")
        let h = try repo.commitFile(path: "f.txt", content: "b\n", message: "b")
        try repo.git("checkout", "main")
        _ = try sut.cherryPick(hash: h)

        try sut.cherryPickSkip()
        #expect(!FileManager.default.fileExists(atPath: repo.url.appendingPathComponent(".git/CHERRY_PICK_HEAD").path))
    }

    @Test
    func abort_restoresWorkingTree() throws {
        try repo.commitFile(path: "f.txt", content: "main\n", message: "m")
        let mainTip = try repo.head()
        try repo.git("checkout", "-b", "b", "HEAD~1")
        let h = try repo.commitFile(path: "f.txt", content: "b\n", message: "b")
        try repo.git("checkout", "main")
        _ = try sut.cherryPick(hash: h)

        try sut.cherryPickAbort()
        #expect(try repo.head() == mainTip)
        let content = try String(contentsOf: repo.url.appendingPathComponent("f.txt"), encoding: .utf8)
        #expect(content == "main\n")
    }

    @Test
    func pick_invalidHash_throws() {
        #expect(throws: ShellRunner.Error.self) {
            try sut.cherryPick(hash: "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef")
        }
    }
}
