import Foundation
import Corredor

public extension Gito {
    func revList(range: String, reverse: Bool = false, format: String? = nil) throws -> String {
        var parts = ["git rev-list"]
        if reverse { parts.append("--reverse") }
        parts.append(range)
        if let format { parts.append("--format='\(format)'") }
        return try Shell.command(parts.joined(separator: " "), in: folder).run()
    }
}
