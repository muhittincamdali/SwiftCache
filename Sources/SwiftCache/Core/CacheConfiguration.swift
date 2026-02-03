// CacheConfiguration.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Cache Configuration

/// Configuration options for cache instances.
///
/// `CacheConfiguration` provides a comprehensive set of options for
/// customizing cache behavior, including memory limits, expiration
/// policies, and eviction strategies.
///
/// ## Overview
/// Create a configuration to customize your cache:
///
/// ```swift
/// let config = CacheConfiguration(
///     maxItemCount: 1000,
///     maxMemoryBytes: 50 * 1024 * 1024,  // 50 MB
///     defaultExpiration: .seconds(3600),
///     evictionPolicy: .lru
/// )
///
/// let cache = MemoryCache<String, Data>(configuration: config)
/// ```
///
/// ## Topics
/// ### Memory Management
/// - ``maxItemCount``
/// - ``maxMemoryBytes``
/// - ``evictionPolicy``
///
/// ### Expiration
/// - ``defaultExpiration``
/// - ``cleanupInterval``
public struct CacheConfiguration: Sendable, Equatable {
    
    // MARK: - Memory Configuration
    
    /// Maximum number of items the cache can hold.
    ///
    /// When this limit is reached, items are evicted according to
    /// the configured `evictionPolicy`. Set to `nil` for unlimited items.
    public var maxItemCount: Int?
    
    /// Maximum memory size in bytes.
    ///
    /// The cache will evict items when total memory usage exceeds
    /// this limit. Set to `nil` for unlimited memory.
    public var maxMemoryBytes: Int?
    
    /// The eviction policy used when the cache is full.
    public var evictionPolicy: EvictionPolicy
    
    // MARK: - Expiration Configuration
    
    /// Default expiration for items without explicit expiration.
    ///
    /// Items stored without specifying an expiration will use this
    /// value. Set to `.never` to disable default expiration.
    public var defaultExpiration: CacheExpiration
    
    /// Interval between automatic cleanup runs.
    ///
    /// The cache periodically removes expired items. Set to `nil`
    /// to disable automatic cleanup.
    public var cleanupInterval: TimeInterval?
    
    /// Whether to remove expired items lazily on access.
    ///
    /// When enabled, expired items are removed when accessed rather
    /// than by background cleanup.
    public var lazyExpiration: Bool
    
    // MARK: - Behavior Configuration
    
    /// Whether to track access statistics.
    ///
    /// Enabling statistics tracking adds overhead but provides
    /// useful metrics for monitoring cache performance.
    public var trackStatistics: Bool
    
    /// Whether to use thread-safe operations.
    ///
    /// When enabled, all cache operations are protected by locks
    /// for safe concurrent access.
    public var threadSafe: Bool
    
    /// Whether to validate data integrity on read.
    ///
    /// When enabled, the cache verifies checksums on read to detect
    /// data corruption.
    public var validateOnRead: Bool
    
    /// Whether to notify observers of cache changes.
    public var notifyObservers: Bool
    
    // MARK: - Disk Configuration
    
    /// Directory for disk cache storage.
    ///
    /// Defaults to a subdirectory in the system caches directory.
    public var diskCacheDirectory: URL?
    
    /// Maximum disk space in bytes.
    public var maxDiskBytes: Int?
    
    /// Whether to use memory-mapped files for disk access.
    public var useMemoryMapping: Bool
    
    /// File protection level for disk cache.
    public var fileProtection: FileProtectionType
    
    // MARK: - Network Configuration
    
    /// Timeout for network fetch operations.
    public var networkTimeout: TimeInterval
    
    /// Whether to cache network errors temporarily.
    public var cacheNetworkErrors: Bool
    
    /// Duration to cache network errors.
    public var errorCacheDuration: TimeInterval
    
    // MARK: - Initialization
    
    /// Creates a new cache configuration with the specified options.
    ///
    /// - Parameters:
    ///   - maxItemCount: Maximum number of items. Default is 1000.
    ///   - maxMemoryBytes: Maximum memory in bytes. Default is 100 MB.
    ///   - evictionPolicy: Eviction policy. Default is `.lru`.
    ///   - defaultExpiration: Default expiration. Default is 1 hour.
    ///   - cleanupInterval: Cleanup interval. Default is 60 seconds.
    ///   - lazyExpiration: Enable lazy expiration. Default is true.
    ///   - trackStatistics: Enable statistics. Default is true.
    ///   - threadSafe: Enable thread safety. Default is true.
    ///   - validateOnRead: Validate on read. Default is false.
    ///   - notifyObservers: Notify observers. Default is true.
    ///   - diskCacheDirectory: Disk directory. Default is nil.
    ///   - maxDiskBytes: Maximum disk bytes. Default is 500 MB.
    ///   - useMemoryMapping: Use memory mapping. Default is false.
    ///   - fileProtection: File protection. Default is `.complete`.
    ///   - networkTimeout: Network timeout. Default is 30 seconds.
    ///   - cacheNetworkErrors: Cache errors. Default is false.
    ///   - errorCacheDuration: Error duration. Default is 60 seconds.
    public init(
        maxItemCount: Int? = 1000,
        maxMemoryBytes: Int? = 100 * 1024 * 1024,
        evictionPolicy: EvictionPolicy = .lru,
        defaultExpiration: CacheExpiration = .seconds(3600),
        cleanupInterval: TimeInterval? = 60,
        lazyExpiration: Bool = true,
        trackStatistics: Bool = true,
        threadSafe: Bool = true,
        validateOnRead: Bool = false,
        notifyObservers: Bool = true,
        diskCacheDirectory: URL? = nil,
        maxDiskBytes: Int? = 500 * 1024 * 1024,
        useMemoryMapping: Bool = false,
        fileProtection: FileProtectionType = .complete,
        networkTimeout: TimeInterval = 30,
        cacheNetworkErrors: Bool = false,
        errorCacheDuration: TimeInterval = 60
    ) {
        self.maxItemCount = maxItemCount
        self.maxMemoryBytes = maxMemoryBytes
        self.evictionPolicy = evictionPolicy
        self.defaultExpiration = defaultExpiration
        self.cleanupInterval = cleanupInterval
        self.lazyExpiration = lazyExpiration
        self.trackStatistics = trackStatistics
        self.threadSafe = threadSafe
        self.validateOnRead = validateOnRead
        self.notifyObservers = notifyObservers
        self.diskCacheDirectory = diskCacheDirectory
        self.maxDiskBytes = maxDiskBytes
        self.useMemoryMapping = useMemoryMapping
        self.fileProtection = fileProtection
        self.networkTimeout = networkTimeout
        self.cacheNetworkErrors = cacheNetworkErrors
        self.errorCacheDuration = errorCacheDuration
    }
    
    // MARK: - Preset Configurations
    
    /// Default configuration suitable for most use cases.
    public static let `default` = CacheConfiguration()
    
    /// Configuration optimized for memory-constrained environments.
    public static let lowMemory = CacheConfiguration(
        maxItemCount: 100,
        maxMemoryBytes: 10 * 1024 * 1024,
        evictionPolicy: .lru,
        defaultExpiration: .seconds(300),
        cleanupInterval: 30,
        trackStatistics: false
    )
    
    /// Configuration for high-performance caching.
    public static let highPerformance = CacheConfiguration(
        maxItemCount: 10000,
        maxMemoryBytes: 500 * 1024 * 1024,
        evictionPolicy: .lru,
        defaultExpiration: .seconds(7200),
        cleanupInterval: 120,
        lazyExpiration: true,
        trackStatistics: false,
        threadSafe: true
    )
    
    /// Configuration for persistent disk-based caching.
    public static let persistent = CacheConfiguration(
        maxItemCount: nil,
        maxMemoryBytes: 50 * 1024 * 1024,
        evictionPolicy: .lru,
        defaultExpiration: .never,
        cleanupInterval: 300,
        maxDiskBytes: 1024 * 1024 * 1024,
        useMemoryMapping: true
    )
    
    /// Configuration for image caching.
    public static let images = CacheConfiguration(
        maxItemCount: 500,
        maxMemoryBytes: 200 * 1024 * 1024,
        evictionPolicy: .lru,
        defaultExpiration: .seconds(86400),
        cleanupInterval: 60
    )
    
    /// Configuration for API response caching.
    public static let apiResponses = CacheConfiguration(
        maxItemCount: 1000,
        maxMemoryBytes: 50 * 1024 * 1024,
        evictionPolicy: .lru,
        defaultExpiration: .seconds(300),
        cleanupInterval: 30,
        cacheNetworkErrors: true,
        errorCacheDuration: 30
    )
}

// MARK: - Eviction Policy

/// Strategies for evicting items from a full cache.
///
/// When the cache reaches its capacity limits, items must be removed
/// to make room for new entries. The eviction policy determines which
/// items are removed first.
public enum EvictionPolicy: String, Sendable, CaseIterable, Codable {
    /// Least Recently Used - evicts items that haven't been accessed recently.
    ///
    /// LRU is ideal for caches where recent access patterns predict
    /// future access. It favors keeping recently accessed items.
    case lru
    
    /// First In First Out - evicts the oldest items first.
    ///
    /// FIFO is simple and predictable, evicting items in the order
    /// they were added regardless of access patterns.
    case fifo
    
    /// Least Frequently Used - evicts items with the lowest access count.
    ///
    /// LFU is useful when some items are accessed much more frequently
    /// than others and should be kept longer.
    case lfu
    
    /// Time To Live - evicts items closest to expiration.
    ///
    /// TTL-based eviction prioritizes removing items that will expire
    /// soon anyway.
    case ttl
    
    /// Random eviction.
    ///
    /// Randomly selects items for eviction. Simple but can be effective
    /// for unpredictable access patterns.
    case random
    
    /// Size-based eviction - evicts largest items first.
    ///
    /// Useful when memory pressure is the primary concern and
    /// removing large items frees more space efficiently.
    case size
    
    /// Human-readable description of the policy.
    public var description: String {
        switch self {
        case .lru:
            return "Least Recently Used"
        case .fifo:
            return "First In First Out"
        case .lfu:
            return "Least Frequently Used"
        case .ttl:
            return "Time To Live"
        case .random:
            return "Random"
        case .size:
            return "Size-Based"
        }
    }
}

// MARK: - File Protection Type

/// File protection levels for disk cache.
public enum FileProtectionType: String, Sendable, Codable {
    /// Complete protection - file is inaccessible when device is locked.
    case complete
    
    /// Protected unless open - file is accessible if opened before lock.
    case completeUnlessOpen
    
    /// Protected until first user authentication.
    case completeUntilFirstUserAuthentication
    
    /// No protection.
    case none
    
    #if os(iOS) || os(tvOS) || os(watchOS)
    /// Converts to the Foundation file protection type.
    var foundationValue: Foundation.FileProtectionType {
        switch self {
        case .complete:
            return .complete
        case .completeUnlessOpen:
            return .completeUnlessOpen
        case .completeUntilFirstUserAuthentication:
            return .completeUntilFirstUserAuthentication
        case .none:
            return .none
        }
    }
    #endif
}

// MARK: - Configuration Builder

/// A builder for creating cache configurations fluently.
///
/// Use `CacheConfigurationBuilder` for a more readable way to create
/// complex configurations.
///
/// ## Example
/// ```swift
/// let config = CacheConfigurationBuilder()
///     .maxItems(1000)
///     .maxMemory(50 * 1024 * 1024)
///     .eviction(.lru)
///     .expiration(.seconds(3600))
///     .build()
/// ```
public final class CacheConfigurationBuilder: @unchecked Sendable {
    private var configuration = CacheConfiguration()
    
    /// Creates a new builder.
    public init() {}
    
    /// Sets the maximum item count.
    @discardableResult
    public func maxItems(_ count: Int?) -> Self {
        configuration.maxItemCount = count
        return self
    }
    
    /// Sets the maximum memory in bytes.
    @discardableResult
    public func maxMemory(_ bytes: Int?) -> Self {
        configuration.maxMemoryBytes = bytes
        return self
    }
    
    /// Sets the eviction policy.
    @discardableResult
    public func eviction(_ policy: EvictionPolicy) -> Self {
        configuration.evictionPolicy = policy
        return self
    }
    
    /// Sets the default expiration.
    @discardableResult
    public func expiration(_ expiration: CacheExpiration) -> Self {
        configuration.defaultExpiration = expiration
        return self
    }
    
    /// Sets the cleanup interval.
    @discardableResult
    public func cleanupInterval(_ interval: TimeInterval?) -> Self {
        configuration.cleanupInterval = interval
        return self
    }
    
    /// Enables or disables lazy expiration.
    @discardableResult
    public func lazyExpiration(_ enabled: Bool) -> Self {
        configuration.lazyExpiration = enabled
        return self
    }
    
    /// Enables or disables statistics tracking.
    @discardableResult
    public func trackStatistics(_ enabled: Bool) -> Self {
        configuration.trackStatistics = enabled
        return self
    }
    
    /// Enables or disables thread safety.
    @discardableResult
    public func threadSafe(_ enabled: Bool) -> Self {
        configuration.threadSafe = enabled
        return self
    }
    
    /// Sets the disk cache directory.
    @discardableResult
    public func diskDirectory(_ url: URL?) -> Self {
        configuration.diskCacheDirectory = url
        return self
    }
    
    /// Sets the maximum disk size.
    @discardableResult
    public func maxDisk(_ bytes: Int?) -> Self {
        configuration.maxDiskBytes = bytes
        return self
    }
    
    /// Sets the network timeout.
    @discardableResult
    public func networkTimeout(_ timeout: TimeInterval) -> Self {
        configuration.networkTimeout = timeout
        return self
    }
    
    /// Builds the configuration.
    public func build() -> CacheConfiguration {
        return configuration
    }
}
