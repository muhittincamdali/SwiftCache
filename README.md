# SwiftCache

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-blue.svg)](https://developer.apple.com)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive, high-performance caching framework for Swift applications. SwiftCache provides multiple caching layers with support for memory, disk, and hybrid storage strategies.

## ✨ Features

- 🚀 **High Performance** - Optimized for speed with O(1) lookups
- 🔒 **Thread-Safe** - Actor-based concurrency with full async/await support
- 📦 **Multi-Layer Caching** - Memory, disk, and hybrid cache implementations
- ⏰ **Flexible Expiration** - TTL, access-based, and custom expiration policies
- 🔄 **Multiple Eviction Strategies** - LRU, FIFO, LFU, and more
- 🖼️ **Image Caching** - Specialized cache for images with downsampling
- 🌐 **Network Caching** - URL session integration with HTTP cache semantics
- 📊 **Statistics & Monitoring** - Built-in metrics and observer support
- 💾 **Persistence** - Automatic disk persistence with integrity checks
- 🧹 **Memory Management** - Automatic cleanup on memory pressure

## 📋 Requirements

- Swift 5.9+
- iOS 15.0+ / macOS 13.0+ / tvOS 15.0+ / watchOS 8.0+
- Xcode 15.0+

## 📦 Installation

### Swift Package Manager

Add SwiftCache to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/SwiftCache.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/muhittincamdali/SwiftCache.git`
3. Select version and add to your target

## 🚀 Quick Start

### Memory Cache

```swift
import SwiftCache

// Create a memory cache
let cache = MemoryCache<String, User>()

// Store a value
await cache.set("user_123", value: currentUser)

// Store with expiration
await cache.set("session", value: session, expiration: .seconds(3600))

// Retrieve a value
if let user = await cache.get("user_123") {
    print("Found user: \(user.name)")
}

// Remove a value
await cache.remove("user_123")

// Clear all
await cache.removeAll()
```

### Disk Cache

```swift
// Create a disk cache for persistent storage
let diskCache = try DiskCache<String, Data>(
    name: "images",
    maxSize: 100 * 1024 * 1024  // 100 MB
)

// Store data (persists across app launches)
try await diskCache.set("image_key", value: imageData)

// Retrieve data
if let data = await diskCache.get("image_key") {
    let image = UIImage(data: data)
}
```

### Hybrid Cache

```swift
// Combine memory speed with disk persistence
let hybridCache = try HybridCache<String, Article>(
    name: "articles",
    configuration: .default
)

// Automatic two-layer caching
await hybridCache.set("article_1", value: article)

// Memory hit (fast) or disk fallback (persistent)
let article = await hybridCache.get("article_1")

// Check which layer served the request
if let (value, source) = await hybridCache.getWithSource("article_1") {
    print("Cache hit from: \(source)")  // .memory or .disk
}
```

## 📚 Cache Types

### MemoryCache

Fast, in-memory storage with configurable eviction policies.

```swift
let config = CacheConfiguration(
    maxItemCount: 1000,
    maxMemoryBytes: 50 * 1024 * 1024,
    evictionPolicy: .lru,
    defaultExpiration: .seconds(3600)
)

let cache = MemoryCache<String, Data>(configuration: config)
```

### LRUCache

Specialized Least Recently Used cache with doubly-linked list.

```swift
let lruCache = LRUCache<String, Data>(capacity: 100)

await lruCache.set("key", value: data)

// Accessing moves item to front (most recently used)
let data = await lruCache.get("key")

// Peek without affecting LRU order
let peeked = await lruCache.peek("key")
```

### FIFOCache

First In First Out eviction strategy.

```swift
let fifoCache = FIFOCache<String, Event>(capacity: 500)

// Oldest items are evicted first
await fifoCache.set("event_1", value: event)
```

### WeakCache

Cache with weak references - items are deallocated when no strong references exist.

```swift
let weakCache = WeakCache<String, MyObject>()

autoreleasepool {
    let obj = MyObject()
    await weakCache.set("key", value: obj)
}

// obj has been deallocated
let result = await weakCache.get("key")  // nil
```

### DiskCache

Persistent storage that survives app restarts.

```swift
let diskCache = try DiskCache<String, User>(
    name: "users",
    maxSize: 500 * 1024 * 1024,  // 500 MB
    fileProtection: .completeUntilFirstUserAuthentication
)

// Verify disk integrity
let corrupted = await diskCache.verifyIntegrity()
print("Removed \(corrupted) corrupted entries")
```

### HybridCache

Two-layer cache combining memory and disk.

```swift
let config = HybridCache.Configuration(
    memoryConfig: .default,
    maxDiskSize: 500 * 1024 * 1024,
    writeToDiskOnSet: true,
    promoteOnDiskHit: true
)

let cache = try HybridCache<String, Data>(
    name: "hybrid",
    configuration: config
)

// Layer-specific operations
await cache.clearMemory()  // Keep disk
await cache.clearDisk()    // Keep memory

// Preload items from disk to memory
await cache.preload(keys: ["key1", "key2", "key3"])
```

## ⏰ Expiration Policies

### Time-Based Expiration

```swift
// Expire after duration
await cache.set("key", value: data, expiration: .seconds(300))
await cache.set("key", value: data, expiration: .minutes(5))
await cache.set("key", value: data, expiration: .hours(1))

// Expire at specific date
await cache.set("key", value: data, expiration: .date(futureDate))

// Never expire
await cache.set("key", value: data, expiration: .never)

// Use presets
await cache.set("key", value: data, expiration: .preset(.oneHour))
```

### Custom Expiration Policies

```swift
// Sliding expiration (resets on access)
let sliding = SlidingExpirationPolicy(
    windowDuration: 300,
    maxLifetime: 3600
)

// Access count expiration
let accessCount = AccessCountExpirationPolicy(maxAccessCount: 100)

// Composite policies
let composite = CompositeExpirationPolicy(
    policies: [sliding, accessCount],
    mode: .any  // Expire if ANY policy triggers
)
```

## 🔄 Eviction Policies

```swift
// LRU - Least Recently Used (default)
let lruConfig = CacheConfiguration(evictionPolicy: .lru)

// FIFO - First In First Out
let fifoConfig = CacheConfiguration(evictionPolicy: .fifo)

// LFU - Least Frequently Used
let lfuConfig = CacheConfiguration(evictionPolicy: .lfu)

// TTL - Time To Live based
let ttlConfig = CacheConfiguration(evictionPolicy: .ttl)

// Random eviction
let randomConfig = CacheConfiguration(evictionPolicy: .random)

// Size-based (evict largest first)
let sizeConfig = CacheConfiguration(evictionPolicy: .size)
```

## 🌐 Network Caching

### CachedURLSession

```swift
let cache = try ResponseCache(name: "api")
let session = CachedURLSession(
    cache: cache,
    defaultPolicy: .cacheFirst
)

// Automatic caching of responses
let (data, response) = try await session.data(from: url)

// Different policies per request
let fresh = try await session.data(
    from: url,
    policy: .networkFirst
)

// Prefetch URLs
await session.prefetch(urls: [url1, url2, url3])
```

### ImageCache

```swift
let imageCache = try ImageCache(
    name: "images",
    memoryLimit: 100 * 1024 * 1024,
    diskLimit: 500 * 1024 * 1024
)

// Cache an image
await imageCache.setImage(image, forKey: "avatar")

// Retrieve
let image = await imageCache.image(forKey: "avatar")

// Fetch from URL with caching
let networkImage = try await imageCache.image(from: imageURL)

// With options
await imageCache.setImage(image, forKey: "thumb", options: .memoryEfficient)
```

## 📊 Statistics & Monitoring

### Cache Statistics

```swift
let stats = await cache.getStatistics()

print("Hit count: \(stats.hitCount)")
print("Miss count: \(stats.missCount)")
print("Hit rate: \(stats.hitRate)%")
print("Item count: \(stats.itemCount)")
print("Total bytes: \(stats.totalBytes)")
print("Eviction count: \(stats.evictionCount)")
```

### Cache Observers

```swift
// Closure observer
let observer = ClosureObserver { event in
    switch event {
    case .added(let key):
        print("Added: \(key)")
    case .evicted(let key, let reason):
        print("Evicted \(key): \(reason)")
    case .memoryWarning:
        print("Memory pressure!")
    default:
        break
    }
}

let token = await cache.addObserver(observer)

// Remove observer when done
await cache.removeObserver(token)

// Logging observer
let logger = LoggingObserver(minLevel: .info)
await cache.addObserver(logger)
```

### Memory Warning Handling

```swift
// Register cache for automatic memory management
let handler = MemoryWarningHandler.shared
handler.register(cache: cache, priority: .normal)

// Manual eviction
handler.triggerEviction(level: .high)

// Check memory info
let info = handler.memoryInfo
print("Usage: \(info.formattedUsed) / \(info.formattedTotal)")
```

## 🔧 Serialization

### Built-in Serializers

```swift
// JSON (default)
let jsonSerializer = JSONCacheSerializer()

// Property List
let plistSerializer = PropertyListSerializer(format: .binary)

// Compressed
let compressedSerializer = CompressionSerializer(
    base: JSONCacheSerializer(),
    algorithm: .lz4
)
```

### Custom Serializer

```swift
struct ProtobufSerializer: CacheSerializer {
    func encode<T: Codable & Sendable>(_ value: T) throws -> Data {
        // Custom encoding
    }
    
    func decode<T: Codable & Sendable>(_ data: Data) throws -> T {
        // Custom decoding
    }
}
```

## 🔐 Cache Policies

```swift
let policy = CachePolicy(
    readPolicy: .cacheFirst,    // Check cache before network
    writePolicy: .writeThrough, // Write to both cache and storage
    stalePolicy: .revalidate,   // Return stale while fetching fresh
    failurePolicy: .returnStale // Return stale on network failure
)

// Preset policies
let aggressive = CachePolicy.cacheFirst
let fresh = CachePolicy.networkFirst
let offline = CachePolicy.offlineFirst
```

## 📝 Configuration

### Full Configuration Example

```swift
let config = CacheConfiguration(
    // Memory limits
    maxItemCount: 1000,
    maxMemoryBytes: 100 * 1024 * 1024,
    
    // Eviction
    evictionPolicy: .lru,
    
    // Expiration
    defaultExpiration: .seconds(3600),
    cleanupInterval: 60,
    lazyExpiration: true,
    
    // Behavior
    trackStatistics: true,
    threadSafe: true,
    notifyObservers: true,
    
    // Disk (for hybrid cache)
    maxDiskBytes: 500 * 1024 * 1024,
    fileProtection: .complete,
    
    // Network
    networkTimeout: 30,
    cacheNetworkErrors: false
)
```

### Configuration Builder

```swift
let config = CacheConfigurationBuilder()
    .maxItems(1000)
    .maxMemory(100 * 1024 * 1024)
    .eviction(.lru)
    .expiration(.seconds(3600))
    .cleanupInterval(60)
    .trackStatistics(true)
    .build()
```

## 🧪 Testing

Run tests:

```bash
swift test
```

Example test:

```swift
func testCacheHitRate() async throws {
    let cache = MemoryCache<String, String>()
    
    await cache.set("key", value: "value")
    
    // 3 hits, 1 miss = 75%
    _ = await cache.get("key")
    _ = await cache.get("key")
    _ = await cache.get("key")
    _ = await cache.get("missing")
    
    let stats = await cache.getStatistics()
    XCTAssertEqual(stats.hitRate, 75.0)
}
```

## 🏗️ Architecture

```
SwiftCache/
├── Core/
│   ├── Cache.swift              # Protocols and base types
│   ├── CacheConfiguration.swift # Configuration options
│   └── CachePolicy.swift        # Caching policies
├── Memory/
│   ├── MemoryCache.swift        # Main memory cache
│   ├── LRUCache.swift           # LRU implementation
│   ├── FIFOCache.swift          # FIFO implementation
│   └── WeakCache.swift          # Weak reference cache
├── Disk/
│   ├── DiskCache.swift          # Persistent cache
│   └── FileManager+Cache.swift  # File utilities
├── Hybrid/
│   └── HybridCache.swift        # Memory + Disk
├── Network/
│   ├── CachedURLSession.swift   # HTTP caching
│   ├── ImageCache.swift         # Image-specific cache
│   └── ResponseCache.swift      # API response cache
├── Serialization/
│   ├── Serializer.swift         # Serialization protocols
│   └── JSONSerializer.swift     # JSON implementation
├── Expiration/
│   ├── ExpirationPolicy.swift   # Expiration strategies
│   └── TimeBasedExpiration.swift
├── Observers/
│   ├── CacheObserver.swift      # Observer protocol
│   └── MemoryWarningHandler.swift
└── Extensions/
    ├── Data+Hashing.swift       # Data utilities
    └── String+Cache.swift       # String utilities
```

## 📖 Best Practices

### 1. Choose the Right Cache Type

```swift
// For UI data that changes frequently
let uiCache = MemoryCache<String, ViewModel>()

// For large persistent data
let mediaCache = try DiskCache<String, Data>(name: "media")

// For data that needs both speed and persistence
let apiCache = try HybridCache<String, Response>(name: "api")
```

### 2. Set Appropriate Limits

```swift
// Memory-constrained devices
let config = CacheConfiguration.lowMemory

// High-performance needs
let config = CacheConfiguration.highPerformance
```

### 3. Use Expiration Wisely

```swift
// Session data - expires when session ends
await cache.set("session", value: data, expiration: .date(sessionEndDate))

// Static content - longer TTL
await cache.set("config", value: data, expiration: .oneDay)

// Real-time data - short TTL
await cache.set("price", value: data, expiration: .seconds(30))
```

### 4. Monitor Performance

```swift
// Log cache performance periodically
Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
    Task {
        let stats = await cache.getStatistics()
        if stats.hitRate < 70 {
            print("Warning: Low cache hit rate: \(stats.hitRate)%")
        }
    }
}
```

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a PR.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

SwiftCache is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## 🙏 Acknowledgments

- Inspired by NSCache and popular caching libraries
- Thanks to the Swift community for async/await and actors

---

Made with ❤️ by [Muhittin Camdali](https://github.com/muhittincamdali)
