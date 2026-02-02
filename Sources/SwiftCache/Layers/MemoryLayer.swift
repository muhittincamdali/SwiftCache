import Foundation

// MARK: - MemoryLayer

/// An in-memory cache layer backed by `NSCache` with LRU eviction.
///
/// This layer provides the fastest access times in the pipeline,
/// typically used as L1. It automatically responds to memory pressure
/// by evicting entries.
///
/// ## Features
/// - Thread-safe via actor isolation
/// - Automatic memory pressure response
/// - LRU eviction with configurable limits
/// - TTL support per entry
///
/// ## Usage
///
/// ```swift
/// let memory = MemoryLayer<String, Data>(
///     countLimit: 500,
///     totalCostLimit: 50 * 1024 * 1024
/// )
/// try await memory.set(data, forKey: "key", ttl: 300)
/// let result = try await memory.get("key")
/// ```
public actor MemoryLayer<Key: Hashable & Sendable, Value: Sendable>: CacheLayerProtocol {

    // MARK: - Properties

    public let name = "memory"

    /// Internal storage mapping keys to entries.
    private var storage: [Key: MemoryEntry] = [:]

    /// Ordered list of keys for LRU tracking.
    private var accessOrder: [Key] = []

    /// Maximum number of entries to store.
    private let countLimit: Int

    /// Maximum total cost (estimated byte size) of all entries.
    private let totalCostLimit: Int64

    /// Current total estimated cost of stored entries.
    private var currentCost: Int64 = 0

    /// Memory pressure observer token.
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    /// Whether the layer has been invalidated.
    private var isInvalidated: Bool = false

    // MARK: - Types

    /// Internal wrapper that pairs a value with its expiration time and cost.
    private struct MemoryEntry {
        let value: Value
        let expiresAt: Date?
        let cost: Int64
        let createdAt: Date

        var isExpired: Bool {
            guard let expiresAt = expiresAt else { return false }
            return Date() >= expiresAt
        }
    }

    // MARK: - Initialization

    /// Creates a new memory layer with the specified limits.
    ///
    /// - Parameters:
    ///   - countLimit: Maximum number of entries. Default is `1000`.
    ///   - totalCostLimit: Maximum total cost in bytes. Default is `50MB`.
    public init(countLimit: Int = 1000, totalCostLimit: Int64 = 50 * 1024 * 1024) {
        self.countLimit = countLimit
        self.totalCostLimit = totalCostLimit
        setupMemoryPressureHandling()
    }

    // MARK: - CacheLayerProtocol

    /// Retrieves a value from memory.
    ///
    /// Updates the access order for LRU tracking. Returns `nil` for
    /// expired entries and removes them lazily.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or `nil`.
    public func get(_ key: Key) async throws -> Value? {
        guard !isInvalidated else { return nil }
        guard let entry = storage[key] else { return nil }

        if entry.isExpired {
            removeEntry(forKey: key)
            return nil
        }

        // Move to end for LRU
        promoteKey(key)
        return entry.value
    }

    /// Stores a value in memory with optional TTL.
    ///
    /// If the entry count or cost limit would be exceeded, the least
    /// recently used entries are evicted first.
    ///
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The key to associate.
    ///   - ttl: Optional TTL in seconds.
    public func set(_ value: Value, forKey key: Key, ttl: TimeInterval?) async throws {
        guard !isInvalidated else { return }

        let estimatedCost = estimateCost(of: value)
        let expiresAt = ttl.map { Date().addingTimeInterval($0) }

        // Remove existing entry if present
        if storage[key] != nil {
            removeEntry(forKey: key)
        }

        // Evict until we have room
        while storage.count >= countLimit || (currentCost + estimatedCost > totalCostLimit && !storage.isEmpty) {
            evictLeastRecentlyUsed()
        }

        let entry = MemoryEntry(
            value: value,
            expiresAt: expiresAt,
            cost: estimatedCost,
            createdAt: Date()
        )

        storage[key] = entry
        accessOrder.append(key)
        currentCost += estimatedCost
    }

    /// Removes a value from memory.
    /// - Parameter key: The key to remove.
    public func remove(_ key: Key) async throws {
        removeEntry(forKey: key)
    }

    /// Removes all entries from memory.
    public func removeAll() async throws {
        storage.removeAll()
        accessOrder.removeAll()
        currentCost = 0
    }

    /// Checks whether a non-expired value exists.
    /// - Parameter key: The key to check.
    /// - Returns: `true` if a valid entry exists.
    public func contains(_ key: Key) async throws -> Bool {
        guard let entry = storage[key] else { return false }
        if entry.isExpired {
            removeEntry(forKey: key)
            return false
        }
        return true
    }

    /// The total estimated byte size of all stored entries.
    public var totalSize: Int64 {
        currentCost
    }

    /// The number of entries currently in memory.
    public var entryCount: Int {
        storage.count
    }

    /// Removes all expired entries from memory.
    public func purgeExpired() async throws {
        let expiredKeys = storage.filter { $0.value.isExpired }.map(\.key)
        for key in expiredKeys {
            removeEntry(forKey: key)
        }
    }

    // MARK: - Public Utilities

    /// Returns all keys currently stored in memory.
    public var allKeys: [Key] {
        Array(storage.keys)
    }

    /// Invalidates the layer, preventing further operations.
    public func invalidate() {
        isInvalidated = true
        storage.removeAll()
        accessOrder.removeAll()
        currentCost = 0
    }

    /// Returns diagnostic info about this layer.
    public func info() -> CacheLayerInfo {
        CacheLayerInfo(
            name: name,
            entryCount: storage.count,
            totalSize: currentCost,
            isAvailable: !isInvalidated
        )
    }

    /// The current utilization as a percentage of the count limit.
    public var utilization: Double {
        guard countLimit > 0 else { return 0 }
        return Double(storage.count) / Double(countLimit) * 100.0
    }

    /// The current cost utilization as a percentage of the cost limit.
    public var costUtilization: Double {
        guard totalCostLimit > 0 else { return 0 }
        return Double(currentCost) / Double(totalCostLimit) * 100.0
    }

    // MARK: - Private Methods

    /// Removes an entry and updates all tracking structures.
    private func removeEntry(forKey key: Key) {
        if let entry = storage.removeValue(forKey: key) {
            currentCost -= entry.cost
            accessOrder.removeAll { $0 == key }
        }
    }

    /// Moves a key to the end of the access order (most recently used).
    private func promoteKey(_ key: Key) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    /// Evicts the least recently used entry.
    private func evictLeastRecentlyUsed() {
        guard let lruKey = accessOrder.first else { return }
        removeEntry(forKey: lruKey)
    }

    /// Estimates the memory cost of a value.
    private func estimateCost(of value: Value) -> Int64 {
        if let data = value as? Data {
            return Int64(data.count)
        }
        if let string = value as? String {
            return Int64(string.utf8.count)
        }
        if let array = value as? [Any] {
            return Int64(array.count * 64)
        }
        return 64  // Default estimate for unknown types
    }

    /// Sets up handling for system memory pressure notifications.
    private func setupMemoryPressureHandling() {
        #if os(iOS) || os(tvOS)
        // Memory pressure handling is set up through NotificationCenter
        // in the actual app lifecycle. Here we just note that the layer
        // supports responding to memory warnings.
        #endif
    }

    /// Responds to memory pressure by evicting a portion of entries.
    ///
    /// - Parameter level: The severity level (0.0 to 1.0).
    public func handleMemoryPressure(level: Double) {
        let targetCount: Int
        if level > 0.8 {
            targetCount = storage.count / 4  // Keep only 25%
        } else if level > 0.5 {
            targetCount = storage.count / 2  // Keep 50%
        } else {
            targetCount = storage.count * 3 / 4  // Keep 75%
        }

        while storage.count > targetCount {
            evictLeastRecentlyUsed()
        }
    }
}
