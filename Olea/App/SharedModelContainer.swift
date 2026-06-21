//
//  SharedModelContainer.swift
//  DocGenieAI
//
//  Role: Process-wide ModelContainer. Single source of truth for SwiftData
//  across every entry point — the SwiftUI app, the App Intents (Siri/
//  Shortcuts), the Share Extension, future Widget intents.
//
//  Why a singleton: SwiftData expects exactly one ModelContainer per database
//  file. If we let App Intents create its own container parallel to the app's,
//  both write to the same SQLite store and corruption/deadlocks become
//  reachable from any concurrent execution. This file enforces one container
//  per process.
//
//  Schema versioning: deliberately uses unversioned `Schema([...])` rather
//  than `VersionedSchema`. Switching mid-deployment crashes when opening a
//  pre-existing store (reproduced in DiagnosticReports/DocGenieAI-2026-05-10).
//  When a real migration is required, see `DocSageSchema.swift` for the
//  scaffolding to enable then.
//
//  Fallback: if the persistent container fails to open (corrupt store,
//  insufficient disk), the lazy initializer falls back to in-memory mode so
//  the app launches and the user can reimport rather than seeing a crash.
//

import Foundation
import SwiftData

enum SharedModelContainer {
    static let shared: ModelContainer = {
        // NOTE: keep this Schema unversioned to match what previous app versions wrote on
        // disk — switching to VersionedSchema without migration stages crashes when
        // opening a pre-existing store. When you actually need a real migration, switch
        // to `Schema(versionedSchema: DocSageSchemaV2.self)` and add a MigrationStage.
        let schema = Schema([
            DocumentFile.self,
            ChatMessage.self,
            Conversation.self,
            ChatMemory.self,
            DocumentFolder.self
        ])
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            AppLogger.storage.error("Failed to create persistent ModelContainer: \(error.localizedDescription, privacy: .public). Falling back to in-memory store.")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Failed to create even an in-memory ModelContainer: \(error)")
            }
        }
    }()
}
