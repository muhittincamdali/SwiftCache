<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOS-Networking-Architecture-Pro/master/.github/brand/banner-tr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOS-Networking-Architecture-Pro/master/.github/brand/banner-tr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOS-Networking-Architecture-Pro/master/.github/brand/banner-tr-light.svg" alt="Networking Architecture: URLSession üzerinde tipli endpoint'ler, retry, token yenileme, önbellek ve streaming; bağımlılık yok."></picture></p>

<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a></p>

# SwiftCache taşındı

Bu proje artık [iOS-Networking-Architecture-Pro](https://github.com/muhittincamdali/iOS-Networking-Architecture-Pro) içinde yaşıyor. Bu depo arşivlendi ve artık değişiklik almıyor.

LRU önbelleği orada Swift 6 için, testlerle `LRUCache` olarak yeniden yazıldı ve bir `NetworkClient`'ın bellek, disk ve hibrit response önbellekleri olarak kullanılıyor. Bunlar genel amaçlı bir key-value önbelleği değil: HTTP response'larını saklıyor ve bir `CachePolicy` (`cacheFirst`, `networkFirst` veya `revalidate`) üzerinden kullanılıyor. Pakette ayrıca kendi `RetryPolicy` ve `CircuitBreaker` tipleri var. Bu depodaki her şey taşınmadı: SQLite hibrit disk adaptörü, Redis bridge ve delta compressor yalnızca mesaj yazdıran yer tutuculardı; event bus, metrics collector ve error handler'ın yeni pakette karşılığı yok. [Changelog](https://github.com/muhittincamdali/iOS-Networking-Architecture-Pro/blob/master/CHANGELOG.md) nelerin birleştirildiğini listeliyor.

- Önbellekler: [Sources/NetworkingArchitecture/Cache](https://github.com/muhittincamdali/iOS-Networking-Architecture-Pro/tree/master/Sources/NetworkingArchitecture/Cache)
- Retry ve circuit breaker: [Sources/NetworkingArchitecture/Retry](https://github.com/muhittincamdali/iOS-Networking-Architecture-Pro/tree/master/Sources/NetworkingArchitecture/Retry)
- Dokümantasyon: [NetworkingArchitecture](https://muhittincamdali.github.io/iOS-Networking-Architecture-Pro/documentation/networkingarchitecture/)

## Yeni paketi kurun

Yeni paket iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ veya visionOS 1+ ve Swift 6.2 gerektirir.

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

İki paket arasında public tipler değişti; geçiş import'ları ve çağrı yerlerini yeniden adlandırmayı gerektirir. Eski kod referans için burada olduğu gibi duruyor.
