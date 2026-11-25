import Foundation
import Testing
@testable import Gito

@Suite
final class WorkingTreeTests {
    let repo: TempRepo
    let sut: Gito

    init() throws {
        repo = try TempRepo()
        sut = Gito(in: repo.url)
    }

    deinit {
        try? repo.tearDown()
    }

    private func write(_ path: String, _ content: String = "x") throws {
        let url = repo.url.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test
    func topLevel_isTheRepoRootFromASubfolder() throws {
        try write("Sub/file.txt")

        let topLevel = Gito(in: repo.url.appending(path: "Sub")).topLevel()

        // git prints the real path: /private/var/… for /var/…, which resolvingSymlinksInPath keeps.
        let root = try #require(realpath(repo.url.path(percentEncoded: false), nil))
        defer { free(root) }
        #expect(topLevel == String(cString: root))
    }

    @Test
    func topLevel_isNilOutsideARepo() throws {
        let outside = FileManager.default.temporaryDirectory.appending(path: "gito-outside-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }

        #expect(Gito(in: outside).topLevel() == nil)
    }

    @Test
    func containsCommit() throws {
        #expect(sut.containsCommit(try repo.head()))
        #expect(sut.containsCommit("HEAD"))
        #expect(!sut.containsCommit("0000000000000000000000000000000000000000"))
    }

    @Test
    func files_keepSpacesAndNonASCIIVerbatim() throws {
        try write("Tracked dir/a b.txt")
        try repo.git("add", ".")
        try repo.git("commit", "-m", "tracked")
        try write("Ünïcode \"quoted\".txt")

        #expect(try sut.trackedFiles() == ["Tracked dir/a b.txt"])
        #expect(try sut.untrackedFiles() == ["Ünïcode \"quoted\".txt"])
        // git lists the index first or not: no order is promised.
        #expect(Set(try sut.listedFiles()) == ["Tracked dir/a b.txt", "Ünïcode \"quoted\".txt"])
    }

    @Test
    func changedFiles_includeEditsDeletionsAndBothSidesOfARename() throws {
        let base = try repo.commitFile(path: "edited.txt", content: "1", message: "edited")
        try repo.commitFile(path: "deleted.txt", content: "1", message: "deleted")
        try repo.commitFile(path: "old.txt", content: "same", message: "old")
        let start = try repo.head()

        try write("edited.txt", "2")
        try FileManager.default.removeItem(at: repo.url.appending(path: "deleted.txt"))
        try repo.git("mv", "old.txt", "new.txt")

        #expect(Set(try sut.changedFiles(since: start)) == ["edited.txt", "deleted.txt", "old.txt", "new.txt"])
        #expect(Set(try sut.changedFiles(since: base)) == ["edited.txt", "new.txt"])
    }

    @Test
    func under_limitsToLiteralPaths() throws {
        try write("a/one.txt")
        try write("[a]/two.txt")
        try write("ab/three.txt")
        try write("top.txt")

        #expect(try sut.untrackedFiles(under: ["[a]"]) == ["[a]/two.txt"])
        #expect(try sut.untrackedFiles(under: ["a", "top.txt"]) == ["a/one.txt", "top.txt"])

        try repo.git("add", ".")
        try repo.git("commit", "-m", "all")
        let start = try repo.head()
        try write("a/one.txt", "changed")
        try write("ab/three.txt", "changed")

        #expect(try sut.changedFiles(since: start, under: ["a"]) == ["a/one.txt"])
        #expect(try sut.trackedFiles(under: ["[a]"]) == ["[a]/two.txt"])
        #expect(try sut.listedFiles(under: ["ab"]) == ["ab/three.txt"])
    }

    @Test
    func ignoredFolders_areListedWithoutTheirContents() throws {
        try write(".gitignore", "build/\n*.log\n")
        try write("build/out/file.o")
        try write("debug.log")
        try write("kept.txt")

        #expect(try sut.ignoredFolders() == ["build"])
        #expect(try sut.untrackedFiles() == [".gitignore", "kept.txt"])
    }

    @Test
    func indexFile_isRewrittenByAdd() throws {
        let index = try #require(sut.indexFile())
        let before = try FileManager.default.attributesOfItem(atPath: index.path())[.modificationDate] as? Date

        Thread.sleep(forTimeInterval: 0.01)
        try write("new.txt")
        try repo.git("add", "new.txt")

        let after = try FileManager.default.attributesOfItem(atPath: index.path())[.modificationDate] as? Date
        #expect(index.lastPathComponent == "index")
        #expect(after != before)
    }
}
