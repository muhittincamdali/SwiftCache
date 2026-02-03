// MemoryWarningHandler.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Memory Warning Handler

/// Handles system memory warnings and manages cache eviction.
///
/// `MemoryWarningHandler` monitors system memory pressure and
/// automatically evicts cache entries when memory is low.
///
/// ## Overview
/// Register your caches with the handler to enable automatic
/// memory management.
///
/// ```swift
/// let cache = MemoryCache<String, Data>()
/// let handler = MemoryWarningHandler.shared
///
/// handler.register(cache: cache, priority: .high)
///
/// // Cache will automatically reduce size on memory warnings
/// ```
///
/// ## Memory Levels
/// The handler responds to different memory pressure levels:
/// - **Low**: Evict 25% of low-priority caches
/// - **Medium**: Evict 50% of normal priority and below
/// - **High**: Evict 75% of all caches
/// - **Critical**: Clear all caches
public final class MemoryWarningHandler: @unchecked Sendable {
    
    // MARK: - Types
    
    /// Memory pressure level.
    public enum PressureLevel: Int, Sendable, Comparable {
        case normal = 0
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
        
        public static func < (lhs: PressureLevel, rhs: PressureLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Cache eviction priority.
    public enum EvictionPriority: Int, Sendable {
        /// Evict first when memory is low.
        case low = 0
        
        /// Default priority.
        case normal = 1
        
        /// Try to keep in memory.
        case high = 2
        
        /// Only evict in critical situations.
        case critical = 3
    }
    
    /// Registered cache entry.
    private struct CacheEntry: Sendable {
        let cache: any EvictableCache
        let priority: EvictionPriority
    }
    
    // MARK: - Properties
    
    /// Shared instance.
    public static let shared = MemoryWarningHandler()
    
    /// Registered caches.
    private var caches: [UUID: CacheEntry] = [:]
    
    /// Lock for thread safety.
    private let lock = NSLock()
    
    /// Current pressure level.
    private var currentPressure: PressureLevel = .normal
    
    /// Observers for pressure changes.
    private var pressureObservers: [(PressureLevel) -> Void] = []
    
    /// Whether monitoring is active.
    private var isMonitoring = false
    
    // MARK: - Initialization
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Registration
    
    /// Registers a cache for memory management.
    ///
    /// - Parameters:
    ///   - cache: Cache to register.
    ///   - priority: Eviction priority.
    /// - Returns: Registration ID for unregistering.
    @discardableResult
    public func register<C: EvictableCache>(cache: C, priority: EvictionPriority = .normal) -> UUID {
        let id = UUID()
        let entry = CacheEntry(cache: cache, priority: priority)
        
        lock.lock()
        caches[id] = entry
        lock.unlock()
        
        return id
    }
    
    /// Unregisters a cache.
    ///
    /// - Parameter id: Registration ID.
    public func unregister(id: UUID) {
        lock.lock()
        caches.removeValue(forKey: id)
        lock.unlock()
    }
    
    /// Unregisters all caches.
    public func unregisterAll() {
        lock.lock()
        caches.removeAll()
        lock.unlock()
    }
    
    // MARK: - Pressure Monitoring
    
    /// Starts monitoring memory pressure.
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        #if os(macOS)
        // macOS uses dispatch source for memory pressure
        startDispatchSourceMonitoring()
        #endif
    }
    
    /// Stops monitoring memory pressure.
    public func stopMonitoring() {
        isMonitoring = false
    }
    
    /// Adds an observer for pressure changes.
    ///
    /// - Parameter observer: Closure called when pressure changes.
    public func addPressureObserver(_ observer: @escaping (PressureLevel) -> Void) {
        lock.lock()
        pressureObservers.append(observer)
        lock.unlock()
    }
    
    /// Returns the current memory pressure level.
    public var pressureLevel: PressureLevel {
        currentPressure
    }
    
    // MARK: - Manual Eviction
    
    /// Manually triggers eviction at a specified level.
    ///
    /// - Parameter level: Pressure level to simulate.
    public func triggerEviction(level: PressureLevel) {
        handlePressure(level)
    }
    
    /// Evicts a percentage of all caches.
    ///
    /// - Parameter percentage: Percentage to evict (0-100).
    public func evictPercentage(_ percentage: Int) {
        let percent = max(0, min(100, percentage))
        
        lock.lock()
        let entries = Array(caches.values)
        lock.unlock()
        
        for entry in entries {
            Task {
                await entry.cache.evictPercentage(percent)
            }
        }
    }
    
    // MARK: - Memory Info
    
    /// Returns current memory usage information.
    public var memoryInfo: MemoryInfo {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return MemoryInfo(
                usedBytes: Int(info.resident_size),
                footprint: Int(info.resident_size),
                physicalMemory: Int(ProcessInfo.processInfo.physicalMemory)
            )
        }
        
        return MemoryInfo(
            usedBytes: 0,
            footprint: 0,
            physicalMemory: Int(ProcessInfo.processInfo.physicalMemory)
        )
    }
    
    // MARK: - Private Methods
    
    /// Sets up system notifications.
    private func setupNotifications() {
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePressure(.high)
        }
        #endif
    }
    
    #if os(macOS)
    /// Starts dispatch source monitoring on macOS.
    private func startDispatchSourceMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global()
        )
        
        source.setEventHandler { [weak self] in
            let event = source.data
            if event.contains(.critical) {
                self?.handlePressure(.critical)
            } else if event.contains(.warning) {
                self?.handlePressure(.high)
            }
        }
        
        source.resume()
    }
    #endif
    
    /// Handles memory pressure.
    private func handlePressure(_ level: PressureLevel) {
        currentPressure = level
        
        // Notify observers
        lock.lock()
        let observers = pressureObservers
        lock.unlock()
        
        for observer in observers {
            observer(level)
        }
        
        // Evict based on level
        evictForPressure(level)
    }
    
    /// Evicts caches based on pressure level.
    private func evictForPressure(_ level: PressureLevel) {
        lock.lock()
        let entries = caches.values.sorted { $0.priority.rawValue < $1.priority.rawValue }
        lock.unlock()
        
        switch level {
        case .normal:
            return // No eviction needed
            
        case .low:
            // Evict 25% of low priority caches
            let lowPriority = entries.filter { $0.priority == .low }
            evictFromCaches(lowPriority, percentage: 25)
            
        case .medium:
            // Evict 50% of normal and below
            let normalAndBelow = entries.filter { $0.priority.rawValue <= EvictionPriority.normal.rawValue }
            evictFromCaches(normalAndBelow, percentage: 50)
            
        case .high:
            // Evict 75% of all except critical
            let nonCritical = entries.filter { $0.priority != .critical }
            evictFromCaches(nonCritical, percentage: 75)
            
        case .critical:
            // Clear all caches
            evictFromCaches(Array(entries), percentage: 100)
        }
    }
    
    /// Evicts from specified caches.
    private func evictFromCaches(_ entries: [CacheEntry], percentage: Int) {
        for entry in entries {
            Task {
                await entry.cache.evictPercentage(percentage)
            }
        }
    }
}

// MARK: - Evictable Cache Protocol

/// A protocol for caches that support eviction.
public protocol EvictableCache: Sendable {
    /// Evicts a percentage of cached items.
    ///
    /// - Parameter percentage: Percentage to evict (0-100).
    func evictPercentage(_ percentage: Int) async
    
    /// Clears all items.
    func clear() async
}

// MARK: - Memory Info

/// Information about current memory usage.
public struct MemoryInfo: Sendable {
    /// Bytes currently in use.
    public let usedBytes: Int
    
    /// Memory footprint.
    public let footprint: Int
    
    /// Total physical memory.
    public let physicalMemory: Int
    
    /// Usage percentage.
    public var usagePercentage: Double {
        guard physicalMemory > 0 else { return 0 }
        return Double(usedBytes) / Double(physicalMemory) * 100
    }
    
    /// Formatted used memory string.
    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .memory)
    }
    
    /// Formatted total memory string.
    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(physicalMemory), countStyle: .memory)
    }
}
