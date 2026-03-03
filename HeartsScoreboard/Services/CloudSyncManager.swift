import Foundation

/// State that is synced via iCloud key-value storage.
struct SyncableState: Codable {
    var game: HeartsGame
    var settings: GameSettings
    var firstDealerIndex: Int
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
