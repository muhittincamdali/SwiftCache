import Foundation

// MARK: - CachePolicy

/// Eviction policies that determine which entries are removed
/// when the cache reaches its capacity limit.
///
/// Each policy provides a different trade-off between hit rate,
/// memory efficiency, and computational overhead.
///
/// ## Choosing a Policy
///
/// | Policy | Best For | Overhead |
/// |--------|----------|----------|
/// | `.lru`  | General purpose, temporal locality | Low |
/// | `.lfu`  | Frequency-based access patterns | Medium |
/// | `.fifo` | Simple insertion-order eviction | Very Low |
/// | `.ttl`  | Time-sensitive data | Low |
///
public enum CachePolicy: String, Sendable, Codable, CaseIterable {

    /// Least Recently Used — evicts the entry that hasn't been accessed
    /// for the longest time.
    ///
    /// Optimal for workloads with temporal locality where recently
    /// accessed items are likely to be accessed again soon.
    case lru

    /// Least Frequently Used — evicts the entry with the fewest total accesses.
    ///
    /// Best for workloads where access frequency is a strong predictor
    /// of future accesses. May require more bookkeeping than LRU.
    case lfu

    /// First In, First Out — evicts the oldest inserted entry regardless
    /// of access patterns.
    ///
    /// The simplest eviction strategy with minimal overhead. Works well
    /// when all entries have roughly equal value.
    case fifo

    /// Time-To-Live — evicts the entry closest to its expiration time.
    ///
    /// Prioritizes keeping entries that have the most remaining TTL.
    /// Ideal for data with well-defined freshness requirements.
    case ttl

    // MARK: - Description

    /// A human-readable description of this policy.
    public var description: String {
        switch self {
        case .lru:
            return "Least Recently Used"
        case .lfu:
            return "Least Frequently Used"
        case .fifo:
            return "First In, First Out"
        case .ttl:
            return "Time-To-Live Based"
        }
    }

    /// Short description suitable for logging.
    public var shortDescription: String {
        rawValue.uppercased()
    }
}

// MARK: - EvictionResult

/// The result of an eviction operation.
public struct EvictionResult<Key: Hashable & Sendable>: Sendable {

    /// The keys that were evicted.
    public let evictedKeys: [Key]

    /// The number of bytes freed by the eviction.
    public let freedBytes: Int64

    /// The eviction policy that was applied.
    public let policy: CachePolicy

    /// The time taken to perform the eviction in seconds.
    public let duration: TimeInterval

    /// Creates a new eviction result.
    /// - Parameters:
    ///   - evictedKeys: Keys removed during eviction.
    ///   - freedBytes: Bytes freed.
    ///   - policy: The policy used.
    ///   - duration: Time elapsed during eviction.
    public init(
        evictedKeys: [Key],
        freedBytes: Int64,
        policy: CachePolicy,
        duration: TimeInterval
    ) {
        self.evictedKeys = evictedKeys
        self.freedBytes = freedBytes
        self.policy = policy
        self.duration = duration
    }

    /// Whether any entries were actually evicted.
    public var didEvict: Bool {
        !evictedKeys.isEmpty
    }

    /// The number of entries evicted.
    public var evictedCount: Int {
        evictedKeys.count
    }
}
