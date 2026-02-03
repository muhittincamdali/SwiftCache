// FileManager+Cache.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - FileManager Cache Extensions

extension FileManager {
    
    // MARK: - Directory Operations
    
    /// Returns the default cache directory for SwiftCache.
    ///
    /// Creates the directory if it doesn't exist.
    ///
    /// - Parameter name: Optional subdirectory name.
    /// - Returns: URL to the cache directory.
    /// - Throws: An error if directory creation fails.
    public func swiftCacheDirectory(name: String? = nil) throws -> URL {
        let caches = urls(for: .cachesDirectory, in: .userDomainMask).first!
        var dir = caches.appendingPathComponent("SwiftCache", isDirectory: true)
        
        if let name = name {
            dir = dir.appendingPathComponent(name, isDirectory: true)
        }
        
        if !fileExists(atPath: dir.path) {
            try createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return dir
    }
    
    /// Calculates the total size of a directory.
    ///
    /// - Parameter url: URL to the directory.
    /// - Returns: Total size in bytes.
    public func directorySize(at url: URL) -> Int {
        var totalSize = 0
        
        guard let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let size = resourceValues.fileSize else { continue }
            totalSize += size
        }
        
        return totalSize
    }
    
    /// Returns the number of files in a directory.
    ///
    /// - Parameter url: URL to the directory.
    /// - Returns: Number of files.
    public func fileCount(at url: URL) -> Int {
        guard let contents = try? contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return 0
        }
        return contents.count
    }
    
    /// Removes all contents of a directory without removing the directory itself.
    ///
    /// - Parameter url: URL to the directory.
    /// - Throws: An error if removal fails.
    public func clearDirectory(at url: URL) throws {
        let contents = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        for item in contents {
            try removeItem(at: item)
        }
    }
    
    /// Creates a directory with protection attributes.
    ///
    /// - Parameters:
    ///   - url: URL for the directory.
    ///   - protection: File protection level.
    /// - Throws: An error if creation fails.
    public func createProtectedDirectory(at url: URL, protection: FileProtectionType) throws {
        var attributes: [FileAttributeKey: Any] = [:]
        
        #if os(iOS) || os(tvOS) || os(watchOS)
        attributes[.protectionKey] = protection.foundationValue
        #endif
        
        try createDirectory(at: url, withIntermediateDirectories: true, attributes: attributes)
    }
    
    // MARK: - File Operations
    
    /// Safely writes data to a file using atomic operations.
    ///
    /// Writes to a temporary file first, then moves to the final location.
    ///
    /// - Parameters:
    ///   - data: Data to write.
    ///   - url: Destination URL.
    ///   - protection: Optional file protection level.
    /// - Throws: An error if writing fails.
    public func atomicWrite(_ data: Data, to url: URL, protection: FileProtectionType? = nil) throws {
        let tempDir = url.deletingLastPathComponent().appendingPathComponent(".tmp", isDirectory: true)
        
        if !fileExists(atPath: tempDir.path) {
            try createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
        
        let tempURL = tempDir.appendingPathComponent(UUID().uuidString)
        
        try data.write(to: tempURL)
        
        // Apply protection
        #if os(iOS) || os(tvOS) || os(watchOS)
        if let protection = protection {
            try setAttributes([.protectionKey: protection.foundationValue], ofItemAtPath: tempURL.path)
        }
        #endif
        
        // Move atomically
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
        try moveItem(at: tempURL, to: url)
    }
    
    /// Returns file attributes including size and dates.
    ///
    /// - Parameter url: URL to the file.
    /// - Returns: File information or nil if file doesn't exist.
    public func fileInfo(at url: URL) -> FileInfo? {
        guard let attrs = try? attributesOfItem(atPath: url.path) else { return nil }
        
        return FileInfo(
            size: attrs[.size] as? Int ?? 0,
            creationDate: attrs[.creationDate] as? Date ?? Date(),
            modificationDate: attrs[.modificationDate] as? Date ?? Date(),
            isDirectory: (attrs[.type] as? FileAttributeType) == .typeDirectory
        )
    }
    
    /// Lists all files in a directory sorted by modification date.
    ///
    /// - Parameters:
    ///   - url: URL to the directory.
    ///   - ascending: Sort order (oldest first if true).
    /// - Returns: Array of file URLs.
    public func filesSortedByDate(at url: URL, ascending: Bool = true) -> [URL] {
        guard let contents = try? contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        return contents.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return ascending ? date1 < date2 : date1 > date2
        }
    }
    
    /// Removes files older than a specified date.
    ///
    /// - Parameters:
    ///   - date: Cutoff date.
    ///   - directory: Directory to clean.
    /// - Returns: Number of files removed.
    @discardableResult
    public func removeFilesOlderThan(_ date: Date, in directory: URL) -> Int {
        var removed = 0
        
        guard let enumerator = enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let modDate = resourceValues.contentModificationDate,
                  modDate < date else { continue }
            
            if (try? removeItem(at: fileURL)) != nil {
                removed += 1
            }
        }
        
        return removed
    }
    
    /// Returns available disk space.
    ///
    /// - Returns: Available space in bytes, or nil if unavailable.
    public var availableDiskSpace: Int? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        guard let path = paths.first else { return nil }
        
        do {
            let attrs = try attributesOfFileSystem(forPath: path)
            return attrs[.systemFreeSize] as? Int
        } catch {
            return nil
        }
    }
    
    /// Returns total disk space.
    ///
    /// - Returns: Total space in bytes, or nil if unavailable.
    public var totalDiskSpace: Int? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        guard let path = paths.first else { return nil }
        
        do {
            let attrs = try attributesOfFileSystem(forPath: path)
            return attrs[.systemSize] as? Int
        } catch {
            return nil
        }
    }
}

// MARK: - File Info

/// Information about a file.
public struct FileInfo: Sendable, Equatable {
    /// Size in bytes.
    public let size: Int
    
    /// Creation date.
    public let creationDate: Date
    
    /// Last modification date.
    public let modificationDate: Date
    
    /// Whether this is a directory.
    public let isDirectory: Bool
    
    /// Age of the file since creation.
    public var age: TimeInterval {
        Date().timeIntervalSince(creationDate)
    }
    
    /// Formatted size string.
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

// MARK: - Cache File Manager

/// Utility class for cache file management.
public final class CacheFileManager: @unchecked Sendable {
    
    /// Shared instance.
    public static let shared = CacheFileManager()
    
    /// File manager.
    private let fileManager = FileManager.default
    
    /// Serial queue for file operations.
    private let queue = DispatchQueue(label: "com.swiftcache.filemanager")
    
    private init() {}
    
    /// Safely reads data from a file.
    ///
    /// - Parameter url: URL to read from.
    /// - Returns: File contents or nil.
    public func read(at url: URL) -> Data? {
        queue.sync {
            fileManager.contents(atPath: url.path)
        }
    }
    
    /// Safely writes data to a file.
    ///
    /// - Parameters:
    ///   - data: Data to write.
    ///   - url: Destination URL.
    /// - Returns: Success status.
    @discardableResult
    public func write(_ data: Data, to url: URL) -> Bool {
        queue.sync {
            do {
                try fileManager.atomicWrite(data, to: url)
                return true
            } catch {
                return false
            }
        }
    }
    
    /// Safely removes a file.
    ///
    /// - Parameter url: URL to remove.
    /// - Returns: Success status.
    @discardableResult
    public func remove(at url: URL) -> Bool {
        queue.sync {
            do {
                try fileManager.removeItem(at: url)
                return true
            } catch {
                return false
            }
        }
    }
}
