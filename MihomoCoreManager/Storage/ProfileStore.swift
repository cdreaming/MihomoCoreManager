import Foundation

struct ProfileStore {
    private var applicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private var fileURL: URL {
        applicationSupport
            .appendingPathComponent("MihomoManager", isDirectory: true)
            .appendingPathComponent("profiles.json", isDirectory: false)
    }

    private var legacyFileURL: URL {
        applicationSupport
            .appendingPathComponent("MihomoCoreManager", isDirectory: true)
            .appendingPathComponent("profiles.json", isDirectory: false)
    }

    func load() -> [ServerProfile] {
        for candidate in [fileURL, legacyFileURL] {
            do {
                let data = try Data(contentsOf: candidate)
                let profiles = try JSONDecoder().decode([ServerProfile].self, from: data)
                if candidate == legacyFileURL, !profiles.isEmpty {
                    try? save(profiles)
                }
                return profiles
            } catch {
                continue
            }
        }
        return []
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
