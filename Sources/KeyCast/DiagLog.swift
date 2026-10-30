import Foundation

enum DiagLog {
    static var url: URL {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return lib.appendingPathComponent("Logs").appendingPathComponent("KeyCast.log")
    }

    static func log(_ msg: String) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let line = "[" + f.string(from: Date()) + "] " + msg + "\n"
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                let h = try FileHandle(forWritingTo: url)
                h.seekToEndOfFile()
                h.write(line.data(using: .utf8)!)
                try h.close()
            } else {
                try line.data(using: .utf8)!.write(to: url)
            }
        } catch {
            // ignore logging errors
        }
    }
}
