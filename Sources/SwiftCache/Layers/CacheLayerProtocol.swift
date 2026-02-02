import Foundation

// MARK: - CacheLayerProtocol

/// Defines the interface for a single layer in the cache pipeline.
///
/// Each layer represents a storage tier (memory, disk, network, etc.)
/// that can be composed into a multi-layer pipeline. Layers are checked
/// in order, with faster layers typically placed first.
///
/// ## Implementing a Custom Layer
///
/// ```swift
/// actor MyCustomLayer: CacheLayerProtocol {
///     typealias Key = String
///     typealias Value = Data
///
///     let name = "custom"
///
///     func get(_ key: String) async throws -> Data? { ... }
///     func set(_ value: Data, forKey key: String, ttl: TimeInterval?) async throws { ... }
///     func remove(_ key: String) async throws { ... }
///     func removeAll() async throws { ... }
///     func contains(_ key: String) async throws -> Bool { ... }
///     var totalSize: Int64 { get async { ... } }
///     var entryCount: Int { get async { ... } }
/// }
/// ```
public protocol CacheLayerProtocol: Actor {
    /// The key type for this layer.
    associatedtype Key: Hashable & Sendable
    /// The value type stored in this layer.
    associatedtype Value: Sendable

    /// A human-readable name for this layer (e.g., "memory", "disk").
    var name: String { get }

    /// Retrieves a value for the given key.
    /// - Parameter key: The key to look up.
    /// - Returns: The stored value, or `nil` if not found.
    func get(_ key: Key) async throws -> Value?

    /// Stores a value for the given key with an optional TTL.
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The key to associate.
    ///   - ttl: Optional TTL in seconds.
    func set(_ value: Value, forKey key: Key, ttl: TimeInterval?) async throws

    /// Removes the value for the given key.
    /// - Parameter key: The key to remove.
    func remove(_ key: Key) async throws

    /// Removes all values from this layer.
    func removeAll() async throws

    /// Checks if a value exists for the given key.
    /// - Parameter key: The key to check.
    /// - Returns: `true` if a value exists.
    func contains(_ key: Key) async throws -> Bool

    /// The total size of data stored in this layer, in bytes.
    var totalSize: Int64 { get async }

    /// The number of entries stored in this layer.
    var entryCount: Int { get async }

    /// Removes all expired entries from this layer.
    func purgeExpired() async throws
}

// MARK: - Default Implementation

extension CacheLayerProtocol {
    /// Default implementation that checks for existence by attempting a get.
    public func contains(_ key: Key) async throws -> Bool {
        try await get(key) != nil
    }

    /// Default purge implementation (no-op for layers without TTL tracking).
    public func purgeExpired() async throws {
        // Override in layers that track expiration
    }
}

// MARK: - CacheLayerInfo

/// Diagnostic information about a cache layer.
public struct CacheLayerInfo: Sendable {
    /// The layer name.
    public let name: String

    /// The number of stored entries.
    public let entryCount: Int

    /// The total size in bytes.
    public let totalSize: Int64

    /// Whether the layer is currently available.
    public let isAvailable: Bool

    /// Creates layer diagnostic info.
    public init(name: String, entryCount: Int, totalSize: Int64, isAvailable: Bool) {
        self.name = name
        self.entryCount = entryCount
        self.totalSize = totalSize
        self.isAvailable = isAvailable
    }
}
