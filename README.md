<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOS-Networking-Architecture-Pro/master/.github/brand/banner-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOS-Networking-Architecture-Pro/master/.github/brand/banner-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOS-Networking-Architecture-Pro/master/.github/brand/banner-light.svg" alt="Networking Architecture: Typed endpoints, retries, token refresh, caching and streaming on URLSession, without dependencies."></picture></p>

<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a></p>

# SwiftCache has moved

This project now lives in [iOS-Networking-Architecture-Pro](https://github.com/muhittincamdali/iOS-Networking-Architecture-Pro). This repository is archived and no longer receives changes.

The LRU cache was rewritten there for Swift 6, with tests, as `LRUCache`, and put to work as the memory, disk and hybrid response caches of a `NetworkClient`. They are not a general-purpose key-value cache: they store HTTP responses and are used through a `CachePolicy` (`cacheFirst`, `networkFirst` or `revalidate`). The package also has a `RetryPolicy` and a `CircuitBreaker` of its own. Not everything from this repository was carried over: the SQLite hybrid disk adapter, the Redis bridge and the delta compressor were placeholders that only printed a message, and the event bus, the metrics collector and the error handler have no counterpart. The [changelog](https://github.com/muhittincamdali/iOS-Networking-Architecture-Pro/blob/master/CHANGELOG.md) lists what was merged.

- Caches: [Sources/NetworkingArchitecture/Cache](https://github.com/muhittincamdali/iOS-Networking-Architecture-Pro/tree/master/Sources/NetworkingArchitecture/Cache)
- Retry and circuit breaker: [Sources/NetworkingArchitecture/Retry](https://github.com/muhittincamdali/iOS-Networking-Architecture-Pro/tree/master/Sources/NetworkingArchitecture/Retry)
- Documentation: [NetworkingArchitecture](https://muhittincamdali.github.io/iOS-Networking-Architecture-Pro/documentation/networkingarchitecture/)

## Install the new package

The new package needs iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ or visionOS 1+, and Swift 6.2.

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/iOS-Networking-Architecture-Pro.git", from: "2.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "NetworkingArchitecture", package: "iOS-Networking-Architecture-Pro")
    ])
]
```

The public types changed between the two packages, so moving over means renaming imports and call sites. The old code stays here, unchanged, for reference.
