// JSONSerializer.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Advanced JSON Serializer

/// An advanced JSON serializer with additional features.
///
/// `AdvancedJSONSerializer` provides extended JSON serialization
/// capabilities including custom type handling, schema validation,
/// and debugging support.
///
/// ## Overview
/// Use this serializer when you need fine-grained control over
/// JSON encoding and decoding.
///
/// ```swift
/// let serializer = AdvancedJSONSerializer(
///     options: .init(
///         dateFormat: .custom("yyyy-MM-dd"),
///         keyStrategy: .convertToSnakeCase,
///         nullHandling: .includeNulls
///     )
/// )
/// ```
public struct AdvancedJSONSerializer: CacheSerializer {
    
    // MARK: - Types
    
    /// Serialization options.
    public struct Options: Sendable {
        /// Date format strategy.
        public var dateFormat: DateFormat
        
        /// Key encoding strategy.
        public var keyStrategy: KeyStrategy
        
        /// How to handle null values.
        public var nullHandling: NullHandling
        
        /// Whether to include debug information.
        public var includeDebugInfo: Bool
        
        /// Maximum nesting depth.
        public var maxDepth: Int
        
        /// Default options.
        public static let `default` = Options(
            dateFormat: .iso8601,
            keyStrategy: .useDefaultKeys,
            nullHandling: .excludeNulls,
            includeDebugInfo: false,
            maxDepth: 100
        )
        
        /// Creates options.
        public init(
            dateFormat: DateFormat = .iso8601,
            keyStrategy: KeyStrategy = .useDefaultKeys,
            nullHandling: NullHandling = .excludeNulls,
            includeDebugInfo: Bool = false,
            maxDepth: Int = 100
        ) {
            self.dateFormat = dateFormat
            self.keyStrategy = keyStrategy
            self.nullHandling = nullHandling
            self.includeDebugInfo = includeDebugInfo
            self.maxDepth = maxDepth
        }
    }
    
    /// Date format options.
    public enum DateFormat: Sendable {
        case iso8601
        case secondsSince1970
        case millisecondsSince1970
        case custom(String)
        
        var encodingStrategy: JSONEncoder.DateEncodingStrategy {
            switch self {
            case .iso8601:
                return .iso8601
            case .secondsSince1970:
                return .secondsSince1970
            case .millisecondsSince1970:
                return .millisecondsSince1970
            case .custom(let format):
                let formatter = DateFormatter()
                formatter.dateFormat = format
                return .formatted(formatter)
            }
        }
        
        var decodingStrategy: JSONDecoder.DateDecodingStrategy {
            switch self {
            case .iso8601:
                return .iso8601
            case .secondsSince1970:
                return .secondsSince1970
            case .millisecondsSince1970:
                return .millisecondsSince1970
            case .custom(let format):
                let formatter = DateFormatter()
                formatter.dateFormat = format
                return .formatted(formatter)
            }
        }
    }
    
    /// Key encoding strategy.
    public enum KeyStrategy: Sendable {
        case useDefaultKeys
        case convertToSnakeCase
        case convertToCamelCase
        
        var encodingStrategy: JSONEncoder.KeyEncodingStrategy {
            switch self {
            case .useDefaultKeys:
                return .useDefaultKeys
            case .convertToSnakeCase:
                return .convertToSnakeCase
            case .convertToCamelCase:
                return .useDefaultKeys // No built-in support
            }
        }
        
        var decodingStrategy: JSONDecoder.KeyDecodingStrategy {
            switch self {
            case .useDefaultKeys:
                return .useDefaultKeys
            case .convertToSnakeCase:
                return .convertFromSnakeCase
            case .convertToCamelCase:
                return .useDefaultKeys
            }
        }
    }
    
    /// Null value handling.
    public enum NullHandling: Sendable {
        case includeNulls
        case excludeNulls
    }
    
    // MARK: - Properties
    
    /// Serialization options.
    public let options: Options
    
    /// Configured encoder.
    private let encoder: JSONEncoder
    
    /// Configured decoder.
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    /// Creates an advanced JSON serializer.
    ///
    /// - Parameter options: Serialization options.
    public init(options: Options = .default) {
        self.options = options
        
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        encoder.dateEncodingStrategy = options.dateFormat.encodingStrategy
        encoder.keyEncodingStrategy = options.keyStrategy.encodingStrategy
        
        decoder.dateDecodingStrategy = options.dateFormat.decodingStrategy
        decoder.keyDecodingStrategy = options.keyStrategy.decodingStrategy
        
        if options.includeDebugInfo {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
    }
    
    // MARK: - CacheSerializer
    
    public func encode<T: Codable & Sendable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
    
    public func decode<T: Codable & Sendable>(_ data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Additional Methods
    
    /// Encodes to JSON string.
    ///
    /// - Parameter value: Value to encode.
    /// - Returns: JSON string.
    public func encodeToString<T: Codable & Sendable>(_ value: T) throws -> String {
        let data = try encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CacheError.serializationFailed("Failed to convert data to string")
        }
        return string
    }
    
    /// Decodes from JSON string.
    ///
    /// - Parameter string: JSON string.
    /// - Returns: Decoded value.
    public func decodeFromString<T: Codable & Sendable>(_ string: String) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw CacheError.deserializationFailed("Failed to convert string to data")
        }
        return try decode(data)
    }
    
    /// Validates JSON structure.
    ///
    /// - Parameter data: Data to validate.
    /// - Returns: True if valid JSON.
    public func isValidJSON(_ data: Data) -> Bool {
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Typed JSON Wrapper

/// A wrapper for type-safe JSON values.
public struct TypedJSON<T: Codable & Sendable>: Codable, Sendable {
    
    /// The wrapped value.
    public let value: T
    
    /// Type identifier.
    public let typeId: String
    
    /// Encoding version.
    public let version: Int
    
    /// Creation timestamp.
    public let timestamp: Date
    
    /// Creates a typed JSON wrapper.
    ///
    /// - Parameters:
    ///   - value: Value to wrap.
    ///   - version: Schema version.
    public init(_ value: T, version: Int = 1) {
        self.value = value
        self.typeId = String(describing: T.self)
        self.version = version
        self.timestamp = Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case value
        case typeId = "type_id"
        case version
        case timestamp
    }
}
