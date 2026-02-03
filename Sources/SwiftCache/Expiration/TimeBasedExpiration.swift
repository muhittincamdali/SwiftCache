// TimeBasedExpiration.swift
// SwiftCache
//
// Created by Muhittin Camdali
// Copyright © 2025 All rights reserved.
//

import Foundation

// MARK: - Time Unit

/// Common time units for expiration configuration.
public enum TimeUnit: Sendable, Equatable {
    case seconds(Int)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case weeks(Int)
    
    /// Converts to seconds.
    public var totalSeconds: TimeInterval {
        switch self {
        case .seconds(let n): return TimeInterval(n)
        case .minutes(let n): return TimeInterval(n * 60)
        case .hours(let n): return TimeInterval(n * 3600)
        case .days(let n): return TimeInterval(n * 86400)
        case .weeks(let n): return TimeInterval(n * 604800)
        }
    }
    
    /// Converts to CacheExpiration.
    public var expiration: CacheExpiration {
        .seconds(totalSeconds)
    }
}

// MARK: - Expiration Calculator

/// Utility for calculating expiration dates.
public struct ExpirationCalculator: Sendable {
    
    /// Calculates expiration date from now.
    ///
    /// - Parameter unit: Time unit.
    /// - Returns: Expiration date.
    public static func date(from unit: TimeUnit) -> Date {
        Date().addingTimeInterval(unit.totalSeconds)
    }
    
    /// Calculates remaining time until a date.
    ///
    /// - Parameter date: Target date.
    /// - Returns: Time interval, or 0 if already passed.
    public static func remainingTime(until date: Date) -> TimeInterval {
        max(0, date.timeIntervalSinceNow)
    }
    
    /// Checks if a date has passed.
    ///
    /// - Parameter date: Date to check.
    /// - Returns: True if the date is in the past.
    public static func hasPassed(_ date: Date) -> Bool {
        Date() > date
    }
    
    /// Returns the end of the current day.
    ///
    /// - Parameter calendar: Calendar to use.
    /// - Returns: End of day date.
    public static func endOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: Date()).addingTimeInterval(86400 - 1)
    }
    
    /// Returns the start of tomorrow.
    ///
    /// - Parameter calendar: Calendar to use.
    /// - Returns: Start of tomorrow.
    public static func startOfTomorrow(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: Date()).addingTimeInterval(86400)
    }
    
    /// Returns the end of the current week.
    ///
    /// - Parameter calendar: Calendar to use.
    /// - Returns: End of week date.
    public static func endOfWeek(calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekOfYear! += 1
        return calendar.date(from: components)
    }
}

// MARK: - Expiration Presets

/// Common expiration presets for convenience.
public enum ExpirationPreset: Sendable {
    /// One minute.
    case oneMinute
    
    /// Five minutes.
    case fiveMinutes
    
    /// Fifteen minutes.
    case fifteenMinutes
    
    /// Thirty minutes.
    case thirtyMinutes
    
    /// One hour.
    case oneHour
    
    /// Six hours.
    case sixHours
    
    /// Twelve hours.
    case twelveHours
    
    /// One day.
    case oneDay
    
    /// One week.
    case oneWeek
    
    /// One month (30 days).
    case oneMonth
    
    /// Until end of day.
    case endOfDay
    
    /// Until end of week.
    case endOfWeek
    
    /// Never expires.
    case never
    
    /// Converts to CacheExpiration.
    public var expiration: CacheExpiration {
        switch self {
        case .oneMinute:
            return .seconds(60)
        case .fiveMinutes:
            return .seconds(300)
        case .fifteenMinutes:
            return .seconds(900)
        case .thirtyMinutes:
            return .seconds(1800)
        case .oneHour:
            return .seconds(3600)
        case .sixHours:
            return .seconds(21600)
        case .twelveHours:
            return .seconds(43200)
        case .oneDay:
            return .seconds(86400)
        case .oneWeek:
            return .seconds(604800)
        case .oneMonth:
            return .seconds(2592000)
        case .endOfDay:
            return .date(ExpirationCalculator.endOfDay())
        case .endOfWeek:
            if let date = ExpirationCalculator.endOfWeek() {
                return .date(date)
            }
            return .seconds(604800)
        case .never:
            return .never
        }
    }
}

// MARK: - CacheExpiration Extensions

extension CacheExpiration {
    
    /// Creates expiration from a time unit.
    ///
    /// - Parameter unit: Time unit.
    /// - Returns: Cache expiration.
    public static func from(_ unit: TimeUnit) -> CacheExpiration {
        unit.expiration
    }
    
    /// Creates expiration from a preset.
    ///
    /// - Parameter preset: Expiration preset.
    /// - Returns: Cache expiration.
    public static func preset(_ preset: ExpirationPreset) -> CacheExpiration {
        preset.expiration
    }
    
    /// Common preset: 5 minutes.
    public static let fiveMinutes = CacheExpiration.seconds(300)
    
    /// Common preset: 15 minutes.
    public static let fifteenMinutes = CacheExpiration.seconds(900)
    
    /// Common preset: 1 hour.
    public static let oneHour = CacheExpiration.seconds(3600)
    
    /// Common preset: 1 day.
    public static let oneDay = CacheExpiration.seconds(86400)
    
    /// Common preset: 1 week.
    public static let oneWeek = CacheExpiration.seconds(604800)
}

// MARK: - Scheduled Expiration

/// Expiration scheduled at a specific time.
public struct ScheduledExpiration: Sendable {
    
    /// The scheduled expiration date.
    public let date: Date
    
    /// Creates scheduled expiration at a specific date.
    ///
    /// - Parameter date: Expiration date.
    public init(at date: Date) {
        self.date = date
    }
    
    /// Creates scheduled expiration at a specific time today.
    ///
    /// - Parameters:
    ///   - hour: Hour (0-23).
    ///   - minute: Minute (0-59).
    ///   - calendar: Calendar to use.
    /// - Returns: Scheduled expiration, or nil if invalid.
    public static func today(
        at hour: Int,
        minute: Int = 0,
        calendar: Calendar = .current
    ) -> ScheduledExpiration? {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        
        guard let date = calendar.date(from: components) else { return nil }
        
        // If time has passed, schedule for tomorrow
        if date < Date() {
            return tomorrow(at: hour, minute: minute, calendar: calendar)
        }
        
        return ScheduledExpiration(at: date)
    }
    
    /// Creates scheduled expiration at a specific time tomorrow.
    ///
    /// - Parameters:
    ///   - hour: Hour (0-23).
    ///   - minute: Minute (0-59).
    ///   - calendar: Calendar to use.
    /// - Returns: Scheduled expiration, or nil if invalid.
    public static func tomorrow(
        at hour: Int,
        minute: Int = 0,
        calendar: Calendar = .current
    ) -> ScheduledExpiration? {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = hour
        components.minute = minute
        
        guard let date = calendar.date(from: components) else { return nil }
        return ScheduledExpiration(at: date)
    }
    
    /// Converts to CacheExpiration.
    public var expiration: CacheExpiration {
        .date(date)
    }
}
