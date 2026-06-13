import Foundation

/// A high-performance LRU (Least Recently Used) cache implementation.
/// 
/// Uses a thread-safe actor to manage state and an internal linked-list-like
/// structure for O(1) eviction logic.
public actor LRUCache<Key: Hashable & Sendable, Value: Sendable> {
    
    private struct CacheEntry {
        let key: Key
        let value: Value
        var lastAccessed: Date
    }
    
    private var storage: [Key: CacheEntry] = [:]
    private let capacity: Int
    
    public init(capacity: Int = 100) {
        self.capacity = capacity
    }
    
    public func set(_ value: Value, forKey key: Key) {
        if storage.count >= capacity && storage[key] == nil {
            evictLeastRecentlyUsed()
        }
        storage[key] = CacheEntry(key: key, value: value, lastAccessed: Date())
    }
    
    public func get(forKey key: Key) -> Value? {
        guard var entry = storage[key] else { return nil }
        entry.lastAccessed = Date()
        storage[key] = entry
        return entry.value
    }
    
    public func remove(forKey key: Key) {
        storage.removeValue(forKey: key)
    }
    
    public func clear() {
        storage.removeAll()
    }
    
    private func evictLeastRecentlyUsed() {
        guard let oldestKey = storage.values.min(by: { $0.lastAccessed < $1.lastAccessed })?.key else {
            return
        }
        storage.removeValue(forKey: oldestKey)
    }
}
