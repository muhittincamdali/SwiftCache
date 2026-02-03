// Cache.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Cache Protocol

/// A protocol defining the fundamental caching operations.
///
/// The `CacheProtocol` defines a standard interface for cache implementations,
/// providing async/await support for modern Swift concurrency.
///
/// ## Overview
/// Implement this protocol to create custom cache backends. The protocol supports
/// generic key-value storage with automatic expiration handling.
///
/// ## Example
/// ```swift
/// let cache = MemoryCache<String, User>()
/// await cache.set("user_123", value: currentUser, expiration: .seconds(300))
/// let user = await cache.get("user_123")
/// ```
///
/// ## Topics
/// ### Essential Operations
/// - ``get(_:)``
/// - ``set(_:value:expiration:)``
/// - ``remove(_:)``
/// - ``removeAll()``
public protocol CacheProtocol<Key, Value>: Sendable {
    /// The type used for cache keys.
    associatedtype Key: Hashable & Sendable
    
    /// The type of values stored in the cache.
    associatedtype Value: Sendable
    
    /// Retrieves a value from the cache.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or `nil` if not found or expired.
    func get(_ key: Key) async -> Value?
    
    /// Stores a value in the cache.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    ///   - expiration: Optional expiration policy for this entry.
    func set(_ key: Key, value: Value, expiration: CacheExpiration?) async
    
    /// Removes a value from the cache.
    ///
    /// - Parameter key: The key to remove.
    func remove(_ key: Key) async
    
    /// Removes all values from the cache.
    func removeAll() async
    
    /// Checks if a key exists in the cache.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists and is not expired.
    func contains(_ key: Key) async -> Bool
    
    /// Returns the number of items currently in the cache.
    var count: Int { get async }
}

// MARK: - Default Implementations

public extension CacheProtocol {
    /// Sets a value without expiration.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    func set(_ key: Key, value: Value) async {
        await set(key, value: value, expiration: nil)
    }
    
    /// Checks if the cache is empty.
    var isEmpty: Bool {
        get async {
            await count == 0
        }
    }
}

// MARK: - Cache Expiration

/// Defines when a cache entry should expire.
///
/// Use `CacheExpiration` to specify time-based expiration for cached values.
///
/// ## Example
/// ```swift
/// // Expire in 5 minutes
/// await cache.set("key", value: data, expiration: .seconds(300))
///
/// // Expire at specific date
/// await cache.set("key", value: data, expiration: .date(futureDate))
///
/// // Never expire
/// await cache.set("key", value: data, expiration: .never)
/// ```
public enum CacheExpiration: Sendable, Equatable, Hashable {
    /// The entry never expires.
    case never
    
    /// The entry expires after the specified number of seconds.
    case seconds(TimeInterval)
    
    /// The entry expires at the specified date.
    case date(Date)
    
    /// The entry expires after the specified duration.
    case duration(Duration)
    
    /// Calculates the expiration date from now.
    ///
    /// - Returns: The date when this entry expires, or `nil` for `.never`.
    public var expirationDate: Date? {
        switch self {
        case .never:
            return nil
        case .seconds(let interval):
            return Date().addingTimeInterval(interval)
        case .date(let date):
            return date
        case .duration(let duration):
            let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
            return Date().addingTimeInterval(seconds)
        }
    }
    
    /// Checks if the expiration has passed.
    ///
    /// - Parameter from: The reference date to check against.
    /// - Returns: `true` if the entry has expired.
    public func isExpired(from creationDate: Date = Date()) -> Bool {
        guard let expDate = expirationDate else { return false }
        return Date() > expDate
    }
    
    /// Returns the remaining time until expiration.
    ///
    /// - Returns: Time interval until expiration, or `nil` if never expires.
    public var remainingTime: TimeInterval? {
        guard let expDate = expirationDate else { return nil }
        return expDate.timeIntervalSinceNow
    }
}

// MARK: - Cache Error

/// Errors that can occur during cache operations.
///
/// `CacheError` provides detailed information about failures during
/// cache read, write, and management operations.
public enum CacheError: Error, LocalizedError, Sendable {
    /// The requested key was not found in the cache.
    case keyNotFound(String)
    
    /// The cache entry has expired.
    case expired(String)
    
    /// Failed to serialize the value for storage.
    case serializationFailed(String)
    
    /// Failed to deserialize the stored data.
    case deserializationFailed(String)
    
    /// The cache storage is full.
    case storageFull(currentSize: Int, maxSize: Int)
    
    /// A disk I/O operation failed.
    case diskOperationFailed(underlying: Error)
    
    /// The cache has been invalidated.
    case invalidated
    
    /// A network operation failed during cache fetch.
    case networkFailed(underlying: Error)
    
    /// The data format is invalid.
    case invalidDataFormat(String)
    
    /// A generic cache error.
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .keyNotFound(let key):
            return "Cache key not found: \(key)"
        case .expired(let key):
            return "Cache entry expired: \(key)"
        case .serializationFailed(let reason):
            return "Serialization failed: \(reason)"
        case .deserializationFailed(let reason):
            return "Deserialization failed: \(reason)"
        case .storageFull(let current, let max):
            return "Cache storage full: \(current)/\(max) bytes"
        case .diskOperationFailed(let error):
            return "Disk operation failed: \(error.localizedDescription)"
        case .invalidated:
            return "Cache has been invalidated"
        case .networkFailed(let error):
            return "Network operation failed: \(error.localizedDescription)"
        case .invalidDataFormat(let reason):
            return "Invalid data format: \(reason)"
        case .unknown(let message):
            return "Cache error: \(message)"
        }
    }
}

// MARK: - Cache Statistics

/// Statistics about cache performance and usage.
///
/// Use `CacheStatistics` to monitor cache hit rates, memory usage,
/// and overall performance metrics.
public struct CacheStatistics: Sendable, Equatable, Codable {
    /// Total number of cache hits.
    public var hitCount: Int
    
    /// Total number of cache misses.
    public var missCount: Int
    
    /// Total number of items currently cached.
    public var itemCount: Int
    
    /// Total bytes used by cached items.
    public var totalBytes: Int
    
    /// Number of items evicted due to memory pressure.
    public var evictionCount: Int
    
    /// Number of items that expired.
    public var expirationCount: Int
    
    /// Timestamp when statistics were last reset.
    public var lastResetDate: Date
    
    /// Creates a new statistics instance.
    public init(
        hitCount: Int = 0,
        missCount: Int = 0,
        itemCount: Int = 0,
        totalBytes: Int = 0,
        evictionCount: Int = 0,
        expirationCount: Int = 0,
        lastResetDate: Date = Date()
    ) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.itemCount = itemCount
        self.totalBytes = totalBytes
        self.evictionCount = evictionCount
        self.expirationCount = expirationCount
        self.lastResetDate = lastResetDate
    }
    
    /// The cache hit rate as a percentage.
    public var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total) * 100
    }
    
    /// The cache miss rate as a percentage.
    public var missRate: Double {
        100 - hitRate
    }
    
    /// Resets all statistics to zero.
    public mutating func reset() {
        hitCount = 0
        missCount = 0
        evictionCount = 0
        expirationCount = 0
        lastResetDate = Date()
    }
}

// MARK: - Cache Result

/// The result of a cache lookup operation.
///
/// `CacheResult` provides detailed information about why a lookup
/// succeeded or failed.
public enum CacheResult<Value: Sendable>: Sendable {
    /// The value was found in the cache.
    case hit(Value, metadata: CacheMetadata)
    
    /// The key was not found in the cache.
    case miss
    
    /// The entry was found but has expired.
    case expired(Value)
    
    /// An error occurred during lookup.
    case error(CacheError)
    
    /// Returns the value if available, regardless of expiration status.
    public var value: Value? {
        switch self {
        case .hit(let value, _), .expired(let value):
            return value
        case .miss, .error:
            return nil
        }
    }
    
    /// Returns `true` if this is a cache hit.
    public var isHit: Bool {
        if case .hit = self { return true }
        return false
    }
    
    /// Returns `true` if this is a cache miss.
    public var isMiss: Bool {
        if case .miss = self { return true }
        return false
    }
}

// MARK: - Cache Metadata

/// Metadata associated with a cached entry.
///
/// `CacheMetadata` tracks creation time, access patterns, and
/// other information useful for cache management.
public struct CacheMetadata: Sendable, Equatable, Codable {
    /// When the entry was created.
    public var creationDate: Date
    
    /// When the entry was last accessed.
    public var lastAccessDate: Date
    
    /// Number of times the entry has been accessed.
    public var accessCount: Int
    
    /// Size of the cached data in bytes.
    public var sizeInBytes: Int
    
    /// The expiration policy for this entry.
    public var expiration: Date?
    
    /// Custom tags associated with this entry.
    public var tags: Set<String>
    
    /// Creates new metadata.
    public init(
        creationDate: Date = Date(),
        lastAccessDate: Date = Date(),
        accessCount: Int = 1,
        sizeInBytes: Int = 0,
        expiration: Date? = nil,
        tags: Set<String> = []
    ) {
        self.creationDate = creationDate
        self.lastAccessDate = lastAccessDate
        self.accessCount = accessCount
        self.sizeInBytes = sizeInBytes
        self.expiration = expiration
        self.tags = tags
    }
    
    /// Updates the last access date and increments access count.
    public mutating func recordAccess() {
        lastAccessDate = Date()
        accessCount += 1
    }
    
    /// Checks if this entry has expired.
    public var isExpired: Bool {
        guard let exp = expiration else { return false }
        return Date() > exp
    }
    
    /// Age of the entry since creation.
    public var age: TimeInterval {
        Date().timeIntervalSince(creationDate)
    }
}

// MARK: - Cache Options

/// Options for cache operations.
///
/// Use `CacheOptions` to customize individual cache operations
/// with specific behaviors.
public struct CacheOptions: Sendable, OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /// Skip memory cache and read/write directly to disk.
    public static let skipMemory = CacheOptions(rawValue: 1 << 0)
    
    /// Skip disk cache and use memory only.
    public static let skipDisk = CacheOptions(rawValue: 1 << 1)
    
    /// Force refresh even if cached value exists.
    public static let forceRefresh = CacheOptions(rawValue: 1 << 2)
    
    /// Return stale data while refreshing in background.
    public static let staleWhileRevalidate = CacheOptions(rawValue: 1 << 3)
    
    /// Don't update access time on read.
    public static let noTouch = CacheOptions(rawValue: 1 << 4)
    
    /// Compress data before storing.
    public static let compress = CacheOptions(rawValue: 1 << 5)
    
    /// Encrypt data before storing.
    public static let encrypt = CacheOptions(rawValue: 1 << 6)
    
    /// Default options (none).
    public static let `default`: CacheOptions = []
}
