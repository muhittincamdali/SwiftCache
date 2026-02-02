import Foundation

// MARK: - CacheEntry

/// A container for a cached value along with its metadata.
///
/// Each entry tracks creation time, expiration, access patterns,
/// and byte size for use by eviction policies and monitoring.
public struct CacheEntry<Value: Sendable>: Sendable {

    // MARK: - Properties

    /// The cached value.
    public let value: Value

    /// The date when this entry was first created.
    public let createdAt: Date

    /// The date when this entry expires, or `nil` for no expiration.
    public let expiresAt: Date?

    /// Additional metadata associated with this entry.
    public var metadata: EntryMetadata

    // MARK: - Computed Properties

    /// Whether this entry has expired based on the current date.
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }

    /// The age of this entry in seconds since creation.
    public var age: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }

    /// The remaining time before expiration, or `nil` if no expiration is set.
    public var timeToLive: TimeInterval? {
        guard let expiresAt = expiresAt else { return nil }
        let remaining = expiresAt.timeIntervalSince(Date())
        return remaining > 0 ? remaining : 0
    }

    // MARK: - Initialization

    /// Creates a new cache entry.
    ///
    /// - Parameters:
    ///   - value: The value to cache.
    ///   - createdAt: The creation timestamp. Defaults to now.
    ///   - expiresAt: The expiration timestamp, or `nil` for no expiration.
    ///   - metadata: Additional metadata for this entry.
    public init(
        value: Value,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        metadata: EntryMetadata = EntryMetadata()
    ) {
        self.value = value
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.metadata = metadata
    }

    // MARK: - Methods

    /// Creates a new entry with an updated access timestamp and incremented hit count.
    /// - Returns: A copy of this entry with refreshed access metadata.
    public func touched() -> CacheEntry<Value> {
        var updatedMetadata = metadata
        updatedMetadata.lastAccessedAt = Date()
        updatedMetadata.accessCount += 1
        return CacheEntry(
            value: value,
            createdAt: createdAt,
            expiresAt: expiresAt,
            metadata: updatedMetadata
        )
    }

    /// Creates a new entry with the same value but a new expiration date.
    /// - Parameter newExpiration: The new expiration date.
    /// - Returns: A copy with the updated expiration.
    public func withExpiration(_ newExpiration: Date?) -> CacheEntry<Value> {
        CacheEntry(
            value: value,
            createdAt: createdAt,
            expiresAt: newExpiration,
            metadata: metadata
        )
    }
}

// MARK: - EntryMetadata

/// Metadata associated with a cache entry for tracking and analytics.
public struct EntryMetadata: Sendable {

    /// The date this entry was last accessed.
    public var lastAccessedAt: Date

    /// The number of times this entry has been read.
    public var accessCount: Int

    /// The estimated size of the cached value in bytes.
    public var sizeInBytes: Int64

    /// The source layer that originally provided this entry.
    public var sourceLayer: String?

    /// Custom tags for categorizing entries.
    public var tags: Set<String>

    /// The priority level for this entry during eviction.
    public var priority: EntryPriority

    /// Creates new entry metadata.
    ///
    /// - Parameters:
    ///   - lastAccessedAt: Last access time. Defaults to now.
    ///   - accessCount: Number of accesses. Defaults to `0`.
    ///   - sizeInBytes: Estimated size. Defaults to `0`.
    ///   - sourceLayer: Source layer name. Defaults to `nil`.
    ///   - tags: Custom tags. Defaults to empty.
    ///   - priority: Eviction priority. Defaults to `.normal`.
    public init(
        lastAccessedAt: Date = Date(),
        accessCount: Int = 0,
        sizeInBytes: Int64 = 0,
        sourceLayer: String? = nil,
        tags: Set<String> = [],
        priority: EntryPriority = .normal
    ) {
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
        self.sizeInBytes = sizeInBytes
        self.sourceLayer = sourceLayer
        self.tags = tags
        self.priority = priority
    }
}

// MARK: - EntryPriority

/// Priority levels affecting eviction order.
///
/// Higher-priority entries are less likely to be evicted
/// when the cache reaches capacity.
public enum EntryPriority: Int, Sendable, Comparable, Codable {
    /// Low priority — evicted first.
    case low = 0
    /// Normal priority — default level.
    case normal = 1
    /// High priority — evicted last.
    case high = 2
    /// Critical priority — only evicted when absolutely necessary.
    case critical = 3

    public static func < (lhs: EntryPriority, rhs: EntryPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
