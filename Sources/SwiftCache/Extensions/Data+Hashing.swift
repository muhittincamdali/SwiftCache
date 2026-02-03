// Data+Hashing.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation
import CommonCrypto

// MARK: - Data Hashing Extensions

extension Data {
    
    // MARK: - SHA256
    
    /// Computes SHA256 hash of the data.
    ///
    /// - Returns: 32-byte hash data.
    public var sha256: Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(count), &hash)
        }
        return Data(hash)
    }
    
    /// Computes SHA256 hash as hexadecimal string.
    ///
    /// - Returns: 64-character hex string.
    public var sha256Hash: String {
        sha256.hexString
    }
    
    // MARK: - SHA1
    
    /// Computes SHA1 hash of the data.
    ///
    /// - Returns: 20-byte hash data.
    public var sha1: Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(count), &hash)
        }
        return Data(hash)
    }
    
    /// Computes SHA1 hash as hexadecimal string.
    ///
    /// - Returns: 40-character hex string.
    public var sha1Hash: String {
        sha1.hexString
    }
    
    // MARK: - MD5
    
    /// Computes MD5 hash of the data.
    ///
    /// - Note: MD5 is not secure for cryptographic purposes.
    /// - Returns: 16-byte hash data.
    public var md5: Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(count), &hash)
        }
        return Data(hash)
    }
    
    /// Computes MD5 hash as hexadecimal string.
    ///
    /// - Returns: 32-character hex string.
    public var md5Hash: String {
        md5.hexString
    }
    
    // MARK: - Hex Conversion
    
    /// Converts data to hexadecimal string.
    ///
    /// - Returns: Hexadecimal representation.
    public var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
    
    /// Creates data from hexadecimal string.
    ///
    /// - Parameter hex: Hexadecimal string.
    /// - Returns: Data, or nil if invalid hex.
    public init?(hexString hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        
        var index = hex.startIndex
        for _ in 0..<len {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    // MARK: - CRC32
    
    /// Computes CRC32 checksum of the data.
    ///
    /// - Returns: CRC32 value.
    public var crc32: UInt32 {
        let polynomial: UInt32 = 0xEDB88320
        var crc: UInt32 = 0xFFFFFFFF
        
        for byte in self {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ polynomial
                } else {
                    crc >>= 1
                }
            }
        }
        
        return ~crc
    }
    
    /// CRC32 checksum as hexadecimal string.
    public var crc32Hash: String {
        String(format: "%08x", crc32)
    }
    
    // MARK: - HMAC
    
    /// Computes HMAC-SHA256 with the given key.
    ///
    /// - Parameter key: Secret key data.
    /// - Returns: HMAC-SHA256 data.
    public func hmacSHA256(key: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        withUnsafeBytes { dataBuffer in
            key.withUnsafeBytes { keyBuffer in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBuffer.baseAddress,
                    key.count,
                    dataBuffer.baseAddress,
                    count,
                    &hash
                )
            }
        }
        
        return Data(hash)
    }
    
    /// Computes HMAC-SHA256 with string key.
    ///
    /// - Parameter key: Secret key string.
    /// - Returns: HMAC-SHA256 hex string.
    public func hmacSHA256(key: String) -> String {
        guard let keyData = key.data(using: .utf8) else { return "" }
        return hmacSHA256(key: keyData).hexString
    }
}

// MARK: - Data Size Extensions

extension Data {
    
    /// Formatted size string.
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
    
    /// Size in kilobytes.
    public var kilobytes: Double {
        Double(count) / 1024.0
    }
    
    /// Size in megabytes.
    public var megabytes: Double {
        Double(count) / (1024.0 * 1024.0)
    }
}

// MARK: - Data Compression Detection

extension Data {
    
    /// File signature types.
    public enum FileSignature: String {
        case gzip
        case zlib
        case jpeg
        case png
        case gif
        case webp
        case pdf
        case zip
        case unknown
    }
    
    /// Detects the file signature/magic bytes.
    public var fileSignature: FileSignature {
        guard count >= 4 else { return .unknown }
        
        let bytes = [UInt8](prefix(4))
        
        // GZIP
        if bytes[0] == 0x1F && bytes[1] == 0x8B {
            return .gzip
        }
        
        // ZLIB
        if bytes[0] == 0x78 && (bytes[1] == 0x01 || bytes[1] == 0x9C || bytes[1] == 0xDA) {
            return .zlib
        }
        
        // JPEG
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return .jpeg
        }
        
        // PNG
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return .png
        }
        
        // GIF
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return .gif
        }
        
        // WebP
        if count >= 12 {
            let webp = [UInt8](self[8..<12])
            if webp == [0x57, 0x45, 0x42, 0x50] { // "WEBP"
                return .webp
            }
        }
        
        // PDF
        if bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46 {
            return .pdf
        }
        
        // ZIP
        if bytes[0] == 0x50 && bytes[1] == 0x4B {
            return .zip
        }
        
        return .unknown
    }
    
    /// Whether the data appears to be compressed.
    public var isCompressed: Bool {
        switch fileSignature {
        case .gzip, .zlib, .zip:
            return true
        default:
            return false
        }
    }
}

// MARK: - Data Base64 Extensions

extension Data {
    
    /// Base64 URL-safe encoded string.
    public var base64URLSafe: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// Creates data from Base64 URL-safe string.
    public init?(base64URLSafe: String) {
        var base64 = base64URLSafe
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        
        self.init(base64Encoded: base64)
    }
}
