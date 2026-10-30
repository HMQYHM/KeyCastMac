import Foundation

enum ConfigStore {
    static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("KeyCast").appendingPathComponent("config.json")
    }

    static func migrateIfNeeded() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let fm = FileManager.default
        let oldDir = base.appendingPathComponent("PA Keystroke")
        let newDir = base.appendingPathComponent("KeyCast")
        if fm.fileExists(atPath: oldDir.path) && !fm.fileExists(atPath: newDir.path) {
            try? fm.moveItem(at: oldDir, to: newDir)
        }
    }

    static func load() -> Config {
        if let data = try? Data(contentsOf: url),
           let c = try? JSONDecoder().decode(Config.self, from: data) {
            return c.sanitized()
        }
        return Config()
    }

    static func save(_ c: Config) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(c)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("KeyCast save failed: %@", String(describing: error))
        }
    }
}

enum ProfileStore {
    static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("KeyCast").appendingPathComponent("profiles.json")
    }

    static func load() -> [String: Config] {
        guard let data = try? Data(contentsOf: url),
              let d = try? JSONDecoder().decode([String: Config].self, from: data) else { return [:] }
        return d.mapValues { $0.sanitized() }
    }

    static func save(_ dict: [String: Config]) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(dict)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("KeyCast profile save failed: %@", String(describing: error))
        }
    }
}
