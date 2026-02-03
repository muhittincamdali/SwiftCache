// ResponseCache.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Response Cache

/// A cache specifically designed for API responses.
///
/// `ResponseCache` provides intelligent caching for HTTP responses
/// with support for ETags, conditional requests, and automatic
/// invalidation based on response headers.
///
/// ## Overview
/// Use `ResponseCache` for caching JSON API responses with proper
/// HTTP semantics.
///
/// ```swift
/// let cache = try ResponseCache(name: "api")
///
/// // Cache a response
/// await cache.store(response, for: request)
///
/// // Retrieve cached response
/// if let cached = await cache.response(for: request) {
///     // Use cached data
/// }
/// ```
///
/// ## Features
/// - ETag-based validation
/// - Cache-Control header parsing
/// - Automatic expiration
/// - Request fingerprinting
public actor ResponseCache: NetworkResponseCache {
    
    // MARK: - Types
    
    /// Cached response entry.
    private struct CacheEntry: Codable, Sendable {
        let response: CachedURLSession.CachedResponse
        let requestFingerprint: String
        let creationDate: Date
        var validationCount: Int
        
        var isExpired: Bool {
            guard let expires = response.expiresDate else { return false }
            return Date() > expires
        }
    }
    
    /// Request matching options.
    public struct MatchOptions: Sendable {
        /// Whether to include query parameters in matching.
        public var includeQuery: Bool
        
        /// Headers to include in fingerprint.
        public var significantHeaders: Set<String>
        
        /// Whether to match HTTP method.
        public var matchMethod: Bool
        
        /// Default options.
        public static let `default` = MatchOptions(
            includeQuery: true,
            significantHeaders: ["Accept", "Accept-Language"],
            matchMethod: true
        )
        
        /// Strict options (includes more headers).
        public static let strict = MatchOptions(
            includeQuery: true,
            significantHeaders: ["Accept", "Accept-Language", "Authorization", "Content-Type"],
            matchMethod: true
        )
        
        /// Loose options (URL only).
        public static let loose = MatchOptions(
            includeQuery: false,
            significantHeaders: [],
            matchMethod: false
        )
        
        /// Creates match options.
        public init(
            includeQuery: Bool = true,
            significantHeaders: Set<String> = [],
            matchMethod: Bool = true
        ) {
            self.includeQuery = includeQuery
            self.significantHeaders = significantHeaders
            self.matchMethod = matchMethod
        }
    }
    
    // MARK: - Properties
    
    /// Cache name.
    public let name: String
    
    /// Internal storage.
    private var storage: [String: CacheEntry] = [:]
    
    /// Maximum entries.
    public let maxEntries: Int
    
    /// Matching options.
    public let matchOptions: MatchOptions
    
    /// Default expiration.
    public let defaultExpiration: TimeInterval
    
    /// Disk cache directory.
    private let diskDirectory: URL?
    
    /// File manager.
    private let fileManager: FileManager
    
    /// Statistics.
    private var stats = ResponseCacheStatistics()
    
    // MARK: - Initialization
    
    /// Creates a new response cache.
    ///
    /// - Parameters:
    ///   - name: Cache name.
    ///   - maxEntries: Maximum number of entries.
    ///   - matchOptions: Request matching options.
    ///   - defaultExpiration: Default expiration in seconds.
    ///   - persistToDisk: Whether to persist to disk.
    public init(
        name: String = "responses",
        maxEntries: Int = 1000,
        matchOptions: MatchOptions = .default,
        defaultExpiration: TimeInterval = 300,
        persistToDisk: Bool = false
    ) throws {
        self.name = name
        self.maxEntries = maxEntries
        self.matchOptions = matchOptions
        self.defaultExpiration = defaultExpiration
        self.fileManager = FileManager.default
        
        if persistToDisk {
            let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.diskDirectory = caches.appendingPathComponent("SwiftCache/Responses/\(name)")
            try fileManager.createDirectory(at: diskDirectory!, withIntermediateDirectories: true)
            loadFromDisk()
        } else {
            self.diskDirectory = nil
        }
    }
    
    // MARK: - NetworkResponseCache Protocol
    
    /// Retrieves a cached response.
    ///
    /// - Parameter key: Cache key.
    /// - Returns: Cached response or nil.
    public func get(_ key: String) async -> CachedURLSession.CachedResponse? {
        guard let entry = storage[key] else {
            stats.misses += 1
            return nil
        }
        
        if entry.isExpired {
            storage.removeValue(forKey: key)
            stats.expirations += 1
            return nil
        }
        
        stats.hits += 1
        return entry.response
    }
    
    /// Stores a response.
    ///
    /// - Parameters:
    ///   - key: Cache key.
    ///   - response: Response to cache.
    ///   - expiration: Expiration policy.
    public func set(_ key: String, response: CachedURLSession.CachedResponse, expiration: CacheExpiration) async {
        // Evict if at capacity
        if storage.count >= maxEntries {
            evictOldest()
        }
        
        let entry = CacheEntry(
            response: response,
            requestFingerprint: key,
            creationDate: Date(),
            validationCount: 0
        )
        
        storage[key] = entry
        stats.stores += 1
        
        if diskDirectory != nil {
            persistToDisk()
        }
    }
    
    /// Removes a cached response.
    ///
    /// - Parameter key: Cache key.
    public func remove(_ key: String) async {
        storage.removeValue(forKey: key)
        
        if diskDirectory != nil {
            persistToDisk()
        }
    }
    
    /// Removes all cached responses.
    public func removeAll() async {
        storage.removeAll()
        
        if let dir = diskDirectory {
            try? fileManager.removeItem(at: dir)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Request-Based Operations
    
    /// Retrieves cached response for a request.
    ///
    /// - Parameter request: URL request.
    /// - Returns: Cached response or nil.
    public func response(for request: URLRequest) -> CachedURLSession.CachedResponse? {
        let key = fingerprint(for: request)
        guard let entry = storage[key], !entry.isExpired else {
            return nil
        }
        return entry.response
    }
    
    /// Stores response for a request.
    ///
    /// - Parameters:
    ///   - response: Cached response.
    ///   - request: Original request.
    public func store(_ response: CachedURLSession.CachedResponse, for request: URLRequest) {
        let key = fingerprint(for: request)
        
        if storage.count >= maxEntries {
            evictOldest()
        }
        
        let entry = CacheEntry(
            response: response,
            requestFingerprint: key,
            creationDate: Date(),
            validationCount: 0
        )
        
        storage[key] = entry
    }
    
    /// Invalidates cached response for a request.
    ///
    /// - Parameter request: URL request.
    public func invalidate(for request: URLRequest) {
        let key = fingerprint(for: request)
        storage.removeValue(forKey: key)
    }
    
    /// Invalidates all responses for a URL path.
    ///
    /// - Parameter path: URL path prefix.
    public func invalidate(pathPrefix: String) {
        let keysToRemove = storage.keys.filter { key in
            key.contains(pathPrefix)
        }
        
        for key in keysToRemove {
            storage.removeValue(forKey: key)
        }
    }
    
    // MARK: - Validation
    
    /// Checks if a request has a valid cached response.
    ///
    /// - Parameter request: URL request.
    /// - Returns: True if valid cached response exists.
    public func hasValidCache(for request: URLRequest) -> Bool {
        let key = fingerprint(for: request)
        guard let entry = storage[key] else { return false }
        return !entry.isExpired
    }
    
    /// Returns the ETag for a cached request if available.
    ///
    /// - Parameter request: URL request.
    /// - Returns: ETag string or nil.
    public func etag(for request: URLRequest) -> String? {
        let key = fingerprint(for: request)
        return storage[key]?.response.etag
    }
    
    /// Creates a conditional request with If-None-Match header.
    ///
    /// - Parameter request: Original request.
    /// - Returns: Request with conditional headers, or original if no ETag.
    public func conditionalRequest(from request: URLRequest) -> URLRequest {
        var modifiedRequest = request
        
        let key = fingerprint(for: request)
        if let etag = storage[key]?.response.etag {
            modifiedRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        if let lastModified = storage[key]?.response.lastModified {
            modifiedRequest.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }
        
        return modifiedRequest
    }
    
    // MARK: - Statistics
    
    /// Returns cache statistics.
    public func getStatistics() -> ResponseCacheStatistics {
        var s = stats
        s.entryCount = storage.count
        return s
    }
    
    /// Resets statistics.
    public func resetStatistics() {
        stats = ResponseCacheStatistics()
    }
    
    // MARK: - Private Methods
    
    /// Generates fingerprint for a request.
    private func fingerprint(for request: URLRequest) -> String {
        var components: [String] = []
        
        // URL
        if let url = request.url {
            if matchOptions.includeQuery {
                components.append(url.absoluteString)
            } else {
                components.append(url.scheme ?? "")
                components.append(url.host ?? "")
                components.append(url.path)
            }
        }
        
        // Method
        if matchOptions.matchMethod {
            components.append(request.httpMethod ?? "GET")
        }
        
        // Headers
        if let headers = request.allHTTPHeaderFields {
            for header in matchOptions.significantHeaders.sorted() {
                if let value = headers[header] {
                    components.append("\(header):\(value)")
                }
            }
        }
        
        return components.joined(separator: "|").sha256Hash
    }
    
    /// Evicts the oldest entry.
    private func evictOldest() {
        guard let oldest = storage.min(by: { $0.value.creationDate < $1.value.creationDate }) else {
            return
        }
        storage.removeValue(forKey: oldest.key)
        stats.evictions += 1
    }
    
    /// Persists storage to disk.
    private func persistToDisk() {
        guard let dir = diskDirectory else { return }
        let path = dir.appendingPathComponent("cache.json")
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(storage)
            try data.write(to: path)
        } catch {
            // Ignore errors
        }
    }
    
    /// Loads storage from disk.
    private func loadFromDisk() {
        guard let dir = diskDirectory else { return }
        let path = dir.appendingPathComponent("cache.json")
        
        guard let data = fileManager.contents(atPath: path.path) else { return }
        
        do {
            let decoder = JSONDecoder()
            storage = try decoder.decode([String: CacheEntry].self, from: data)
        } catch {
            storage = [:]
        }
    }
}

// MARK: - Response Cache Statistics

/// Statistics for response cache.
public struct ResponseCacheStatistics: Sendable {
    /// Cache hits.
    public var hits: Int = 0
    
    /// Cache misses.
    public var misses: Int = 0
    
    /// Stores.
    public var stores: Int = 0
    
    /// Evictions.
    public var evictions: Int = 0
    
    /// Expirations.
    public var expirations: Int = 0
    
    /// Current entry count.
    public var entryCount: Int = 0
    
    /// Hit rate.
    public var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total) * 100
    }
}
