import Foundation

// MARK: - CacheConfiguration

/// Configuration options for controlling cache behavior.
///
/// Use `CacheConfiguration` to customize TTL, eviction policies,
/// storage limits, and other operational parameters.
///
/// ## Example
///
/// ```swift
/// let config = CacheConfiguration(
///     defaultTTL: 300,
///     maxEntryCount: 500,
///     maxDiskSize: 50 * 1024 * 1024,
///     evictionPolicy: .lru
/// )
/// let cache = Cache<String, Data>(configuration: config)
/// ```
public struct CacheConfiguration: Sendable {

    // MARK: - Properties

    /// Default time-to-live for cache entries in seconds.
    ///
    /// When a value is stored without an explicit TTL, this value
    /// is used. Set to `0` or `.infinity` to disable expiration.
    public let defaultTTL: TimeInterval

    /// Maximum number of entries allowed in the in-memory layer.
    ///
    /// When this limit is reached, the eviction policy determines
    /// which entry to remove before inserting a new one.
    public let maxEntryCount: Int

    /// Maximum disk storage size in bytes.
    ///
    /// The disk layer will begin evicting entries when total
    /// stored data exceeds this threshold.
    public let maxDiskSize: Int64

    /// Maximum memory storage size in bytes.
    ///
    /// The memory layer will begin evicting when the estimated
    /// total memory usage exceeds this value.
    public let maxMemorySize: Int64

    /// The eviction policy to use when the cache is full.
    public let evictionPolicy: CachePolicy

    /// Interval in seconds between automatic cleanup sweeps.
    ///
    /// Set to `0` to disable periodic cleanup. Expired entries
    /// will still be removed on access.
    public let cleanupInterval: TimeInterval

    /// Whether to enable disk persistence.
    ///
    /// When enabled, entries are written to disk for survival
    /// across app launches.
    public let diskPersistenceEnabled: Bool

    /// Whether to enable encryption for disk-stored entries.
    ///
    /// Uses AES-256 encryption for all data written to disk.
    public let encryptionEnabled: Bool

    /// The directory name used for disk cache storage.
    ///
    /// This directory is created inside the app's caches directory.
    public let diskDirectoryName: String

    /// Whether to enable CloudKit synchronization.
    public let cloudSyncEnabled: Bool

    /// The CloudKit container identifier for sync operations.
    public let cloudContainerIdentifier: String?

    /// Whether to compress data before writing to disk.
    public let compressionEnabled: Bool

    /// The serialization format used for encoding/decoding values.
    public let serializationFormat: SerializationFormat

    /// Whether to log cache operations for debugging.
    public let loggingEnabled: Bool

    /// Maximum number of concurrent operations allowed.
    public let maxConcurrentOperations: Int

    // MARK: - Initialization

    /// Creates a new cache configuration with the specified parameters.
    ///
    /// - Parameters:
    ///   - defaultTTL: Default TTL in seconds. Default is `300` (5 minutes).
    ///   - maxEntryCount: Maximum in-memory entries. Default is `1000`.
    ///   - maxDiskSize: Maximum disk usage in bytes. Default is `100MB`.
    ///   - maxMemorySize: Maximum memory usage in bytes. Default is `50MB`.
    ///   - evictionPolicy: Eviction strategy. Default is `.lru`.
    ///   - cleanupInterval: Cleanup sweep interval. Default is `120` seconds.
    ///   - diskPersistenceEnabled: Enable disk storage. Default is `true`.
    ///   - encryptionEnabled: Enable AES-256 encryption. Default is `false`.
    ///   - diskDirectoryName: Disk cache directory name. Default is `"SwiftCache"`.
    ///   - cloudSyncEnabled: Enable CloudKit sync. Default is `false`.
    ///   - cloudContainerIdentifier: CloudKit container ID. Default is `nil`.
    ///   - compressionEnabled: Enable compression. Default is `false`.
    ///   - serializationFormat: Serialization format. Default is `.json`.
    ///   - loggingEnabled: Enable debug logging. Default is `false`.
    ///   - maxConcurrentOperations: Max concurrent ops. Default is `4`.
    public init(
        defaultTTL: TimeInterval = 300,
        maxEntryCount: Int = 1000,
        maxDiskSize: Int64 = 100 * 1024 * 1024,
        maxMemorySize: Int64 = 50 * 1024 * 1024,
        evictionPolicy: CachePolicy = .lru,
        cleanupInterval: TimeInterval = 120,
        diskPersistenceEnabled: Bool = true,
        encryptionEnabled: Bool = false,
        diskDirectoryName: String = "SwiftCache",
        cloudSyncEnabled: Bool = false,
        cloudContainerIdentifier: String? = nil,
        compressionEnabled: Bool = false,
        serializationFormat: SerializationFormat = .json,
        loggingEnabled: Bool = false,
        maxConcurrentOperations: Int = 4
    ) {
        self.defaultTTL = defaultTTL
        self.maxEntryCount = maxEntryCount
        self.maxDiskSize = maxDiskSize
        self.maxMemorySize = maxMemorySize
        self.evictionPolicy = evictionPolicy
        self.cleanupInterval = cleanupInterval
        self.diskPersistenceEnabled = diskPersistenceEnabled
        self.encryptionEnabled = encryptionEnabled
        self.diskDirectoryName = diskDirectoryName
        self.cloudSyncEnabled = cloudSyncEnabled
        self.cloudContainerIdentifier = cloudContainerIdentifier
        self.compressionEnabled = compressionEnabled
        self.serializationFormat = serializationFormat
        self.loggingEnabled = loggingEnabled
        self.maxConcurrentOperations = maxConcurrentOperations
    }

    // MARK: - Presets

    /// Default configuration suitable for most use cases.
    ///
    /// Uses LRU eviction, 5-minute TTL, 1000 entry limit, and disk persistence.
    public static let `default` = CacheConfiguration()

    /// Aggressive caching configuration for high-throughput scenarios.
    ///
    /// Higher limits, longer TTL, and compression enabled.
    public static let aggressive = CacheConfiguration(
        defaultTTL: 3600,
        maxEntryCount: 10000,
        maxDiskSize: 500 * 1024 * 1024,
        maxMemorySize: 200 * 1024 * 1024,
        evictionPolicy: .lru,
        cleanupInterval: 300,
        compressionEnabled: true
    )

    /// Minimal configuration for lightweight caching needs.
    ///
    /// Small limits, short TTL, memory-only storage.
    public static let minimal = CacheConfiguration(
        defaultTTL: 60,
        maxEntryCount: 100,
        maxDiskSize: 10 * 1024 * 1024,
        maxMemorySize: 10 * 1024 * 1024,
        evictionPolicy: .fifo,
        cleanupInterval: 30,
        diskPersistenceEnabled: false
    )

    /// Secure configuration with encryption and shorter TTL.
    ///
    /// Suitable for caching sensitive data like tokens or user info.
    public static let secure = CacheConfiguration(
        defaultTTL: 120,
        maxEntryCount: 500,
        evictionPolicy: .ttl,
        encryptionEnabled: true,
        loggingEnabled: false
    )

    /// Image caching configuration optimized for large binary data.
    ///
    /// Large disk allocation, LRU eviction, longer TTL.
    public static let imageCache = CacheConfiguration(
        defaultTTL: 86400,
        maxEntryCount: 2000,
        maxDiskSize: 200 * 1024 * 1024,
        maxMemorySize: 100 * 1024 * 1024,
        evictionPolicy: .lru,
        cleanupInterval: 600,
        diskDirectoryName: "SwiftCacheImages"
    )
}

// MARK: - SerializationFormat

/// Supported serialization formats for cache data.
public enum SerializationFormat: String, Sendable, Codable {
    /// JSON serialization using `JSONEncoder`/`JSONDecoder`.
    case json

    /// Property list serialization.
    case plist

    /// MessagePack binary format (requires custom implementation).
    case messagePack

    /// Raw data passthrough with no transformation.
    case raw
}
