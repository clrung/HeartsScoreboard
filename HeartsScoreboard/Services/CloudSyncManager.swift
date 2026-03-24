import Foundation

/// State that is synced via iCloud key-value storage.
///
/// Note: Appearance preference is intentionally NOT synced. Only game-related
/// settings (ending score, shoot-moon behavior) are shared across devices.
struct SyncableState: Codable {
    var game: HeartsGame
    var settings: GameSettings
    var firstDealerIndex: Int
    var history: [CompletedGame]

    init(
        game: HeartsGame,
        settings: GameSettings,
        firstDealerIndex: Int,
        history: [CompletedGame] = []
    ) {
        self.game = game
        self.settings = settings
        self.firstDealerIndex = firstDealerIndex
        self.history = history
    }

    private struct SyncedSettings: Codable {
        var endingScore: Int
        var shootMoonPreference: ShootMoonPreference
        var quickIncrementPoints: Int?
    }

    private enum CodingKeys: String, CodingKey {
        case game
        case settings
        case firstDealerIndex
        case history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        game = try container.decode(HeartsGame.self, forKey: .game)
        firstDealerIndex = try container.decode(Int.self, forKey: .firstDealerIndex)
        history = try container.decodeIfPresent([CompletedGame].self, forKey: .history) ?? []

        // Support both new compact settings payload and legacy full GameSettings.
        if let synced = try? container.decode(SyncedSettings.self, forKey: .settings) {
            settings = GameSettings(
                endingScore: synced.endingScore,
                shootMoonPreference: synced.shootMoonPreference,
                appearance: .system,
                quickIncrementPoints: synced.quickIncrementPoints ?? 5
            )
        } else {
            let legacy = try container.decode(GameSettings.self, forKey: .settings)
            settings = GameSettings(
                endingScore: legacy.endingScore,
                shootMoonPreference: legacy.shootMoonPreference,
                appearance: .system,
                quickIncrementPoints: legacy.quickIncrementPoints
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(game, forKey: .game)
        let synced = SyncedSettings(
            endingScore: settings.endingScore,
            shootMoonPreference: settings.shootMoonPreference,
            quickIncrementPoints: settings.quickIncrementPoints
        )
        try container.encode(synced, forKey: .settings)
        try container.encode(firstDealerIndex, forKey: .firstDealerIndex)
        try container.encode(history, forKey: .history)
    }
}

/// Syncs game state to iCloud so it’s available on all devices signed into the same iCloud account.
final class CloudSyncManager {
    static let shared = CloudSyncManager()

    private let store = NSUbiquitousKeyValueStore.default
    private let key = "heartsGameState"

    /// Called when state is updated from another device. Set this to apply the new state to your view model.
    var onSyncFromCloud: ((SyncableState) -> Void)?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquitousKeyValueStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Loads the last synced state, if any.
    func load() -> SyncableState? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SyncableState.self, from: data)
    }

    /// Saves the given state to iCloud key-value store (and triggers sync to other devices).
    func save(_ state: SyncableState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        store.set(data, forKey: key)
        store.synchronize()
    }

    @objc private func ubiquitousKeyValueStoreDidChange(_ notification: Notification) {
        guard let state = load() else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onSyncFromCloud?(state)
        }
    }
}
