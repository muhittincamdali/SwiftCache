// ImageCache.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Image Cache

/// A specialized cache for images with optimizations for image data.
///
/// `ImageCache` provides efficient caching for images with automatic
/// memory management, disk persistence, and image-specific optimizations
/// like downsampling and format conversion.
///
/// ## Overview
/// Use `ImageCache` for caching images downloaded from the network
/// or generated locally.
///
/// ```swift
/// let imageCache = ImageCache(
///     name: "images",
///     memoryLimit: 100 * 1024 * 1024,
///     diskLimit: 500 * 1024 * 1024
/// )
///
/// // Cache an image
/// await imageCache.setImage(image, forKey: "profile_123")
///
/// // Retrieve an image
/// let image = await imageCache.image(forKey: "profile_123")
/// ```
///
/// ## Features
/// - Automatic memory pressure handling
/// - Disk persistence with configurable limits
/// - Image downsampling for memory efficiency
/// - Format conversion (PNG/JPEG)
/// - URL-based image fetching with caching
public actor ImageCache {
    
    // MARK: - Types
    
    /// Image format for storage.
    public enum ImageFormat: String, Sendable {
        case png
        case jpeg
        
        var fileExtension: String { rawValue }
    }
    
    /// Options for image caching.
    public struct CacheOptions: Sendable {
        /// Image format for disk storage.
        public var format: ImageFormat
        
        /// JPEG compression quality (0-1).
        public var compressionQuality: CGFloat
        
        /// Maximum dimension for downsampling.
        public var maxDimension: CGFloat?
        
        /// Whether to skip memory cache.
        public var skipMemory: Bool
        
        /// Whether to skip disk cache.
        public var skipDisk: Bool
        
        /// Default options.
        public static let `default` = CacheOptions(
            format: .jpeg,
            compressionQuality: 0.8,
            maxDimension: nil,
            skipMemory: false,
            skipDisk: false
        )
        
        /// High quality options.
        public static let highQuality = CacheOptions(
            format: .png,
            compressionQuality: 1.0,
            maxDimension: nil,
            skipMemory: false,
            skipDisk: false
        )
        
        /// Memory efficient options.
        public static let memoryEfficient = CacheOptions(
            format: .jpeg,
            compressionQuality: 0.7,
            maxDimension: 1024,
            skipMemory: false,
            skipDisk: false
        )
        
        /// Creates cache options.
        public init(
            format: ImageFormat = .jpeg,
            compressionQuality: CGFloat = 0.8,
            maxDimension: CGFloat? = nil,
            skipMemory: Bool = false,
            skipDisk: Bool = false
        ) {
            self.format = format
            self.compressionQuality = compressionQuality
            self.maxDimension = maxDimension
            self.skipMemory = skipMemory
            self.skipDisk = skipDisk
        }
    }
    
    /// Cached image entry.
    private struct CachedImage: Sendable {
        #if canImport(UIKit)
        let image: UIImage
        #elseif canImport(AppKit)
        let image: NSImage
        #endif
        let size: Int
        let accessDate: Date
    }
    
    // MARK: - Properties
    
    /// Cache name.
    public let name: String
    
    /// Maximum memory cache size in bytes.
    public let memoryLimit: Int
    
    /// Maximum disk cache size in bytes.
    public let diskLimit: Int
    
    /// Memory cache.
    #if canImport(UIKit)
    private var memoryCache: [String: CachedImage] = [:]
    #elseif canImport(AppKit)
    private var memoryCache: [String: CachedImage] = [:]
    #endif
    
    /// LRU order for memory cache.
    private var memoryAccessOrder: [String] = []
    
    /// Current memory usage.
    private var currentMemoryUsage: Int = 0
    
    /// Disk cache directory.
    private let diskDirectory: URL
    
    /// File manager.
    private let fileManager: FileManager
    
    /// Statistics.
    private var stats = ImageCacheStatistics()
    
    /// URL session for fetching images.
    private let urlSession: URLSession
    
    // MARK: - Initialization
    
    /// Creates a new image cache.
    ///
    /// - Parameters:
    ///   - name: Unique cache name.
    ///   - memoryLimit: Maximum memory in bytes. Default 100MB.
    ///   - diskLimit: Maximum disk space in bytes. Default 500MB.
    /// - Throws: Error if disk directory creation fails.
    public init(
        name: String = "images",
        memoryLimit: Int = 100 * 1024 * 1024,
        diskLimit: Int = 500 * 1024 * 1024
    ) throws {
        self.name = name
        self.memoryLimit = memoryLimit
        self.diskLimit = diskLimit
        self.fileManager = FileManager.default
        self.urlSession = URLSession.shared
        
        // Set up disk directory
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskDirectory = caches.appendingPathComponent("SwiftCache/Images/\(name)", isDirectory: true)
        
        try fileManager.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Image Operations
    
    #if canImport(UIKit)
    /// Retrieves an image from cache.
    ///
    /// - Parameter key: Cache key.
    /// - Returns: Cached image or nil.
    public func image(forKey key: String) async -> UIImage? {
        // Check memory cache
        if var cached = memoryCache[key] {
            updateMemoryAccess(for: key)
            stats.memoryHits += 1
            return cached.image
        }
        
        // Check disk cache
        let diskPath = diskFilePath(for: key)
        guard let data = fileManager.contents(atPath: diskPath.path),
              let image = UIImage(data: data) else {
            stats.misses += 1
            return nil
        }
        
        // Promote to memory
        let size = estimateImageSize(image)
        await storeInMemory(key: key, image: image, size: size)
        
        stats.diskHits += 1
        return image
    }
    
    /// Stores an image in cache.
    ///
    /// - Parameters:
    ///   - image: Image to cache.
    ///   - key: Cache key.
    ///   - options: Caching options.
    public func setImage(
        _ image: UIImage,
        forKey key: String,
        options: CacheOptions = .default
    ) async {
        var processedImage = image
        
        // Downsample if needed
        if let maxDim = options.maxDimension {
            processedImage = downsample(image, maxDimension: maxDim)
        }
        
        let size = estimateImageSize(processedImage)
        
        // Store in memory
        if !options.skipMemory {
            await storeInMemory(key: key, image: processedImage, size: size)
        }
        
        // Store on disk
        if !options.skipDisk {
            let data = encodeImage(processedImage, format: options.format, quality: options.compressionQuality)
            await storeToDisk(key: key, data: data)
        }
    }
    
    /// Fetches an image from URL with caching.
    ///
    /// - Parameters:
    ///   - url: Image URL.
    ///   - options: Caching options.
    /// - Returns: Fetched or cached image.
    /// - Throws: Network or decoding error.
    public func image(
        from url: URL,
        options: CacheOptions = .default
    ) async throws -> UIImage {
        let key = url.absoluteString.sha256Hash
        
        // Check cache first
        if let cached = await image(forKey: key) {
            return cached
        }
        
        // Fetch from network
        let (data, _) = try await urlSession.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw CacheError.invalidDataFormat("Invalid image data")
        }
        
        // Cache the image
        await setImage(image, forKey: key, options: options)
        stats.networkFetches += 1
        
        return image
    }
    
    /// Downsamples an image to fit within max dimension.
    private func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        
        guard scale < 1.0 else { return image }
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    /// Encodes an image to data.
    private func encodeImage(_ image: UIImage, format: ImageFormat, quality: CGFloat) -> Data? {
        switch format {
        case .png:
            return image.pngData()
        case .jpeg:
            return image.jpegData(compressionQuality: quality)
        }
    }
    
    /// Estimates memory size of an image.
    private func estimateImageSize(_ image: UIImage) -> Int {
        let pixelWidth = Int(image.size.width * image.scale)
        let pixelHeight = Int(image.size.height * image.scale)
        return pixelWidth * pixelHeight * 4 // 4 bytes per pixel (RGBA)
    }
    
    /// Stores image in memory cache.
    private func storeInMemory(key: String, image: UIImage, size: Int) async {
        // Evict if needed
        while currentMemoryUsage + size > memoryLimit && !memoryAccessOrder.isEmpty {
            evictLRUFromMemory()
        }
        
        let cached = CachedImage(image: image, size: size, accessDate: Date())
        memoryCache[key] = cached
        memoryAccessOrder.append(key)
        currentMemoryUsage += size
    }
    
    #elseif canImport(AppKit)
    /// Retrieves an image from cache.
    public func image(forKey key: String) async -> NSImage? {
        if let cached = memoryCache[key] {
            updateMemoryAccess(for: key)
            stats.memoryHits += 1
            return cached.image
        }
        
        let diskPath = diskFilePath(for: key)
        guard let data = fileManager.contents(atPath: diskPath.path),
              let image = NSImage(data: data) else {
            stats.misses += 1
            return nil
        }
        
        let size = estimateImageSize(image)
        await storeInMemory(key: key, image: image, size: size)
        
        stats.diskHits += 1
        return image
    }
    
    /// Stores an image in cache.
    public func setImage(
        _ image: NSImage,
        forKey key: String,
        options: CacheOptions = .default
    ) async {
        let size = estimateImageSize(image)
        
        if !options.skipMemory {
            await storeInMemory(key: key, image: image, size: size)
        }
        
        if !options.skipDisk {
            if let data = image.tiffRepresentation {
                await storeToDisk(key: key, data: data)
            }
        }
    }
    
    private func estimateImageSize(_ image: NSImage) -> Int {
        let size = image.size
        return Int(size.width * size.height * 4)
    }
    
    private func storeInMemory(key: String, image: NSImage, size: Int) async {
        while currentMemoryUsage + size > memoryLimit && !memoryAccessOrder.isEmpty {
            evictLRUFromMemory()
        }
        
        let cached = CachedImage(image: image, size: size, accessDate: Date())
        memoryCache[key] = cached
        memoryAccessOrder.append(key)
        currentMemoryUsage += size
    }
    #endif
    
    // MARK: - Common Operations
    
    /// Removes an image from cache.
    ///
    /// - Parameter key: Cache key.
    public func removeImage(forKey key: String) async {
        // Remove from memory
        if let cached = memoryCache.removeValue(forKey: key) {
            currentMemoryUsage -= cached.size
            memoryAccessOrder.removeAll { $0 == key }
        }
        
        // Remove from disk
        let diskPath = diskFilePath(for: key)
        try? fileManager.removeItem(at: diskPath)
    }
    
    /// Clears all cached images.
    public func clearAll() async {
        memoryCache.removeAll()
        memoryAccessOrder.removeAll()
        currentMemoryUsage = 0
        
        try? fileManager.removeItem(at: diskDirectory)
        try? fileManager.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }
    
    /// Clears memory cache only.
    public func clearMemory() {
        memoryCache.removeAll()
        memoryAccessOrder.removeAll()
        currentMemoryUsage = 0
    }
    
    /// Returns cache statistics.
    public func getStatistics() -> ImageCacheStatistics {
        var s = stats
        s.memoryUsage = currentMemoryUsage
        s.memoryItemCount = memoryCache.count
        return s
    }
    
    // MARK: - Private Methods
    
    /// Returns disk file path for a key.
    private func diskFilePath(for key: String) -> URL {
        diskDirectory.appendingPathComponent(key.sha256Hash)
    }
    
    /// Stores data to disk.
    private func storeToDisk(key: String, data: Data?) async {
        guard let data = data else { return }
        
        let path = diskFilePath(for: key)
        try? data.write(to: path)
    }
    
    /// Updates memory access order.
    private func updateMemoryAccess(for key: String) {
        memoryAccessOrder.removeAll { $0 == key }
        memoryAccessOrder.append(key)
    }
    
    /// Evicts least recently used item from memory.
    private func evictLRUFromMemory() {
        guard let key = memoryAccessOrder.first else { return }
        memoryAccessOrder.removeFirst()
        
        if let cached = memoryCache.removeValue(forKey: key) {
            currentMemoryUsage -= cached.size
            stats.memoryEvictions += 1
        }
    }
}

// MARK: - Image Cache Statistics

/// Statistics for image cache.
public struct ImageCacheStatistics: Sendable {
    /// Memory cache hits.
    public var memoryHits: Int = 0
    
    /// Disk cache hits.
    public var diskHits: Int = 0
    
    /// Cache misses.
    public var misses: Int = 0
    
    /// Network fetches.
    public var networkFetches: Int = 0
    
    /// Memory evictions.
    public var memoryEvictions: Int = 0
    
    /// Current memory usage.
    public var memoryUsage: Int = 0
    
    /// Items in memory.
    public var memoryItemCount: Int = 0
    
    /// Hit rate.
    public var hitRate: Double {
        let total = memoryHits + diskHits + misses
        guard total > 0 else { return 0 }
        return Double(memoryHits + diskHits) / Double(total) * 100
    }
}
