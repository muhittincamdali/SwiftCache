// CachedURLSession.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Cached URL Session

/// A URL session wrapper with intelligent caching.
///
/// `CachedURLSession` provides automatic response caching for network
/// requests, respecting cache headers and supporting offline access.
///
/// ## Overview
/// Use `CachedURLSession` to automatically cache network responses
/// and reduce redundant network traffic.
///
/// ```swift
/// let session = CachedURLSession(
///     cache: HybridCache(name: "network"),
///     policy: .cacheFirst
/// )
///
/// let (data, response) = try await session.data(from: url)
/// ```
///
/// ## Cache Headers
/// The session respects standard HTTP cache headers:
/// - `Cache-Control`
/// - `Expires`
/// - `ETag`
/// - `Last-Modified`
///
/// ## Policies
/// Configure caching behavior with `NetworkCachePolicy`:
/// - `.cacheFirst` - Return cached data if available
/// - `.networkFirst` - Try network first, fall back to cache
/// - `.cacheOnly` - Only use cached data
/// - `.networkOnly` - Never use cache
public actor CachedURLSession {
    
    // MARK: - Types
    
    /// Cached response data.
    public struct CachedResponse: Codable, Sendable {
        /// Response data.
        public let data: Data
        
        /// HTTP status code.
        public let statusCode: Int
        
        /// Response headers.
        public let headers: [String: String]
        
        /// When the response was cached.
        public let cachedDate: Date
        
        /// ETag for validation.
        public let etag: String?
        
        /// Last-Modified header value.
        public let lastModified: String?
        
        /// Expiration date based on headers.
        public let expiresDate: Date?
        
        /// MIME type.
        public let mimeType: String?
        
        /// Creates a cached response from URL response.
        public init(data: Data, response: HTTPURLResponse) {
            self.data = data
            self.statusCode = response.statusCode
            self.headers = response.allHeaderFields as? [String: String] ?? [:]
            self.cachedDate = Date()
            self.etag = response.value(forHTTPHeaderField: "ETag")
            self.lastModified = response.value(forHTTPHeaderField: "Last-Modified")
            self.mimeType = response.mimeType
            self.expiresDate = Self.parseExpiration(from: response)
        }
        
        /// Parses expiration date from response headers.
        private static func parseExpiration(from response: HTTPURLResponse) -> Date? {
            // Check Cache-Control max-age
            if let cacheControl = response.value(forHTTPHeaderField: "Cache-Control") {
                let components = cacheControl.components(separatedBy: ",")
                for component in components {
                    let trimmed = component.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("max-age=") {
                        let ageString = trimmed.dropFirst(8)
                        if let maxAge = TimeInterval(ageString) {
                            return Date().addingTimeInterval(maxAge)
                        }
                    }
                }
            }
            
            // Check Expires header
            if let expires = response.value(forHTTPHeaderField: "Expires") {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                return formatter.date(from: expires)
            }
            
            return nil
        }
        
        /// Whether the cached response is still fresh.
        public var isFresh: Bool {
            guard let expires = expiresDate else { return true }
            return Date() < expires
        }
        
        /// Age of the cached response.
        public var age: TimeInterval {
            Date().timeIntervalSince(cachedDate)
        }
    }
    
    /// Network cache policy.
    public enum Policy: Sendable {
        /// Return cached data if available and fresh.
        case cacheFirst
        
        /// Try network first, fall back to cache.
        case networkFirst
        
        /// Only use cached data, never network.
        case cacheOnly
        
        /// Never use cache, always network.
        case networkOnly
        
        /// Return stale cache while revalidating.
        case staleWhileRevalidate
    }
    
    // MARK: - Properties
    
    /// Underlying URL session.
    private let session: URLSession
    
    /// Response cache.
    private let cache: any NetworkResponseCache
    
    /// Default cache policy.
    public let defaultPolicy: Policy
    
    /// Default expiration for responses without cache headers.
    public let defaultExpiration: TimeInterval
    
    /// Statistics.
    private var stats = NetworkCacheStatistics()
    
    // MARK: - Initialization
    
    /// Creates a new cached URL session.
    ///
    /// - Parameters:
    ///   - session: URL session to use. Defaults to shared.
    ///   - cache: Response cache implementation.
    ///   - defaultPolicy: Default cache policy.
    ///   - defaultExpiration: Default expiration in seconds.
    public init(
        session: URLSession = .shared,
        cache: any NetworkResponseCache,
        defaultPolicy: Policy = .cacheFirst,
        defaultExpiration: TimeInterval = 300
    ) {
        self.session = session
        self.cache = cache
        self.defaultPolicy = defaultPolicy
        self.defaultExpiration = defaultExpiration
    }
    
    // MARK: - Data Tasks
    
    /// Fetches data from a URL with caching.
    ///
    /// - Parameters:
    ///   - url: URL to fetch.
    ///   - policy: Cache policy. Uses default if nil.
    /// - Returns: Data and response.
    /// - Throws: Network or cache error.
    public func data(
        from url: URL,
        policy: Policy? = nil
    ) async throws -> (Data, URLResponse) {
        let request = URLRequest(url: url)
        return try await data(for: request, policy: policy)
    }
    
    /// Fetches data for a request with caching.
    ///
    /// - Parameters:
    ///   - request: URL request.
    ///   - policy: Cache policy. Uses default if nil.
    /// - Returns: Data and response.
    /// - Throws: Network or cache error.
    public func data(
        for request: URLRequest,
        policy: Policy? = nil
    ) async throws -> (Data, URLResponse) {
        let effectivePolicy = policy ?? defaultPolicy
        let cacheKey = cacheKey(for: request)
        
        switch effectivePolicy {
        case .cacheFirst:
            return try await cacheFirstFetch(request: request, key: cacheKey)
            
        case .networkFirst:
            return try await networkFirstFetch(request: request, key: cacheKey)
            
        case .cacheOnly:
            return try await cacheOnlyFetch(key: cacheKey)
            
        case .networkOnly:
            return try await networkOnlyFetch(request: request, key: cacheKey)
            
        case .staleWhileRevalidate:
            return try await staleWhileRevalidateFetch(request: request, key: cacheKey)
        }
    }
    
    // MARK: - Cache Operations
    
    /// Prefetches URLs into cache.
    ///
    /// - Parameter urls: URLs to prefetch.
    public func prefetch(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = try? await self.data(from: url, policy: .networkFirst)
                }
            }
        }
    }
    
    /// Invalidates cached response for a URL.
    ///
    /// - Parameter url: URL to invalidate.
    public func invalidate(url: URL) async {
        let key = cacheKey(for: URLRequest(url: url))
        await cache.remove(key)
    }
    
    /// Clears all cached responses.
    public func clearCache() async {
        await cache.removeAll()
    }
    
    /// Returns cache statistics.
    public func getStatistics() -> NetworkCacheStatistics {
        stats
    }
    
    // MARK: - Private Methods
    
    /// Generates cache key for a request.
    private func cacheKey(for request: URLRequest) -> String {
        var components = [request.url?.absoluteString ?? ""]
        
        // Include method
        components.append(request.httpMethod ?? "GET")
        
        // Include relevant headers
        if let headers = request.allHTTPHeaderFields {
            let relevantHeaders = ["Accept", "Accept-Language", "Authorization"]
            for header in relevantHeaders {
                if let value = headers[header] {
                    components.append("\(header):\(value)")
                }
            }
        }
        
        return components.joined(separator: "|").sha256Hash
    }
    
    /// Cache-first fetch strategy.
    private func cacheFirstFetch(
        request: URLRequest,
        key: String
    ) async throws -> (Data, URLResponse) {
        // Check cache first
        if let cached = await cache.get(key), cached.isFresh {
            stats.cacheHits += 1
            return (cached.data, createResponse(from: cached, url: request.url!))
        }
        
        // Fall back to network
        return try await networkFetch(request: request, key: key)
    }
    
    /// Network-first fetch strategy.
    private func networkFirstFetch(
        request: URLRequest,
        key: String
    ) async throws -> (Data, URLResponse) {
        do {
            return try await networkFetch(request: request, key: key)
        } catch {
            // Fall back to cache
            if let cached = await cache.get(key) {
                stats.cacheHits += 1
                stats.networkErrors += 1
                return (cached.data, createResponse(from: cached, url: request.url!))
            }
            throw error
        }
    }
    
    /// Cache-only fetch strategy.
    private func cacheOnlyFetch(key: String) async throws -> (Data, URLResponse) {
        guard let cached = await cache.get(key) else {
            stats.cacheMisses += 1
            throw CacheError.keyNotFound(key)
        }
        
        stats.cacheHits += 1
        
        // Create a dummy URL for the response
        let url = URL(string: "cached://\(key)")!
        return (cached.data, createResponse(from: cached, url: url))
    }
    
    /// Network-only fetch strategy.
    private func networkOnlyFetch(
        request: URLRequest,
        key: String
    ) async throws -> (Data, URLResponse) {
        try await networkFetch(request: request, key: key)
    }
    
    /// Stale-while-revalidate fetch strategy.
    private func staleWhileRevalidateFetch(
        request: URLRequest,
        key: String
    ) async throws -> (Data, URLResponse) {
        // Return stale cache immediately if available
        if let cached = await cache.get(key) {
            stats.cacheHits += 1
            
            // Revalidate in background
            Task {
                _ = try? await self.networkFetch(request: request, key: key)
            }
            
            return (cached.data, createResponse(from: cached, url: request.url!))
        }
        
        // No cache, must fetch
        return try await networkFetch(request: request, key: key)
    }
    
    /// Performs network fetch and caches response.
    private func networkFetch(
        request: URLRequest,
        key: String
    ) async throws -> (Data, URLResponse) {
        let (data, response) = try await session.data(for: request)
        
        stats.networkRequests += 1
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return (data, response)
        }
        
        // Cache successful responses
        if (200...299).contains(httpResponse.statusCode) {
            let cached = CachedResponse(data: data, response: httpResponse)
            let expiration = cached.expiresDate.map { CacheExpiration.date($0) }
                ?? .seconds(defaultExpiration)
            await cache.set(key, response: cached, expiration: expiration)
        }
        
        return (data, response)
    }
    
    /// Creates URL response from cached data.
    private func createResponse(from cached: CachedResponse, url: URL) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: cached.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: cached.headers
        )!
    }
}

// MARK: - Network Response Cache Protocol

/// Protocol for network response caching.
public protocol NetworkResponseCache: Sendable {
    /// Retrieves a cached response.
    func get(_ key: String) async -> CachedURLSession.CachedResponse?
    
    /// Stores a response.
    func set(_ key: String, response: CachedURLSession.CachedResponse, expiration: CacheExpiration) async
    
    /// Removes a cached response.
    func remove(_ key: String) async
    
    /// Removes all cached responses.
    func removeAll() async
}

// MARK: - Network Cache Statistics

/// Statistics for network caching.
public struct NetworkCacheStatistics: Sendable {
    /// Cache hit count.
    public var cacheHits: Int = 0
    
    /// Cache miss count.
    public var cacheMisses: Int = 0
    
    /// Network request count.
    public var networkRequests: Int = 0
    
    /// Network error count.
    public var networkErrors: Int = 0
    
    /// Cache hit rate.
    public var hitRate: Double {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return 0 }
        return Double(cacheHits) / Double(total) * 100
    }
    
    /// Bandwidth saved (estimated).
    public var bandwidthSaved: Int {
        cacheHits * 50_000 // Rough estimate of 50KB per request
    }
}
