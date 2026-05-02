import Foundation

enum Persistence {
    private static let appFolder = "Pulse"
    private static let legacyAppFolder = "SpeedTester"
    private static let historyFile = "history.json"
    private static let settingsFile = "settings.json"
    private static let outagesFile = "outages.json"
    private static let speedFile = "speed.json"
    private static let maxRetentionDays: TimeInterval = 7

    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent(appFolder, isDirectory: true)
        let legacy = base.appendingPathComponent(legacyAppFolder, isDirectory: true)
        // One-time migration: move legacy contents into Pulse/ if needed
        if !FileManager.default.fileExists(atPath: folder.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: folder)
        }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static var folderURL: URL { dir }

    private static func url(_ name: String) -> URL { dir.appendingPathComponent(name) }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Settings

    static func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: url(settingsFile)),
              let s = try? decoder.decode(AppSettings.self, from: data) else {
            return AppSettings.defaults
        }
        return s
    }

    static func saveSettings(_ s: AppSettings) {
        guard let data = try? encoder.encode(s) else { return }
        try? data.write(to: url(settingsFile), options: .atomic)
    }

    // MARK: - History

    static func loadPings() -> [PingSample] {
        load([PingSample].self, from: historyFile) ?? []
    }
    static func savePings(_ samples: [PingSample]) {
        let trimmed = trimByAge(samples) { $0.timestamp }
        save(trimmed, to: historyFile)
    }

    static func loadSpeeds() -> [SpeedSample] {
        load([SpeedSample].self, from: speedFile) ?? []
    }
    static func saveSpeeds(_ samples: [SpeedSample]) {
        let trimmed = trimByAge(samples) { $0.timestamp }
        save(trimmed, to: speedFile)
    }

    static func loadOutages() -> [OutageEvent] {
        load([OutageEvent].self, from: outagesFile) ?? []
    }
    static func saveOutages(_ events: [OutageEvent]) {
        let trimmed = trimByAge(events) { $0.start }
        save(trimmed, to: outagesFile)
    }

    private static func trimByAge<T>(_ items: [T], _ getDate: (T) -> Date) -> [T] {
        let cutoff = Date().addingTimeInterval(-maxRetentionDays * 86_400)
        return items.filter { getDate($0) >= cutoff }
    }

    private static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, to name: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(name), options: .atomic)
    }
}
