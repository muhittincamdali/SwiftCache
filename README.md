<div align="center">

# 💾 SwiftCache

**Modern protocol-oriented caching framework with multi-layer storage for iOS**

[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-Compatible-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/muhittincamdali/SwiftCache/ci.yml?style=for-the-badge&logo=github)](https://github.com/muhittincamdali/SwiftCache/actions)

[Features](#-features) • [Installation](#-installation) • [Quick Start](#-quick-start) • [Documentation](#-documentation)

</div>

---

## ✨ Features

- 💾 **Multi-Layer Cache** — Memory + Disk with automatic fallback
- 🔄 **Async/Await** — Modern Swift concurrency throughout
- 📊 **Type-Safe** — Generic API with Codable support
- ⏱️ **TTL Support** — Configurable expiration policies
- 🧹 **Auto Cleanup** — Automatic memory pressure handling
- 🔐 **Thread-Safe** — Actor-based concurrency
- 📦 **Zero Dependencies** — Pure Swift implementation
- 🧪 **Fully Tested** — Comprehensive test coverage

---

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/SwiftCache.git", from: "1.0.0")
]
```

---

## 🚀 Quick Start

```swift
import SwiftCache

// Create cache
let cache = Cache<String, User>()

// Store
await cache.set("user_123", value: user)

// Retrieve
if let user = await cache.get("user_123") {
    print(user.name)
}

// With expiration
await cache.set("session", value: token, ttl: .minutes(30))

// Clear
await cache.removeAll()
```

### Disk Cache

```swift
let diskCache = DiskCache<String, Data>(
    name: "images",
    maxSize: 100 * 1024 * 1024 // 100MB
)

await diskCache.set("avatar", value: imageData)
```

---

## 📚 Documentation

| Resource | Description |
|----------|-------------|
| [Getting Started](Documentation/GettingStarted.md) | Quick tutorial |
| [Configuration](Documentation/Configuration.md) | Cache options |
| [API Reference](Documentation/API.md) | Full API docs |

---

## 🛠 Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS | 15.0+ |
| macOS | 12.0+ |
| tvOS | 15.0+ |
| watchOS | 8.0+ |
| Swift | 5.9+ |

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 📄 License

MIT License - see [LICENSE](LICENSE)

---

## 👨‍💻 Author

**Muhittin Camdali** • [@muhittincamdali](https://github.com/muhittincamdali)
