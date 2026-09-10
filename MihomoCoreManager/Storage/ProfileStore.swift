import Foundation

struct ProfileStore {
    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("MihomoCoreManager", isDirectory: true)
            .appendingPathComponent("profiles.json", isDirectory: false)
    }

    func load() -> [ServerProfile] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([ServerProfile].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ profiles: [ServerProfile]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profiles)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
