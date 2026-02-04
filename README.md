<p align="center">
  <img src="Assets/logo.png" alt="SwiftCache" width="200"/>
</p>

<h1 align="center">SwiftCache</h1>

<p align="center">
  <strong>💾 Modern protocol-oriented caching framework with multi-layer storage for iOS</strong>
</p>

<p align="center">
  <a href="https://github.com/muhittincamdali/SwiftCache/actions/workflows/ci.yml">
    <img src="https://github.com/muhittincamdali/SwiftCache/actions/workflows/ci.yml/badge.svg" alt="CI"/>
  </a>
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift 6.0"/>
  <img src="https://img.shields.io/badge/iOS-17.0+-blue.svg" alt="iOS 17.0+"/>
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"/>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#documentation">Documentation</a>
</p>

---

## Why SwiftCache?

iOS caching is fragmented - NSCache for memory, FileManager for disk, each with different APIs. **SwiftCache** unifies everything with a clean, protocol-oriented design.

```swift
// Before: Different APIs for each storage
let nsCache = NSCache<NSString, Data>()
let fileManager = FileManager.default
// Manual expiration tracking...

// After: Unified API
let cache = Cache<User>()
cache.set(user, forKey: "current_user", expiration: .hours(24))
let user = try await cache.get("current_user")
```

## Features

| Feature | Description |
|---------|-------------|
| 🏗️ **Multi-Layer** | Memory + Disk + Custom layers |
| ⏰ **Expiration** | TTL, date-based, custom policies |
| 🔄 **Async/Await** | Modern Swift concurrency |
| 🧹 **Auto Cleanup** | Automatic expired entry removal |
| 📦 **Type-Safe** | Generic, Codable support |
| 📊 **Metrics** | Hit/miss rates, size tracking |
| 🧪 **Testable** | Protocol-based, mockable |

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/SwiftCache.git", from: "1.0.0")
]
```

## Quick Start

### Basic Usage

```swift
import SwiftCache

// Create cache for any Codable type
let cache = Cache<User>()

// Store
try await cache.set(user, forKey: "user_123")

// Retrieve
if let user = try await cache.get("user_123") {
    print("Found: \(user.name)")
}

// Remove
try await cache.remove("user_123")

// Clear all
try await cache.clear()
```

### With Expiration

```swift
// Expire after duration
try await cache.set(user, forKey: "user", expiration: .minutes(30))

// Expire at specific date
try await cache.set(user, forKey: "user", expiration: .date(tomorrow))

// Never expire
try await cache.set(user, forKey: "user", expiration: .never)
```

## Storage Layers

### Memory Only (Fast)

```swift
let cache = Cache<User>(storage: .memory(
    countLimit: 100,
    totalCostLimit: 50_000_000 // 50MB
))
```

### Disk Only (Persistent)

```swift
let cache = Cache<User>(storage: .disk(
    directory: .cachesDirectory,
    sizeLimit: 100_000_000 // 100MB
))
```

### Multi-Layer (Recommended)

```swift
let cache = Cache<User>(storage: .hybrid(
    memory: MemoryStorage(countLimit: 50),
    disk: DiskStorage(sizeLimit: 100_000_000)
))

// Read: Memory → Disk → Miss
// Write: Memory + Disk
```

## Image Caching

Built-in image support with optimizations:

```swift
let imageCache = ImageCache()

// Cache image
await imageCache.set(image, forKey: url.absoluteString)

// Retrieve with resize
let thumbnail = await imageCache.get(
    url.absoluteString,
    resize: CGSize(width: 100, height: 100)
)

// SwiftUI integration
AsyncCachedImage(url: imageURL) { phase in
    switch phase {
    case .success(let image):
        image.resizable()
    case .failure:
        Image(systemName: "photo")
    case .empty:
        ProgressView()
    }
}
```

## Expiration Policies

### Time-Based

```swift
.seconds(30)
.minutes(5)
.hours(24)
.days(7)
```

### Custom Policy

```swift
struct BusinessHoursExpiration: ExpirationPolicy {
    func isExpired(cachedAt: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        return hour < 9 || hour > 17 // Expire outside business hours
    }
}
```

## Network Caching

Integrate with URLSession:

```swift
let networkCache = Cache<Data>(storage: .hybrid())

func fetchData(from url: URL) async throws -> Data {
    // Check cache first
    if let cached = try await networkCache.get(url.absoluteString) {
        return cached
    }
    
    // Fetch from network
    let (data, response) = try await URLSession.shared.data(from: url)
    
    // Cache based on HTTP headers
    let expiration = CacheExpiration(response: response) ?? .hours(1)
    try await networkCache.set(data, forKey: url.absoluteString, expiration: expiration)
    
    return data
}
```

## Metrics & Monitoring

```swift
let cache = Cache<User>()
cache.metricsEnabled = true

// Later...
let metrics = cache.metrics
print("Hit rate: \(metrics.hitRate)%")
print("Total requests: \(metrics.totalRequests)")
print("Cache size: \(metrics.currentSize) bytes")
```

## Migration

### From NSCache

```swift
// Before
let nsCache = NSCache<NSString, Data>()
nsCache.setObject(data, forKey: "key" as NSString)
let data = nsCache.object(forKey: "key" as NSString)

// After
let cache = Cache<Data>()
try await cache.set(data, forKey: "key")
let data = try await cache.get("key")
```

### From UserDefaults

```swift
// Before (not ideal for large data)
UserDefaults.standard.set(data, forKey: "key")

// After (proper caching)
let cache = Cache<Data>(storage: .disk())
try await cache.set(data, forKey: "key")
```

## Best Practices

### Key Strategy

```swift
// ✅ Good: Namespaced, versioned
let key = "users_v2_\(userId)"

// ❌ Avoid: Generic keys
let key = "user"
```

### Memory Management

```swift
// Configure limits based on device
let cache = Cache<Data>(storage: .memory(
    countLimit: ProcessInfo.processInfo.physicalMemory > 4_000_000_000 ? 200 : 50
))
```

### Error Handling

```swift
do {
    try await cache.set(largeData, forKey: "key")
} catch CacheError.storageFull {
    // Handle full storage
    try await cache.clear()
} catch {
    // Handle other errors
}
```

## API Reference

### Cache

```swift
class Cache<Value: Codable>: Sendable {
    func get(_ key: String) async throws -> Value?
    func set(_ value: Value, forKey key: String, expiration: Expiration) async throws
    func remove(_ key: String) async throws
    func clear() async throws
    func contains(_ key: String) async -> Bool
}
```

### Expiration

```swift
enum Expiration {
    case never
    case seconds(Int)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case date(Date)
}
```

## Testing

```swift
class CacheTests: XCTestCase {
    func testSetAndGet() async throws {
        let cache = Cache<String>(storage: .memory())
        
        try await cache.set("Hello", forKey: "greeting")
        let value = try await cache.get("greeting")
        
        XCTAssertEqual(value, "Hello")
    }
    
    func testExpiration() async throws {
        let cache = Cache<String>()
        
        try await cache.set("Temp", forKey: "key", expiration: .seconds(1))
        
        try await Task.sleep(for: .seconds(2))
        
        let value = try await cache.get("key")
        XCTAssertNil(value)
    }
}
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License

---

<p align="center">
  <sub>Cache smarter, not harder 💾</sub>
</p>

---

## 📈 Star History

<a href="https://star-history.com/#muhittincamdali/SwiftCache&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=muhittincamdali/SwiftCache&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=muhittincamdali/SwiftCache&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=muhittincamdali/SwiftCache&type=Date" />
 </picture>
</a>
