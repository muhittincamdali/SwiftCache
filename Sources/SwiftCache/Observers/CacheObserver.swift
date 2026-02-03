// CacheObserver.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Cache Observer Protocol

/// A protocol for observing cache events.
///
/// Implement `CacheObserver` to receive notifications when
/// cache contents change.
///
/// ## Overview
/// Observers can monitor additions, removals, evictions, and
/// other cache events.
///
/// ```swift
/// class MyCacheObserver: CacheObserver {
///     func cacheDidChange(event: CacheEvent) {
///         switch event {
///         case .added(let key):
///             print("Added: \(key)")
///         case .evicted(let key, let reason):
///             print("Evicted \(key): \(reason)")
///         default:
///             break
///         }
///     }
/// }
/// ```
public protocol CacheObserver: Sendable {
    /// Called when a cache event occurs.
    ///
    /// - Parameter event: The cache event.
    func cacheDidChange(event: CacheEvent)
}

// MARK: - Cache Event

/// Events that can occur in a cache.
public enum CacheEvent: Sendable {
    /// An item was added to the cache.
    case added(key: String)
    
    /// An item was updated in the cache.
    case updated(key: String)
    
    /// An item was removed from the cache.
    case removed(key: String)
    
    /// An item was evicted due to capacity or other constraints.
    case evicted(key: String, reason: EvictionReason)
    
    /// An item expired.
    case expired(key: String)
    
    /// The cache was cleared.
    case cleared
    
    /// An error occurred.
    case error(CacheError)
    
    /// Memory warning received.
    case memoryWarning
    
    /// The key associated with this event.
    public var key: String? {
        switch self {
        case .added(let key), .updated(let key), .removed(let key),
             .evicted(let key, _), .expired(let key):
            return key
        case .cleared, .error, .memoryWarning:
            return nil
        }
    }
}

// MARK: - Eviction Reason

/// Reasons why an item was evicted from the cache.
public enum EvictionReason: String, Sendable {
    /// Evicted to make room for new items.
    case capacityLimit
    
    /// Evicted due to memory pressure.
    case memoryPressure
    
    /// Evicted due to disk space constraints.
    case diskSpace
    
    /// Evicted due to TTL expiration during cleanup.
    case expiration
    
    /// Evicted manually.
    case manual
    
    /// Evicted based on LRU policy.
    case lruEviction
    
    /// Evicted based on LFU policy.
    case lfuEviction
    
    /// Human-readable description.
    public var description: String {
        switch self {
        case .capacityLimit:
            return "Cache at capacity"
        case .memoryPressure:
            return "Memory pressure"
        case .diskSpace:
            return "Disk space limit"
        case .expiration:
            return "Entry expired"
        case .manual:
            return "Manual removal"
        case .lruEviction:
            return "Least recently used"
        case .lfuEviction:
            return "Least frequently used"
        }
    }
}

// MARK: - Closure-Based Observer

/// A cache observer that calls a closure on events.
public final class ClosureObserver: CacheObserver, @unchecked Sendable {
    
    /// The event handler closure.
    private let handler: @Sendable (CacheEvent) -> Void
    
    /// Event filter (optional).
    private let filter: ((CacheEvent) -> Bool)?
    
    /// Creates a closure-based observer.
    ///
    /// - Parameters:
    ///   - filter: Optional filter for events.
    ///   - handler: Closure called for each event.
    public init(
        filter: ((CacheEvent) -> Bool)? = nil,
        handler: @escaping @Sendable (CacheEvent) -> Void
    ) {
        self.filter = filter
        self.handler = handler
    }
    
    public func cacheDidChange(event: CacheEvent) {
        if let filter = filter {
            guard filter(event) else { return }
        }
        handler(event)
    }
}

// MARK: - Logging Observer

/// A cache observer that logs events.
public final class LoggingObserver: CacheObserver, @unchecked Sendable {
    
    /// Log level.
    public enum Level: Int, Sendable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
    }
    
    /// Minimum level to log.
    private let minLevel: Level
    
    /// Logger closure.
    private let logger: @Sendable (Level, String) -> Void
    
    /// Creates a logging observer.
    ///
    /// - Parameters:
    ///   - minLevel: Minimum level to log.
    ///   - logger: Custom logger closure.
    public init(
        minLevel: Level = .info,
        logger: @escaping @Sendable (Level, String) -> Void = { level, message in
            print("[\(level)] SwiftCache: \(message)")
        }
    ) {
        self.minLevel = minLevel
        self.logger = logger
    }
    
    public func cacheDidChange(event: CacheEvent) {
        let (level, message) = logMessage(for: event)
        
        guard level.rawValue >= minLevel.rawValue else { return }
        logger(level, message)
    }
    
    /// Generates log message for an event.
    private func logMessage(for event: CacheEvent) -> (Level, String) {
        switch event {
        case .added(let key):
            return (.debug, "Added key: \(key)")
        case .updated(let key):
            return (.debug, "Updated key: \(key)")
        case .removed(let key):
            return (.debug, "Removed key: \(key)")
        case .evicted(let key, let reason):
            return (.info, "Evicted key: \(key), reason: \(reason.description)")
        case .expired(let key):
            return (.debug, "Expired key: \(key)")
        case .cleared:
            return (.info, "Cache cleared")
        case .error(let error):
            return (.error, "Error: \(error.localizedDescription)")
        case .memoryWarning:
            return (.warning, "Memory warning received")
        }
    }
}

// MARK: - Statistics Observer

/// A cache observer that collects statistics.
public actor StatisticsObserver: CacheObserver {
    
    /// Collected statistics.
    public struct Statistics: Sendable {
        public var addCount: Int = 0
        public var updateCount: Int = 0
        public var removeCount: Int = 0
        public var evictionCount: Int = 0
        public var expirationCount: Int = 0
        public var clearCount: Int = 0
        public var errorCount: Int = 0
        public var memoryWarningCount: Int = 0
        
        /// Total events.
        public var totalEvents: Int {
            addCount + updateCount + removeCount + evictionCount +
            expirationCount + clearCount + errorCount + memoryWarningCount
        }
    }
    
    /// Current statistics.
    private var stats = Statistics()
    
    public init() {}
    
    nonisolated public func cacheDidChange(event: CacheEvent) {
        Task { await recordEvent(event) }
    }
    
    /// Records an event.
    private func recordEvent(_ event: CacheEvent) {
        switch event {
        case .added:
            stats.addCount += 1
        case .updated:
            stats.updateCount += 1
        case .removed:
            stats.removeCount += 1
        case .evicted:
            stats.evictionCount += 1
        case .expired:
            stats.expirationCount += 1
        case .cleared:
            stats.clearCount += 1
        case .error:
            stats.errorCount += 1
        case .memoryWarning:
            stats.memoryWarningCount += 1
        }
    }
    
    /// Returns current statistics.
    public func getStatistics() -> Statistics {
        stats
    }
    
    /// Resets statistics.
    public func reset() {
        stats = Statistics()
    }
}

// MARK: - Debounced Observer

/// A cache observer that debounces events.
public final class DebouncedObserver: CacheObserver, @unchecked Sendable {
    
    /// The wrapped observer.
    private let wrapped: any CacheObserver
    
    /// Debounce interval.
    private let interval: TimeInterval
    
    /// Pending events.
    private var pendingEvents: [CacheEvent] = []
    
    /// Last flush time.
    private var lastFlush: Date = Date()
    
    /// Lock for thread safety.
    private let lock = NSLock()
    
    /// Creates a debounced observer.
    ///
    /// - Parameters:
    ///   - wrapped: The observer to wrap.
    ///   - interval: Debounce interval in seconds.
    public init(wrapped: any CacheObserver, interval: TimeInterval = 0.5) {
        self.wrapped = wrapped
        self.interval = interval
    }
    
    public func cacheDidChange(event: CacheEvent) {
        lock.lock()
        pendingEvents.append(event)
        
        let now = Date()
        if now.timeIntervalSince(lastFlush) >= interval {
            let events = pendingEvents
            pendingEvents = []
            lastFlush = now
            lock.unlock()
            
            // Flush events
            for e in events {
                wrapped.cacheDidChange(event: e)
            }
        } else {
            lock.unlock()
        }
    }
}
