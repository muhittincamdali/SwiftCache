import Foundation

/// Main entry point for the SwiftCache ecosystem.
public enum SwiftCache {
    public static let version = "2.0.0"
}

/// A protocol for cache layers
public protocol CacheLayer: Sendable {
    associatedtype Key: Hashable & Sendable
    associatedtype Value: Sendable
    
    func set(_ value: Value, forKey key: Key) async
    func get(forKey key: Key) async -> Value?
    func remove(forKey key: Key) async
    func clear() async
}
