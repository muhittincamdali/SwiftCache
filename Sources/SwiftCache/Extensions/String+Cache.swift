// String+Cache.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation
import CommonCrypto

// MARK: - String Hashing Extensions

extension String {
    
    // MARK: - SHA256
    
    /// Computes SHA256 hash of the string.
    ///
    /// Uses UTF-8 encoding.
    ///
    /// - Returns: 64-character hexadecimal string.
    public var sha256Hash: String {
        guard let data = data(using: .utf8) else { return "" }
        return data.sha256Hash
    }
    
    /// Computes SHA256 hash as data.
    ///
    /// - Returns: 32-byte hash data.
    public var sha256Data: Data {
        guard let data = data(using: .utf8) else { return Data() }
        return data.sha256
    }
    
    // MARK: - SHA1
    
    /// Computes SHA1 hash of the string.
    ///
    /// - Note: SHA1 is deprecated for security purposes.
    /// - Returns: 40-character hexadecimal string.
    public var sha1Hash: String {
        guard let data = data(using: .utf8) else { return "" }
        return data.sha1Hash
    }
    
    // MARK: - MD5
    
    /// Computes MD5 hash of the string.
    ///
    /// - Note: MD5 is not secure for cryptographic purposes.
    /// - Returns: 32-character hexadecimal string.
    public var md5Hash: String {
        guard let data = data(using: .utf8) else { return "" }
        return data.md5Hash
    }
    
    // MARK: - Cache Key Generation
    
    /// Generates a cache-safe key from the string.
    ///
    /// Removes or replaces characters that may cause issues
    /// with file systems or other storage backends.
    ///
    /// - Returns: Safe cache key string.
    public var safeCacheKey: String {
        // Remove or replace problematic characters
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        
        return components(separatedBy: allowedCharacters.inverted)
            .joined(separator: "_")
            .lowercased()
    }
    
    /// Generates a unique cache key using hash.
    ///
    /// Useful for long strings or URLs that need a fixed-length key.
    ///
    /// - Returns: Hash-based cache key.
    public var hashedCacheKey: String {
        sha256Hash
    }
    
    /// Generates a cache key with prefix.
    ///
    /// - Parameter prefix: Prefix to add.
    /// - Returns: Prefixed cache key.
    public func cacheKey(prefix: String) -> String {
        "\(prefix)_\(hashedCacheKey)"
    }
}

// MARK: - URL String Extensions

extension String {
    
    /// Extracts domain from URL string.
    ///
    /// - Returns: Domain string, or nil if invalid URL.
    public var urlDomain: String? {
        guard let url = URL(string: self) else { return nil }
        return url.host
    }
    
    /// Extracts path from URL string.
    ///
    /// - Returns: Path string, or nil if invalid URL.
    public var urlPath: String? {
        guard let url = URL(string: self) else { return nil }
        return url.path
    }
    
    /// Generates cache key from URL string.
    ///
    /// Combines domain and path hash for readable keys.
    ///
    /// - Returns: URL-based cache key.
    public var urlCacheKey: String {
        guard let url = URL(string: self) else { return hashedCacheKey }
        
        let domain = url.host ?? "unknown"
        let pathHash = url.path.sha256Hash.prefix(16)
        
        return "\(domain.safeCacheKey)_\(pathHash)"
    }
}

// MARK: - String Formatting Extensions

extension String {
    
    /// Truncates string to specified length.
    ///
    /// - Parameters:
    ///   - maxLength: Maximum length.
    ///   - trailing: Trailing string for truncation.
    /// - Returns: Truncated string.
    public func truncated(to maxLength: Int, trailing: String = "...") -> String {
        guard count > maxLength else { return self }
        let truncateAt = maxLength - trailing.count
        guard truncateAt > 0 else { return trailing }
        return String(prefix(truncateAt)) + trailing
    }
    
    /// Pads string to specified length.
    ///
    /// - Parameters:
    ///   - length: Target length.
    ///   - character: Padding character.
    ///   - leading: Whether to pad at start.
    /// - Returns: Padded string.
    public func padded(to length: Int, with character: Character = " ", leading: Bool = true) -> String {
        guard count < length else { return self }
        let padding = String(repeating: character, count: length - count)
        return leading ? padding + self : self + padding
    }
}

// MARK: - String Encoding Extensions

extension String {
    
    /// URL-encoded string.
    public var urlEncoded: String? {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
    
    /// URL-decoded string.
    public var urlDecoded: String? {
        removingPercentEncoding
    }
    
    /// Base64-encoded string.
    public var base64Encoded: String? {
        data(using: .utf8)?.base64EncodedString()
    }
    
    /// Base64-decoded string.
    public var base64Decoded: String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// URL-safe Base64-encoded string.
    public var base64URLSafe: String? {
        data(using: .utf8)?.base64URLSafe
    }
}

// MARK: - String Validation Extensions

extension String {
    
    /// Whether the string is a valid URL.
    public var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    /// Whether the string is a valid file path.
    public var isValidFilePath: Bool {
        !isEmpty && !contains(CharacterSet(charactersIn: "\0"))
    }
    
    /// Whether the string contains only alphanumeric characters.
    public var isAlphanumeric: Bool {
        !isEmpty && rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
    }
    
    /// Whether the string is a valid cache key.
    public var isValidCacheKey: Bool {
        guard !isEmpty else { return false }
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.:"))
        return rangeOfCharacter(from: validCharacters.inverted) == nil
    }
}

// MARK: - String File Extension Utilities

extension String {
    
    /// File extension from the string.
    public var fileExtension: String? {
        guard let lastDot = lastIndex(of: ".") else { return nil }
        let ext = String(self[index(after: lastDot)...])
        return ext.isEmpty ? nil : ext.lowercased()
    }
    
    /// File name without extension.
    public var fileNameWithoutExtension: String {
        guard let lastDot = lastIndex(of: ".") else { return self }
        return String(self[..<lastDot])
    }
    
    /// Appends extension to the string.
    public func appendingExtension(_ ext: String) -> String {
        "\(self).\(ext)"
    }
    
    /// Replaces file extension.
    public func replacingExtension(with newExtension: String) -> String {
        fileNameWithoutExtension.appendingExtension(newExtension)
    }
}

// MARK: - Cache Key Builder

/// A builder for creating cache keys.
public struct CacheKeyBuilder: Sendable {
    
    private var components: [String] = []
    private let separator: String
    
    /// Creates a new key builder.
    ///
    /// - Parameter separator: Component separator.
    public init(separator: String = ":") {
        self.separator = separator
    }
    
    /// Adds a component to the key.
    ///
    /// - Parameter component: Component to add.
    /// - Returns: Self for chaining.
    @discardableResult
    public mutating func add(_ component: String) -> Self {
        components.append(component.safeCacheKey)
        return self
    }
    
    /// Adds a hashable component.
    ///
    /// - Parameter component: Hashable component.
    /// - Returns: Self for chaining.
    @discardableResult
    public mutating func add<T: CustomStringConvertible>(_ component: T) -> Self {
        components.append(String(describing: component).safeCacheKey)
        return self
    }
    
    /// Builds the final cache key.
    ///
    /// - Returns: Combined cache key.
    public func build() -> String {
        components.joined(separator: separator)
    }
    
    /// Builds a hashed cache key.
    ///
    /// - Returns: Hashed cache key.
    public func buildHashed() -> String {
        build().hashedCacheKey
    }
}
