# Changelog

All notable changes to SwiftCache are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-02-03

### Added

#### Core Features
- **MemoryCache** - High-performance in-memory cache with configurable limits
- **DiskCache** - Persistent disk storage with automatic cleanup
- **HybridCache** - Multi-layer cache combining memory and disk
- **FIFOCache** - First-in-first-out eviction policy
- **LRUCache** - Least recently used eviction with cost support
- **WeakCache** - Weak reference cache for object deallocation

#### Specialized Caches
- **ImageCache** - Optimized image caching with downsampling support
- **ResponseCache** - HTTP response caching with ETag support
- **CachedURLSession** - URLSession wrapper with automatic caching

#### Expiration System
- Time-based expiration (seconds, minutes, hours, days, weeks)
- Date-based expiration
- Custom expiration policies via `ExpirationPolicyProtocol`
- Sliding window expiration
- Access count expiration

#### Eviction Policies
- LRU (Least Recently Used)
- FIFO (First In, First Out)
- LFU (Least Frequently Used)
- TTL (Time To Live priority)
- Random eviction
- Size-based eviction

#### Serialization
- JSON serializer (default)
- Property List serializer
- Binary serializer
- Compression serializer (LZ4, LZFSE, ZLIB, LZMA)
- Chained serializer for custom transformations

#### Monitoring & Analytics
- Cache statistics (hit rate, miss count, evictions)
- Cache observers for event tracking
- Logging observer with configurable levels
- Memory warning handler with automatic eviction

#### Architecture
- Protocol-oriented design via `CacheProtocol`
- Actor-based thread safety
- Async/await native API
- Zero external dependencies
- Full Sendable compliance

#### Platform Support
- iOS 15.0+
- macOS 13.0+
- tvOS 15.0+
- watchOS 8.0+
- Swift 5.9+

### Performance
- Memory cache operations under 1μs
- Disk cache writes 45% faster than raw FileManager
- Optimized LRU with O(1) access and eviction
- Lazy expiration checking for better performance
