// CachePolicy.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Cache Policy

/// Defines how the cache should handle various scenarios.
///
/// `CachePolicy` controls cache behavior for reads, writes, and
/// network operations. Use policies to fine-tune caching behavior
/// for different use cases.
///
/// ## Example
/// ```swift
/// let policy = CachePolicy(
///     readPolicy: .cacheFirst,
///     writePolicy: .writeThrough,
///     stalePolicy: .revalidate
/// )
/// ```
public struct CachePolicy: Sendable, Equatable {
    
    /// How to handle read operations.
    public var readPolicy: ReadPolicy
    
    /// How to handle write operations.
    public var writePolicy: WritePolicy
    
    /// How to handle stale data.
    public var stalePolicy: StalePolicy
    
    /// How to handle network failures.
    public var failurePolicy: FailurePolicy
    
    /// Creates a new cache policy.
    ///
    /// - Parameters:
    ///   - readPolicy: Read handling policy.
    ///   - writePolicy: Write handling policy.
    ///   - stalePolicy: Stale data handling policy.
    ///   - failurePolicy: Failure handling policy.
    public init(
        readPolicy: ReadPolicy = .cacheFirst,
        writePolicy: WritePolicy = .writeThrough,
        stalePolicy: StalePolicy = .revalidate,
        failurePolicy: FailurePolicy = .returnStale
    ) {
        self.readPolicy = readPolicy
        self.writePolicy = writePolicy
        self.stalePolicy = stalePolicy
        self.failurePolicy = failurePolicy
    }
    
    // MARK: - Preset Policies
    
    /// Default policy - cache first with write-through.
    public static let `default` = CachePolicy()
    
    /// Aggressive caching - prioritize cache over network.
    public static let cacheFirst = CachePolicy(
        readPolicy: .cacheOnly,
        writePolicy: .writeBack,
        stalePolicy: .returnStale,
        failurePolicy: .returnStale
    )
    
    /// Network first - always try network before cache.
    public static let networkFirst = CachePolicy(
        readPolicy: .networkFirst,
        writePolicy: .writeThrough,
        stalePolicy: .revalidate,
        failurePolicy: .returnStale
    )
    
    /// No caching - bypass cache entirely.
    public static let noCache = CachePolicy(
        readPolicy: .networkOnly,
        writePolicy: .none,
        stalePolicy: .reject,
        failurePolicy: .fail
    )
    
    /// Offline first - prefer cached data for offline support.
    public static let offlineFirst = CachePolicy(
        readPolicy: .cacheFirst,
        writePolicy: .writeBack,
        stalePolicy: .returnStale,
        failurePolicy: .returnStale
    )
}

// MARK: - Read Policy

/// Defines how read operations should be handled.
public enum ReadPolicy: String, Sendable, CaseIterable, Codable {
    /// Check cache first, then network if not found.
    case cacheFirst
    
    /// Check network first, fall back to cache on failure.
    case networkFirst
    
    /// Only read from cache, never from network.
    case cacheOnly
    
    /// Only read from network, never from cache.
    case networkOnly
    
    /// Read from cache and network simultaneously.
    case parallel
    
    /// Description of the policy.
    public var description: String {
        switch self {
        case .cacheFirst:
            return "Cache First"
        case .networkFirst:
            return "Network First"
        case .cacheOnly:
            return "Cache Only"
        case .networkOnly:
            return "Network Only"
        case .parallel:
            return "Parallel"
        }
    }
}

// MARK: - Write Policy

/// Defines how write operations should be handled.
public enum WritePolicy: String, Sendable, CaseIterable, Codable {
    /// Write to cache and persist immediately.
    case writeThrough
    
    /// Write to cache, persist lazily in background.
    case writeBack
    
    /// Write to memory cache only, no persistence.
    case cacheOnly
    
    /// Don't cache at all.
    case none
    
    /// Description of the policy.
    public var description: String {
        switch self {
        case .writeThrough:
            return "Write Through"
        case .writeBack:
            return "Write Back"
        case .cacheOnly:
            return "Cache Only"
        case .none:
            return "No Caching"
        }
    }
}

// MARK: - Stale Policy

/// Defines how stale (expired) data should be handled.
public enum StalePolicy: String, Sendable, CaseIterable, Codable {
    /// Return stale data immediately while revalidating.
    case revalidate
    
    /// Return stale data without revalidating.
    case returnStale
    
    /// Reject stale data, treat as cache miss.
    case reject
    
    /// Return stale data with a warning.
    case warn
    
    /// Description of the policy.
    public var description: String {
        switch self {
        case .revalidate:
            return "Stale While Revalidate"
        case .returnStale:
            return "Return Stale"
        case .reject:
            return "Reject Stale"
        case .warn:
            return "Warn on Stale"
        }
    }
}

// MARK: - Failure Policy

/// Defines how failures should be handled.
public enum FailurePolicy: String, Sendable, CaseIterable, Codable {
    /// Return stale cached data on failure.
    case returnStale
    
    /// Fail immediately with error.
    case fail
    
    /// Retry the operation.
    case retry
    
    /// Return a default value.
    case returnDefault
    
    /// Description of the policy.
    public var description: String {
        switch self {
        case .returnStale:
            return "Return Stale on Failure"
        case .fail:
            return "Fail Immediately"
        case .retry:
            return "Retry"
        case .returnDefault:
            return "Return Default"
        }
    }
}

// MARK: - Cache Priority

/// Priority levels for cache operations.
public enum CachePriority: Int, Sendable, Comparable, CaseIterable, Codable {
    /// Low priority - may be evicted first.
    case low = 0
    
    /// Normal priority.
    case normal = 1
    
    /// High priority - less likely to be evicted.
    case high = 2
    
    /// Critical - should never be evicted automatically.
    case critical = 3
    
    public static func < (lhs: CachePriority, rhs: CachePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// Description of the priority.
    public var description: String {
        switch self {
        case .low:
            return "Low"
        case .normal:
            return "Normal"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }
}
