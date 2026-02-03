# Getting Started with SwiftCache

## Overview

SwiftCache provides a high-performance, type-safe caching solution for iOS.

## Basic Usage

```swift
import SwiftCache

let cache = Cache<String, MyModel>()

// Store
await cache.set("key", value: model)

// Retrieve
let value = await cache.get("key")

// Delete
await cache.remove("key")
```

## Configuration

```swift
let config = CacheConfiguration(
    memoryLimit: 50 * 1024 * 1024, // 50MB
    diskLimit: 200 * 1024 * 1024,  // 200MB
    defaultTTL: .hours(1)
)

let cache = Cache<String, Data>(configuration: config)
```
