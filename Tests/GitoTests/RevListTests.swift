import Foundation
import Testing
import Corredor
@testable import Gito

@Suite
final class RevListTests {
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
    func revList_listsCommitsInRange() throws {
        let base = try repo.head()
        let c1 = try repo.commitFile(path: "1.txt", content: "1", message: "first")
        let c2 = try repo.commitFile(path: "2.txt", content: "2", message: "second")

        let output = try sut.revList(range: "\(base)..HEAD")
        let hashes = output.split(separator: "\n").map { String($0) }
        #expect(hashes == [c2, c1]) // newest first by default
    }

    @Test
    func revList_reverseGivesOldestFirst() throws {
        let base = try repo.head()
        let c1 = try repo.commitFile(path: "1.txt", content: "1", message: "first")
        let c2 = try repo.commitFile(path: "2.txt", content: "2", message: "second")

        let output = try sut.revList(range: "\(base)..HEAD", reverse: true)
        let hashes = output.split(separator: "\n").map { String($0) }
        #expect(hashes == [c1, c2])
    }

    @Test
    func revList_customFormatRoundTrips() throws {
        let base = try repo.head()
        let hash = try repo.commitFile(path: "f.txt", content: "f", message: "subject here")

        let output = try sut.revList(range: "\(base)..HEAD", format: "%H|%s")
        #expect(output.contains("\(hash)|subject here"))
    }

    @Test
    func revList_invalidRange_throws() {
        #expect(throws: ShellRunner.Error.self) {
            try sut.revList(range: "bogus..HEAD")
        }
    }
}
