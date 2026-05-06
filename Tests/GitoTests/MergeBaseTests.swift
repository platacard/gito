import Foundation
import Testing
import Corredor
@testable import Gito

@Suite
final class MergeBaseTests {
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
    func mergeBase_returnsForkPoint() throws {
        let base = try repo.head()
        try repo.git("checkout", "-b", "a")
        try repo.commitFile(path: "a.txt", content: "a", message: "a1")
        let aTip = try repo.head()
        try repo.git("checkout", "-b", "b", base)
        try repo.commitFile(path: "b.txt", content: "b", message: "b1")
        let bTip = try repo.head()

        let result = try sut.mergeBase(aTip, bTip)
        #expect(result == base)
    }

    @Test
    func mergeBase_unrelatedHistories_returnsNil() throws {
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
        #expect(result == nil)
    }

    @Test
    func mergeBase_invalidRef_throws() {
        #expect(throws: ShellRunner.Error.self) {
            try sut.mergeBase("nope", "HEAD")
        }
    }

    @Test
    func isAncestor_trueForReachable() throws {
        let base = try repo.head()
        try repo.commitFile(path: "x.txt", content: "x", message: "x1")
        let result = try sut.isAncestor(base, of: "HEAD")
        #expect(result)
    }

    @Test
    func isAncestor_falseForUnreachable() throws {
        let base = try repo.head()
        try repo.git("checkout", "-b", "side")
        let sideTip = try repo.commitFile(path: "s.txt", content: "s", message: "s1")
        try repo.git("checkout", "main")
        _ = base

        let result = try sut.isAncestor(sideTip, of: "main")
        #expect(!result)
    }

    @Test
    func isAncestor_invalidRef_throws() {
        #expect(throws: ShellRunner.Error.self) {
            try sut.isAncestor("HEAD", of: "no-such-branch")
        }
    }
}
