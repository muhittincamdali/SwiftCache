// ExpirationPolicy.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Expiration Policy Protocol

/// A protocol for defining custom expiration policies.
///
/// `ExpirationPolicyProtocol` allows you to create complex expiration
/// rules beyond simple time-based expiration.
///
/// ## Overview
/// Implement this protocol to create custom expiration logic.
///
/// ```swift
/// struct AccessCountExpiration: ExpirationPolicyProtocol {
///     let maxAccesses: Int
///
///     func shouldExpire(metadata: CacheMetadata) -> Bool {
///         metadata.accessCount >= maxAccesses
///     }
/// }
/// ```
public protocol ExpirationPolicyProtocol: Sendable {
    /// Determines if an entry should expire.
    ///
    /// - Parameter metadata: Entry metadata.
    /// - Returns: True if the entry should be considered expired.
    func shouldExpire(metadata: CacheMetadata) -> Bool
    
    /// Returns the next expiration check date.
    ///
    /// - Parameter metadata: Entry metadata.
    /// - Returns: When to check expiration again.
    func nextCheckDate(metadata: CacheMetadata) -> Date?
}

// MARK: - Default Implementation

public extension ExpirationPolicyProtocol {
    func nextCheckDate(metadata: CacheMetadata) -> Date? {
        // Default: check in 60 seconds
        Date().addingTimeInterval(60)
    }
}

// MARK: - Time-Based Expiration Policy

/// A time-based expiration policy.
///
/// Expires entries after a specified duration from creation or
/// last access.
public struct TimeBasedExpirationPolicy: ExpirationPolicyProtocol {
    
    /// The duration before expiration.
    public let duration: TimeInterval
    
    /// Whether to use last access time instead of creation time.
    public let fromLastAccess: Bool
    
    /// Creates a time-based expiration policy.
    ///
    /// - Parameters:
    ///   - duration: Expiration duration in seconds.
    ///   - fromLastAccess: Use last access time. Default false.
    public init(duration: TimeInterval, fromLastAccess: Bool = false) {
        self.duration = duration
        self.fromLastAccess = fromLastAccess
    }
    
    /// Convenience initializer for common durations.
    public static func seconds(_ seconds: TimeInterval) -> Self {
        Self(duration: seconds)
    }
    
    public static func minutes(_ minutes: Double) -> Self {
        Self(duration: minutes * 60)
    }
    
    public static func hours(_ hours: Double) -> Self {
        Self(duration: hours * 3600)
    }
    
    public static func days(_ days: Double) -> Self {
        Self(duration: days * 86400)
    }
    
    public func shouldExpire(metadata: CacheMetadata) -> Bool {
        let referenceDate = fromLastAccess ? metadata.lastAccessDate : metadata.creationDate
        return Date().timeIntervalSince(referenceDate) >= duration
    }
    
    public func nextCheckDate(metadata: CacheMetadata) -> Date? {
        let referenceDate = fromLastAccess ? metadata.lastAccessDate : metadata.creationDate
        return referenceDate.addingTimeInterval(duration)
    }
}

// MARK: - Access Count Expiration Policy

/// Expires entries after a specified number of accesses.
public struct AccessCountExpirationPolicy: ExpirationPolicyProtocol {
    
    /// Maximum access count before expiration.
    public let maxAccessCount: Int
    
    /// Creates an access count expiration policy.
    ///
    /// - Parameter maxAccessCount: Maximum number of accesses.
    public init(maxAccessCount: Int) {
        self.maxAccessCount = maxAccessCount
    }
    
    public func shouldExpire(metadata: CacheMetadata) -> Bool {
        metadata.accessCount >= maxAccessCount
    }
}

// MARK: - Size-Based Expiration Policy

/// Expires entries that exceed a size threshold.
public struct SizeExpirationPolicy: ExpirationPolicyProtocol {
    
    /// Maximum size in bytes.
    public let maxSizeBytes: Int
    
    /// Creates a size-based expiration policy.
    ///
    /// - Parameter maxSizeBytes: Maximum entry size in bytes.
    public init(maxSizeBytes: Int) {
        self.maxSizeBytes = maxSizeBytes
    }
    
    public func shouldExpire(metadata: CacheMetadata) -> Bool {
        metadata.sizeInBytes > maxSizeBytes
    }
}

// MARK: - Composite Expiration Policy

/// Combines multiple expiration policies.
public struct CompositeExpirationPolicy: ExpirationPolicyProtocol {
    
    /// Combination mode.
    public enum Mode: Sendable {
        /// Expires if ANY policy triggers.
        case any
        
        /// Expires only if ALL policies trigger.
        case all
    }
    
    /// The policies to combine.
    public let policies: [any ExpirationPolicyProtocol]
    
    /// The combination mode.
    public let mode: Mode
    
    /// Creates a composite policy.
    ///
    /// - Parameters:
    ///   - policies: Policies to combine.
    ///   - mode: Combination mode.
    public init(policies: [any ExpirationPolicyProtocol], mode: Mode = .any) {
        self.policies = policies
        self.mode = mode
    }
    
    public func shouldExpire(metadata: CacheMetadata) -> Bool {
        switch mode {
        case .any:
            return policies.contains { $0.shouldExpire(metadata: metadata) }
        case .all:
            return policies.allSatisfy { $0.shouldExpire(metadata: metadata) }
        }
    }
    
    public func nextCheckDate(metadata: CacheMetadata) -> Date? {
        let dates = policies.compactMap { $0.nextCheckDate(metadata: metadata) }
        return dates.min()
    }
}

// MARK: - Sliding Expiration Policy

/// A sliding window expiration that resets on each access.
public struct SlidingExpirationPolicy: ExpirationPolicyProtocol {
    
    /// The sliding window duration.
    public let windowDuration: TimeInterval
    
    /// Maximum absolute lifetime.
    public let maxLifetime: TimeInterval?
    
    /// Creates a sliding expiration policy.
    ///
    /// - Parameters:
    ///   - windowDuration: Duration of the sliding window.
    ///   - maxLifetime: Maximum total lifetime (optional).
    public init(windowDuration: TimeInterval, maxLifetime: TimeInterval? = nil) {
        self.windowDuration = windowDuration
        self.maxLifetime = maxLifetime
    }
    
    public func shouldExpire(metadata: CacheMetadata) -> Bool {
        // Check sliding window
        let windowExpired = Date().timeIntervalSince(metadata.lastAccessDate) >= windowDuration
        
        // Check absolute lifetime
        if let max = maxLifetime {
            let lifetimeExpired = Date().timeIntervalSince(metadata.creationDate) >= max
            return windowExpired || lifetimeExpired
        }
        
        return windowExpired
    }
    
    public func nextCheckDate(metadata: CacheMetadata) -> Date? {
        metadata.lastAccessDate.addingTimeInterval(windowDuration)
    }
}

// MARK: - Conditional Expiration Policy

/// An expiration policy with custom conditions.
public struct ConditionalExpirationPolicy: ExpirationPolicyProtocol {
    
    /// The condition closure.
    private let condition: @Sendable (CacheMetadata) -> Bool
    
    /// Creates a conditional expiration policy.
    ///
    /// - Parameter condition: Condition that returns true when expired.
    public init(condition: @escaping @Sendable (CacheMetadata) -> Bool) {
        self.condition = condition
    }
    
    public func shouldExpire(metadata: CacheMetadata) -> Bool {
        condition(metadata)
    }
}

// MARK: - Never Expire Policy

/// A policy that never expires entries.
public struct NeverExpirePolicy: ExpirationPolicyProtocol {
    
    /// Shared instance.
    public static let shared = NeverExpirePolicy()
    
    public init() {}
    
    public func shouldExpire(metadata: CacheMetadata) -> Bool {
        false
    }
    
    public func nextCheckDate(metadata: CacheMetadata) -> Date? {
        nil
    }
}

// MARK: - Tag-Based Expiration Policy

/// Expires entries based on tags.
public struct TagExpirationPolicy: ExpirationPolicyProtocol {
    
    /// Tags that trigger expiration.
    public let expiredTags: Set<String>
    
    /// Creates a tag-based expiration policy.
    ///
    /// - Parameter expiredTags: Tags that mark entries as expired.
    public init(expiredTags: Set<String>) {
        self.expiredTags = expiredTags
    }
    
    public func shouldExpire(metadata: CacheMetadata) -> Bool {
        !metadata.tags.isDisjoint(with: expiredTags)
    }
}
