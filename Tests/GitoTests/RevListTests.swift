import Foundation
import XCTest
import Corredor
@testable import Gito

final class RevListTests: XCTestCase {
    var repo: TempRepo!
    var sut: Gito!

    override func setUpWithError() throws {
        repo = try TempRepo()
        sut = Gito(in: repo.url)
    }

    override func tearDownWithError() throws {
        try repo.tearDown()
    }

    func test_revList_listsCommitsInRange() throws {
        let base = try repo.head()
        let c1 = try repo.commitFile(path: "1.txt", content: "1", message: "first")
        let c2 = try repo.commitFile(path: "2.txt", content: "2", message: "second")

        let output = try sut.revList(range: "\(base)..HEAD")
        let hashes = output.split(separator: "\n").map { String($0) }
        XCTAssertEqual(hashes, [c2, c1]) // newest first by default
    }

    func test_revList_reverseGivesOldestFirst() throws {
        let base = try repo.head()
        let c1 = try repo.commitFile(path: "1.txt", content: "1", message: "first")
        let c2 = try repo.commitFile(path: "2.txt", content: "2", message: "second")

        let output = try sut.revList(range: "\(base)..HEAD", reverse: true)
        let hashes = output.split(separator: "\n").map { String($0) }
        XCTAssertEqual(hashes, [c1, c2])
    }

    func test_revList_customFormatRoundTrips() throws {
        let base = try repo.head()
        let hash = try repo.commitFile(path: "f.txt", content: "f", message: "subject here")

        let output = try sut.revList(range: "\(base)..HEAD", format: "%H|%s")
        XCTAssertTrue(output.contains("\(hash)|subject here"))
    }

    func test_revList_invalidRange_throws() throws {
        XCTAssertThrowsError(try sut.revList(range: "bogus..HEAD")) { error in
            guard case ShellRunner.Error.commandFailed = error else {
                return XCTFail("expected ShellRunner.Error.commandFailed, got \(error)")
            }
        }
    }
}
