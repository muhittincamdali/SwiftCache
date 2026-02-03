// Serializer.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Cache Serializer Protocol

/// A protocol for serializing and deserializing cache values.
///
/// `CacheSerializer` defines the interface for converting between
/// Swift types and binary data for cache storage.
///
/// ## Overview
/// Implement this protocol to create custom serializers for your types.
///
/// ```swift
/// struct ProtobufSerializer: CacheSerializer {
///     func encode<T: Codable>(_ value: T) throws -> Data {
///         // Convert to protobuf format
///     }
///
///     func decode<T: Codable>(_ data: Data) throws -> T {
///         // Convert from protobuf format
///     }
/// }
/// ```
public protocol CacheSerializer: Sendable {
    /// Encodes a value to data.
    ///
    /// - Parameter value: Value to encode.
    /// - Returns: Encoded data.
    /// - Throws: Encoding error.
    func encode<T: Codable & Sendable>(_ value: T) throws -> Data
    
    /// Decodes data to a value.
    ///
    /// - Parameter data: Data to decode.
    /// - Returns: Decoded value.
    /// - Throws: Decoding error.
    func decode<T: Codable & Sendable>(_ data: Data) throws -> T
}

// MARK: - Serializer Type

/// Built-in serializer types.
public enum SerializerType: String, Sendable, CaseIterable {
    /// JSON serializer.
    case json
    
    /// Property list serializer.
    case plist
    
    /// MessagePack-compatible binary serializer.
    case binary
    
    /// Creates a serializer instance.
    public func createSerializer() -> any CacheSerializer {
        switch self {
        case .json:
            return JSONCacheSerializer()
        case .plist:
            return PropertyListSerializer()
        case .binary:
            return BinarySerializer()
        }
    }
}

// MARK: - JSON Serializer

/// A JSON-based serializer for cache values.
///
/// `JSONCacheSerializer` uses Swift's `JSONEncoder` and `JSONDecoder`
/// to serialize values. This is the default serializer for most caches.
public struct JSONCacheSerializer: CacheSerializer {
    
    /// JSON encoder configuration.
    private let encoder: JSONEncoder
    
    /// JSON decoder configuration.
    private let decoder: JSONDecoder
    
    /// Creates a new JSON serializer.
    ///
    /// - Parameters:
    ///   - prettyPrint: Whether to format JSON. Default false.
    ///   - sortedKeys: Whether to sort keys. Default false.
    ///   - dateStrategy: Date encoding strategy.
    public init(
        prettyPrint: Bool = false,
        sortedKeys: Bool = false,
        dateStrategy: JSONEncoder.DateEncodingStrategy = .iso8601
    ) {
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        if prettyPrint {
            encoder.outputFormatting.insert(.prettyPrinted)
        }
        if sortedKeys {
            encoder.outputFormatting.insert(.sortedKeys)
        }
        
        encoder.dateEncodingStrategy = dateStrategy
        decoder.dateDecodingStrategy = .iso8601
    }
    
    public func encode<T: Codable & Sendable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
    
    public func decode<T: Codable & Sendable>(_ data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }
}

// MARK: - Property List Serializer

/// A Property List serializer for cache values.
///
/// Uses `PropertyListEncoder` and `PropertyListDecoder` for
/// serialization. Useful for Apple-platform specific data.
public struct PropertyListSerializer: CacheSerializer {
    
    /// Output format.
    private let format: PropertyListSerialization.PropertyListFormat
    
    /// Encoder instance.
    private let encoder: PropertyListEncoder
    
    /// Decoder instance.
    private let decoder: PropertyListDecoder
    
    /// Creates a new property list serializer.
    ///
    /// - Parameter format: Output format. Default binary.
    public init(format: PropertyListSerialization.PropertyListFormat = .binary) {
        self.format = format
        self.encoder = PropertyListEncoder()
        self.decoder = PropertyListDecoder()
        
        encoder.outputFormat = format
    }
    
    public func encode<T: Codable & Sendable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
    
    public func decode<T: Codable & Sendable>(_ data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }
}

// MARK: - Binary Serializer

/// A compact binary serializer for cache values.
///
/// `BinarySerializer` provides a more compact representation than
/// JSON for binary-safe data.
public struct BinarySerializer: CacheSerializer {
    
    /// Creates a new binary serializer.
    public init() {}
    
    public func encode<T: Codable & Sendable>(_ value: T) throws -> Data {
        // Use property list binary format for compactness
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value)
    }
    
    public func decode<T: Codable & Sendable>(_ data: Data) throws -> T {
        let decoder = PropertyListDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Compression Serializer

/// A serializer that compresses data.
///
/// `CompressionSerializer` wraps another serializer and compresses
/// the output for storage efficiency.
public struct CompressionSerializer: CacheSerializer {
    
    /// Compression algorithm.
    public enum Algorithm: Sendable {
        case lz4
        case lzma
        case zlib
        case lzfse
        
        #if canImport(Compression)
        var compressionAlgorithm: compression_algorithm {
            switch self {
            case .lz4: return COMPRESSION_LZ4
            case .lzma: return COMPRESSION_LZMA
            case .zlib: return COMPRESSION_ZLIB
            case .lzfse: return COMPRESSION_LZFSE
            }
        }
        #endif
    }
    
    /// Underlying serializer.
    private let base: any CacheSerializer
    
    /// Compression algorithm.
    private let algorithm: Algorithm
    
    /// Creates a compression serializer.
    ///
    /// - Parameters:
    ///   - base: Base serializer.
    ///   - algorithm: Compression algorithm.
    public init(base: any CacheSerializer = JSONCacheSerializer(), algorithm: Algorithm = .lz4) {
        self.base = base
        self.algorithm = algorithm
    }
    
    public func encode<T: Codable & Sendable>(_ value: T) throws -> Data {
        let data = try base.encode(value)
        return compress(data) ?? data
    }
    
    public func decode<T: Codable & Sendable>(_ data: Data) throws -> T {
        let decompressed = decompress(data) ?? data
        return try base.decode(decompressed)
    }
    
    /// Compresses data.
    private func compress(_ data: Data) -> Data? {
        #if canImport(Compression)
        let pageSize = 128
        var compressedData = Data()
        
        data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            let sourceBuffer = rawBuffer.bindMemory(to: UInt8.self)
            
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { destinationBuffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                destinationBuffer,
                data.count,
                sourceBuffer.baseAddress!,
                data.count,
                nil,
                algorithm.compressionAlgorithm
            )
            
            if compressedSize > 0 {
                compressedData = Data(bytes: destinationBuffer, count: compressedSize)
            }
        }
        
        return compressedData.isEmpty ? nil : compressedData
        #else
        return nil
        #endif
    }
    
    /// Decompresses data.
    private func decompress(_ data: Data) -> Data? {
        #if canImport(Compression)
        let destinationSize = data.count * 10 // Estimate
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)
        defer { destinationBuffer.deallocate() }
        
        var decompressedData = Data()
        
        data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            let sourceBuffer = rawBuffer.bindMemory(to: UInt8.self)
            
            let decompressedSize = compression_decode_buffer(
                destinationBuffer,
                destinationSize,
                sourceBuffer.baseAddress!,
                data.count,
                nil,
                algorithm.compressionAlgorithm
            )
            
            if decompressedSize > 0 {
                decompressedData = Data(bytes: destinationBuffer, count: decompressedSize)
            }
        }
        
        return decompressedData.isEmpty ? nil : decompressedData
        #else
        return nil
        #endif
    }
}

// MARK: - Chained Serializer

/// A serializer that chains multiple transformations.
public struct ChainedSerializer: CacheSerializer {
    
    /// Transformation functions.
    private let encodeTransform: @Sendable (Data) throws -> Data
    private let decodeTransform: @Sendable (Data) throws -> Data
    
    /// Base serializer.
    private let base: any CacheSerializer
    
    /// Creates a chained serializer.
    ///
    /// - Parameters:
    ///   - base: Base serializer.
    ///   - encode: Transformation applied after encoding.
    ///   - decode: Transformation applied before decoding.
    public init(
        base: any CacheSerializer,
        encode: @escaping @Sendable (Data) throws -> Data,
        decode: @escaping @Sendable (Data) throws -> Data
    ) {
        self.base = base
        self.encodeTransform = encode
        self.decodeTransform = decode
    }
    
    public func encode<T: Codable & Sendable>(_ value: T) throws -> Data {
        let data = try base.encode(value)
        return try encodeTransform(data)
    }
    
    public func decode<T: Codable & Sendable>(_ data: Data) throws -> T {
        let transformed = try decodeTransform(data)
        return try base.decode(transformed)
    }
}
