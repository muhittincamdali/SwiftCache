// DiskCache.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Disk Cache

/// A persistent cache that stores data on disk.
///
/// `DiskCache` provides persistent storage for cached data, surviving
/// app restarts. It supports automatic cleanup, size limits, and
/// optional encryption.
///
/// ## Overview
/// Use `DiskCache` when you need cached data to persist across app
/// launches or when data is too large for memory.
///
/// ```swift
/// let cache = try DiskCache<String, Data>(
///     name: "images",
///     maxSize: 100 * 1024 * 1024  // 100 MB
/// )
///
/// // Store data
/// await cache.set("image_123", value: imageData)
///
/// // Data persists across app launches
/// let data = await cache.get("image_123")
/// ```
///
/// ## File Structure
/// The cache creates a directory with the following structure:
/// ```
/// CacheName/
/// ├── metadata.plist
/// ├── data/
/// │   ├── a1b2c3d4.cache
/// │   └── e5f6g7h8.cache
/// └── temp/
/// ```
///
/// ## Thread Safety
/// All operations are thread-safe via actor isolation.
public actor DiskCache<Key: Hashable & Sendable & CustomStringConvertible, Value: Codable & Sendable> {
    
    // MARK: - Types
    
    /// Metadata for a cached file.
    private struct FileMetadata: Codable, Sendable {
        let key: String
        let size: Int
        let creationDate: Date
        var lastAccessDate: Date
        var accessCount: Int
        var expiration: Date?
        
        var isExpired: Bool {
            guard let exp = expiration else { return false }
            return Date() > exp
        }
    }
    
    // MARK: - Properties
    
    /// Name of the cache.
    public let name: String
    
    /// Root directory for cache storage.
    public let directory: URL
    
    /// Directory for cached data files.
    private let dataDirectory: URL
    
    /// Directory for temporary files.
    private let tempDirectory: URL
    
    /// Path to metadata file.
    private let metadataPath: URL
    
    /// Maximum disk space in bytes.
    public let maxSize: Int?
    
    /// File manager instance.
    private let fileManager: FileManager
    
    /// Serializer for encoding/decoding values.
    private let serializer: any CacheSerializer
    
    /// In-memory metadata cache.
    private var metadata: [String: FileMetadata] = [:]
    
    /// Current total size on disk.
    private var currentSize: Int = 0
    
    /// Statistics.
    private var stats = CacheStatistics()
    
    /// Cleanup task.
    private var cleanupTask: Task<Void, Never>?
    
    /// File protection level.
    private let fileProtection: FileProtectionType
    
    // MARK: - Initialization
    
    /// Creates a new disk cache.
    ///
    /// - Parameters:
    ///   - name: Unique name for the cache.
    ///   - directory: Base directory (defaults to Caches directory).
    ///   - maxSize: Maximum disk space in bytes.
    ///   - serializer: Serializer for encoding/decoding.
    ///   - fileProtection: File protection level.
    ///   - cleanupInterval: Interval for cleanup operations.
    /// - Throws: An error if directory creation fails.
    public init(
        name: String,
        directory: URL? = nil,
        maxSize: Int? = 500 * 1024 * 1024,
        serializer: any CacheSerializer = JSONCacheSerializer(),
        fileProtection: FileProtectionType = .completeUntilFirstUserAuthentication,
        cleanupInterval: TimeInterval = 300
    ) throws {
        self.name = name
        self.maxSize = maxSize
        self.serializer = serializer
        self.fileProtection = fileProtection
        self.fileManager = FileManager.default
        
        // Set up directories
        let baseDir = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.directory = baseDir.appendingPathComponent("SwiftCache/\(name)", isDirectory: true)
        self.dataDirectory = self.directory.appendingPathComponent("data", isDirectory: true)
        self.tempDirectory = self.directory.appendingPathComponent("temp", isDirectory: true)
        self.metadataPath = self.directory.appendingPathComponent("metadata.json")
        
        // Create directories
        try fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Load existing metadata
        loadMetadata()
        
        // Start cleanup timer
        startCleanupTimer(interval: cleanupInterval)
    }
    
    deinit {
        cleanupTask?.cancel()
    }
    
    // MARK: - Cache Operations
    
    /// Retrieves a value from the disk cache.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or `nil` if not found or expired.
    public func get(_ key: Key) async -> Value? {
        let keyString = key.description
        
        guard var meta = metadata[keyString] else {
            stats.missCount += 1
            return nil
        }
        
        // Check expiration
        if meta.isExpired {
            await remove(key)
            stats.missCount += 1
            stats.expirationCount += 1
            return nil
        }
        
        // Read file
        let filePath = dataFilePath(for: keyString)
        
        guard let data = fileManager.contents(atPath: filePath.path) else {
            metadata.removeValue(forKey: keyString)
            stats.missCount += 1
            return nil
        }
        
        // Decode value
        do {
            let value: Value = try serializer.decode(data)
            
            // Update access metadata
            meta.lastAccessDate = Date()
            meta.accessCount += 1
            metadata[keyString] = meta
            
            stats.hitCount += 1
            return value
        } catch {
            stats.missCount += 1
            return nil
        }
    }
    
    /// Stores a value to the disk cache.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    ///   - expiration: Optional expiration policy.
    public func set(_ key: Key, value: Value, expiration: CacheExpiration? = nil) async throws {
        let keyString = key.description
        
        // Encode value
        let data = try serializer.encode(value)
        let size = data.count
        
        // Check if we need to evict
        if let max = maxSize, currentSize + size > max {
            await evictToFit(requiredSize: size)
        }
        
        // Write to temp first, then move (atomic)
        let tempPath = tempDirectory.appendingPathComponent(UUID().uuidString)
        let finalPath = dataFilePath(for: keyString)
        
        try data.write(to: tempPath)
        
        // Remove existing file if present
        if let existing = metadata[keyString] {
            currentSize -= existing.size
            try? fileManager.removeItem(at: finalPath)
        }
        
        try fileManager.moveItem(at: tempPath, to: finalPath)
        
        // Update metadata
        let meta = FileMetadata(
            key: keyString,
            size: size,
            creationDate: Date(),
            lastAccessDate: Date(),
            accessCount: 1,
            expiration: expiration?.expirationDate
        )
        metadata[keyString] = meta
        currentSize += size
        
        stats.itemCount = metadata.count
        stats.totalBytes = currentSize
        
        // Persist metadata periodically
        saveMetadata()
    }
    
    /// Removes a value from the disk cache.
    ///
    /// - Parameter key: The key to remove.
    public func remove(_ key: Key) async {
        let keyString = key.description
        
        guard let meta = metadata.removeValue(forKey: keyString) else { return }
        
        let filePath = dataFilePath(for: keyString)
        try? fileManager.removeItem(at: filePath)
        
        currentSize -= meta.size
        stats.itemCount = metadata.count
        stats.totalBytes = currentSize
        
        saveMetadata()
    }
    
    /// Removes all cached data.
    public func removeAll() async {
        // Remove all data files
        try? fileManager.removeItem(at: dataDirectory)
        try? fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        
        metadata.removeAll()
        currentSize = 0
        
        stats.itemCount = 0
        stats.totalBytes = 0
        
        saveMetadata()
    }
    
    /// Checks if a key exists in the cache.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists and is not expired.
    public func contains(_ key: Key) -> Bool {
        let keyString = key.description
        guard let meta = metadata[keyString] else { return false }
        return !meta.isExpired
    }
    
    /// Returns the number of cached items.
    public var count: Int {
        metadata.count
    }
    
    /// Returns the total size of cached data in bytes.
    public var totalSize: Int {
        currentSize
    }
    
    // MARK: - Extended Operations
    
    /// Removes all expired entries.
    ///
    /// - Returns: Number of entries removed.
    @discardableResult
    public func removeExpired() async -> Int {
        var removed = 0
        var keysToRemove: [String] = []
        
        for (key, meta) in metadata where meta.isExpired {
            keysToRemove.append(key)
        }
        
        for key in keysToRemove {
            if let meta = metadata.removeValue(forKey: key) {
                let filePath = dataFilePath(for: key)
                try? fileManager.removeItem(at: filePath)
                currentSize -= meta.size
                removed += 1
            }
        }
        
        if removed > 0 {
            stats.expirationCount += removed
            stats.itemCount = metadata.count
            stats.totalBytes = currentSize
            saveMetadata()
        }
        
        return removed
    }
    
    /// Returns all cached keys.
    public var keys: [String] {
        Array(metadata.keys)
    }
    
    /// Returns cache statistics.
    public func getStatistics() -> CacheStatistics {
        stats
    }
    
    /// Verifies cache integrity.
    ///
    /// - Returns: Number of corrupted entries removed.
    @discardableResult
    public func verifyIntegrity() async -> Int {
        var removed = 0
        
        for (key, meta) in metadata {
            let filePath = dataFilePath(for: key)
            
            // Check file exists
            guard fileManager.fileExists(atPath: filePath.path) else {
                metadata.removeValue(forKey: key)
                currentSize -= meta.size
                removed += 1
                continue
            }
            
            // Verify file size
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath.path),
               let fileSize = attrs[.size] as? Int,
               fileSize != meta.size {
                // Size mismatch - corrupted
                try? fileManager.removeItem(at: filePath)
                metadata.removeValue(forKey: key)
                currentSize -= meta.size
                removed += 1
            }
        }
        
        if removed > 0 {
            stats.itemCount = metadata.count
            stats.totalBytes = currentSize
            saveMetadata()
        }
        
        return removed
    }
    
    /// Computes the total disk usage.
    ///
    /// - Returns: Total bytes used on disk.
    public func computeDiskUsage() -> Int {
        var total = 0
        
        guard let enumerator = fileManager.enumerator(
            at: dataDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += size
            }
        }
        
        return total
    }
    
    // MARK: - Private Methods
    
    /// Returns the file path for a cache key.
    private func dataFilePath(for key: String) -> URL {
        let hash = key.sha256Hash
        return dataDirectory.appendingPathComponent("\(hash).cache")
    }
    
    /// Loads metadata from disk.
    private func loadMetadata() {
        guard let data = fileManager.contents(atPath: metadataPath.path) else { return }
        
        do {
            let decoder = JSONDecoder()
            let loaded = try decoder.decode([String: FileMetadata].self, from: data)
            metadata = loaded
            currentSize = loaded.values.reduce(0) { $0 + $1.size }
            stats.itemCount = metadata.count
            stats.totalBytes = currentSize
        } catch {
            // Metadata corrupted, start fresh
            metadata = [:]
            currentSize = 0
        }
    }
    
    /// Saves metadata to disk.
    private func saveMetadata() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(metadata)
            try data.write(to: metadataPath)
        } catch {
            // Ignore save errors
        }
    }
    
    /// Evicts items to make room for new data.
    private func evictToFit(requiredSize: Int) async {
        guard let max = maxSize else { return }
        
        let targetSize = max - requiredSize
        
        // Sort by LRU
        let sorted = metadata.sorted { $0.value.lastAccessDate < $1.value.lastAccessDate }
        
        for (key, meta) in sorted {
            guard currentSize > targetSize else { break }
            
            let filePath = dataFilePath(for: key)
            try? fileManager.removeItem(at: filePath)
            metadata.removeValue(forKey: key)
            currentSize -= meta.size
            stats.evictionCount += 1
        }
        
        stats.itemCount = metadata.count
        stats.totalBytes = currentSize
        saveMetadata()
    }
    
    /// Starts the periodic cleanup timer.
    private func startCleanupTimer(interval: TimeInterval) {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await self?.removeExpired()
            }
        }
    }
}
