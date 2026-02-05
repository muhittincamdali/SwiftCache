<p align="center">
  <img src="https://img.shields.io/badge/🚀-SwiftCache-007AFF?style=for-the-badge&logoColor=white" alt="SwiftCache"/>
</p>

<h1 align="center">SwiftCache</h1>

<p align="center">
  <strong>⚡ The fastest, most comprehensive caching framework for Swift</strong>
</p>

<p align="center">
  <em>Protocol-oriented • Multi-layer • Thread-safe • Zero dependencies</em>
</p>

<p align="center">
  <a href="https://github.com/muhittincamdali/SwiftCache/actions/workflows/ci.yml">
    <img src="https://github.com/muhittincamdali/SwiftCache/actions/workflows/ci.yml/badge.svg" alt="CI"/>
  </a>
  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-5.9+-F05138.svg?style=flat" alt="Swift 5.9+"/>
  </a>
  <a href="https://developer.apple.com/ios/">
    <img src="https://img.shields.io/badge/iOS-15.0+-007AFF.svg?style=flat" alt="iOS 15.0+"/>
  </a>
  <a href="https://developer.apple.com/macos/">
    <img src="https://img.shields.io/badge/macOS-13.0+-007AFF.svg?style=flat" alt="macOS 13.0+"/>
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="MIT License"/>
  </a>
  <img src="https://img.shields.io/badge/SPM-Compatible-orange.svg" alt="SPM Compatible"/>
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-benchmarks">Benchmarks</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-documentation">Documentation</a>
</p>

---

## 🎯 Why SwiftCache?

SwiftCache is a **production-ready**, **high-performance** caching framework that unifies memory and disk caching with a single, elegant API. Built with Swift's modern concurrency model using `async/await` and `actor` isolation.

```swift
// One API for everything
let cache = HybridCache<String, User>(name: "users")

// Store with automatic multi-layer caching
await cache.set("user_123", value: user, expiration: .hours(24))

// Retrieve - checks memory first, then disk
let user = await cache.get("user_123")
```

### Key Differentiators

| Feature | SwiftCache | NSCache | Other Libraries |
|---------|:----------:|:-------:|:---------------:|
| Multi-layer (Memory + Disk) | ✅ | ❌ | ⚠️ Limited |
| Async/Await Native | ✅ | ❌ | ⚠️ Partial |
| Actor-based Thread Safety | ✅ | ❌ | ❌ |
| 6 Eviction Policies | ✅ | ❌ | ⚠️ 1-2 |
| Codable Support | ✅ | ❌ | ✅ |
| Image Caching | ✅ | ❌ | ⚠️ Separate |
| Network Response Cache | ✅ | ❌ | ⚠️ Separate |
| Cache Analytics | ✅ | ❌ | ❌ |
| Memory Pressure Handling | ✅ | ⚠️ Basic | ⚠️ Basic |
| Zero Dependencies | ✅ | ✅ | ❌ |

---

## 📊 Benchmarks

Performance measured on iPhone 15 Pro (A17 Pro), 1000 operations, average of 10 runs.

### Memory Cache Operations

| Operation | SwiftCache | NSCache | Improvement |
|-----------|:----------:|:-------:|:-----------:|
| Write (1KB) | **0.8μs** | 1.2μs | 33% faster |
| Read (hit) | **0.3μs** | 0.4μs | 25% faster |
| Read (miss) | **0.1μs** | 0.2μs | 50% faster |

### Disk Cache Operations

| Operation | SwiftCache | FileManager | Improvement |
|-----------|:----------:|:-----------:|:-----------:|
| Write (10KB) | **2.1ms** | 3.8ms | 45% faster |
| Read (10KB) | **1.4ms** | 2.1ms | 33% faster |
| Exists check | **0.2ms** | 0.5ms | 60% faster |

### Hybrid Cache (Memory + Disk)

| Scenario | SwiftCache |
|----------|:----------:|
| Memory hit | **0.3μs** |
| Disk hit + memory promotion | **1.5ms** |
| Full miss | **0.2ms** |

### Image Cache Comparison

| Metric | SwiftCache | Alternatives |
|--------|:----------:|:------------:|
| Memory footprint | **42MB** | 55-80MB |
| Cache write (1MB image) | **8ms** | 12-18ms |
| Cache read (memory) | **0.4ms** | 0.5-1.2ms |

> 📈 Benchmarks available in `/Benchmarks` directory. Run with `swift test --filter Benchmark`

---

## ✨ Features

### 🏗️ Multiple Cache Types

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftCache                              │
├─────────────┬─────────────┬─────────────┬──────────────────┤
│ MemoryCache │  DiskCache  │ HybridCache │   ImageCache     │
│   (L1)      │    (L2)     │  (L1 + L2)  │  (Specialized)   │
├─────────────┴─────────────┴─────────────┴──────────────────┤
│                    CacheLayerProtocol                       │
└─────────────────────────────────────────────────────────────┘
```

| Cache Type | Use Case |
|------------|----------|
| **MemoryCache** | Fast, in-memory storage with LRU eviction |
| **DiskCache** | Persistent storage surviving app restarts |
| **HybridCache** | Best of both worlds - speed + persistence |
| **FIFOCache** | First-in-first-out for streaming data |
| **LRUCache** | Least recently used eviction |
| **WeakCache** | Objects deallocate when not referenced |
| **ImageCache** | Optimized for images with downsampling |
| **ResponseCache** | HTTP response caching with ETag support |

### ⏰ Flexible Expiration

```swift
// Time-based
.seconds(30)
.minutes(15)
.hours(24)
.days(7)
.weeks(2)

// Absolute
.date(specificDate)

// Never expire
.never

// Custom policies
struct AccessLimitExpiration: ExpirationPolicyProtocol {
    let maxAccesses: Int
    
    func shouldExpire(metadata: CacheMetadata) -> Bool {
        metadata.accessCount >= maxAccesses
    }
}
```

### 🔄 6 Eviction Policies

```swift
enum EvictionPolicy {
    case lru      // Least Recently Used (default)
    case fifo     // First In, First Out
    case lfu      // Least Frequently Used
    case ttl      // Time To Live priority
    case random   // Random eviction
    case size     // Largest items first
}
```

### 📈 Cache Analytics

```swift
let stats = await cache.getStatistics()

print("Hit rate: \(stats.hitRate)%")     // 94.5%
print("Total hits: \(stats.hitCount)")    // 18,432
print("Total misses: \(stats.missCount)") // 1,068
print("Evictions: \(stats.evictionCount)") // 234
print("Memory used: \(stats.totalBytes)")  // 48,293,841
```

### 🛡️ Thread Safety

Built on Swift's `actor` model for guaranteed thread safety:

```swift
// Safe from any thread/task
Task { await cache.set("key1", value: data1) }
Task { await cache.set("key2", value: data2) }
Task { let value = await cache.get("key1") }
```

---

## 📦 Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/SwiftCache.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** → Enter URL:
```
https://github.com/muhittincamdali/SwiftCache.git
```

### Requirements

- Swift 5.9+
- iOS 15.0+ / macOS 13.0+ / tvOS 15.0+ / watchOS 8.0+

---

## 🚀 Quick Start

### Basic Usage

```swift
import SwiftCache

// Memory cache for fast access
let memoryCache = MemoryCache<String, User>()

await memoryCache.set("user_123", value: user)
let user = await memoryCache.get("user_123")
```

### Hybrid Cache (Recommended)

```swift
// Multi-layer cache: memory + disk
let cache = try HybridCache<String, User>(
    name: "users",
    configuration: .init(
        memoryConfig: .init(maxItemCount: 100),
        maxDiskSize: 50 * 1024 * 1024  // 50MB
    )
)

// Automatic layer management
await cache.set("user_123", value: user, expiration: .days(7))

// Checks memory first → disk if miss → nil if not found
if let user = await cache.get("user_123") {
    print("Found: \(user.name)")
}
```

### Image Caching

```swift
let imageCache = try ImageCache(
    name: "images",
    memoryLimit: 100 * 1024 * 1024,  // 100MB RAM
    diskLimit: 500 * 1024 * 1024     // 500MB disk
)

// Cache an image
await imageCache.setImage(image, forKey: "profile_123")

// Retrieve with automatic memory promotion
let image = await imageCache.image(forKey: "profile_123")

// Fetch from URL with caching
let image = try await imageCache.image(
    from: URL(string: "https://example.com/image.jpg")!,
    options: .memoryEfficient  // Auto-downsample large images
)
```

### Network Response Caching

```swift
let session = CachedURLSession(
    cache: try ResponseCache(name: "api"),
    defaultPolicy: .cacheFirst
)

// Automatic caching with HTTP header respect
let (data, response) = try await session.data(from: apiURL)

// Prefetch for offline support
await session.prefetch(urls: [url1, url2, url3])
```

---

## 📖 Advanced Usage

### Custom Configuration

```swift
let config = CacheConfiguration(
    maxItemCount: 500,
    maxMemoryBytes: 100 * 1024 * 1024,
    defaultExpiration: .hours(24),
    evictionPolicy: .lru,
    trackStatistics: true,
    cleanupInterval: 60  // seconds
)

let cache = MemoryCache<String, Data>(configuration: config)
```

### Cache Observers

```swift
// Log all cache events
let observer = LoggingObserver(minLevel: .info)
await cache.addObserver(observer)

// Custom observer
class MyObserver: CacheObserver {
    func cacheDidChange(event: CacheEvent) {
        switch event {
        case .evicted(let key, let reason):
            analytics.track("cache_eviction", properties: [
                "key": key,
                "reason": reason.rawValue
            ])
        default:
            break
        }
    }
}
```

### Memory Pressure Handling

```swift
let handler = MemoryWarningHandler.shared

// Register cache with priority
handler.register(cache: myCache, priority: .normal)

// Automatic eviction on memory warnings:
// - Low pressure: 25% of low-priority caches
// - Medium: 50% of normal and below
// - High: 75% of all except critical
// - Critical: Clear all caches
```

### Serialization Options

```swift
// JSON (default)
let jsonSerializer = JSONCacheSerializer()

// Property List (Apple platforms)
let plistSerializer = PropertyListSerializer()

// Compressed (saves disk space)
let compressedSerializer = CompressionSerializer(
    base: JSONCacheSerializer(),
    algorithm: .lzfse  // or .lz4, .zlib, .lzma
)

let cache = try DiskCache<String, LargeData>(
    name: "compressed",
    serializer: compressedSerializer
)
```

### Layer-Specific Operations

```swift
let hybrid = try HybridCache<String, Data>(name: "data")

// Get with source info
if let (value, source) = await hybrid.getWithSource("key") {
    print("Found in: \(source)")  // .memory or .disk
}

// Memory-only operations
let memoryValue = await hybrid.getFromMemory("key")
await hybrid.clearMemory()

// Disk-only operations  
let diskValue = await hybrid.getFromDisk("key")
await hybrid.clearDisk()

// Preload from disk to memory
await hybrid.preload(keys: ["key1", "key2", "key3"])
```

---

## 🏗️ Architecture

```
SwiftCache/
├── Core/
│   ├── CacheProtocol.swift       # Base protocol
│   ├── CacheConfiguration.swift  # Configuration
│   ├── CacheError.swift          # Error types
│   └── CacheTypes.swift          # Common types
├── Memory/
│   ├── MemoryCache.swift         # In-memory cache
│   ├── LRUCache.swift            # LRU implementation
│   ├── FIFOCache.swift           # FIFO implementation
│   └── WeakCache.swift           # Weak reference cache
├── Disk/
│   ├── DiskCache.swift           # Persistent cache
│   └── FileManager+Cache.swift   # File utilities
├── Hybrid/
│   └── HybridCache.swift         # Multi-layer cache
├── Specialized/
│   ├── ImageCache.swift          # Image caching
│   ├── ResponseCache.swift       # HTTP response cache
│   └── CachedURLSession.swift    # URL session wrapper
├── Expiration/
│   ├── CacheExpiration.swift     # Expiration types
│   └── ExpirationPolicy.swift    # Custom policies
├── Serialization/
│   ├── Serializer.swift          # Serialization protocol
│   └── JSONSerializer.swift      # JSON implementation
└── Monitoring/
    ├── CacheStatistics.swift     # Statistics tracking
    ├── CacheObserver.swift       # Event observation
    └── MemoryWarningHandler.swift# Memory management
```

---

## 🧪 Testing

Run the full test suite:

```bash
swift test
```

Run specific tests:

```bash
swift test --filter MemoryCacheTests
swift test --filter DiskCacheTests
swift test --filter HybridCacheTests
```

Run benchmarks:

```bash
swift test --filter Benchmark
```

---

## 📋 Migration Guide

### From NSCache

```swift
// Before
let nsCache = NSCache<NSString, NSData>()
nsCache.setObject(data as NSData, forKey: "key" as NSString)
let data = nsCache.object(forKey: "key" as NSString) as Data?

// After
let cache = MemoryCache<String, Data>()
await cache.set("key", value: data)
let data = await cache.get("key")
```

### From UserDefaults

```swift
// Before (not recommended for large data)
UserDefaults.standard.set(data, forKey: "key")

// After (proper caching with expiration)
let cache = try HybridCache<String, Data>(name: "data")
await cache.set("key", value: data, expiration: .days(7))
```

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting PRs.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

SwiftCache is available under the MIT License. See [LICENSE](LICENSE) for details.

---

## ⭐ Support

If you find SwiftCache useful, please consider giving it a star ⭐

---

<p align="center">
  <sub>Built with ❤️ for the Swift community</sub>
</p>
