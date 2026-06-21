//
//  AppLogger.swift
//  DocGenieAI
//
//  Role: Centralized OSLog categories for production observability.
//
//  Why one place: Apple's Console.app filters by `subsystem` and `category`,
//  so a single `subsystem` per app is the right shape. Categories let on-call
//  / support filter the firehose to just the relevant slice ("show me only
//  AI events on this device").
//
//  Live tail (during development):
//    xcrun simctl spawn booted log stream \
//        --predicate 'subsystem == "com.docgenieai.app"'
//
//  Filtering one category:
//    xcrun simctl spawn booted log stream \
//        --predicate 'subsystem == "com.docgenieai.app" && category == "ai"'
//
//  Tied to MetricKit via `CrashReporter` so daily crash reports appear in
//  the same stream alongside our own log events.
//

import OSLog

enum AppLogger {
    static let subsystem = "com.docgenieai.app"

    static let storage  = Logger(subsystem: subsystem, category: "storage")
    static let importer = Logger(subsystem: subsystem, category: "import")
    static let ai       = Logger(subsystem: subsystem, category: "ai")
    static let pdf      = Logger(subsystem: subsystem, category: "pdf")
    static let location = Logger(subsystem: subsystem, category: "location")
    static let contacts = Logger(subsystem: subsystem, category: "contacts")
    static let intents  = Logger(subsystem: subsystem, category: "intents")
    static let ui       = Logger(subsystem: subsystem, category: "ui")
}
