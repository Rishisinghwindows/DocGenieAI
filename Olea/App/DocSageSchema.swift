import Foundation
import SwiftData

/// Versioned schema definition. The current set of @Model types lives at V1.
/// When you add a *required* field or rename/remove a field, bump to V2 and add a
/// `MigrationStage` to `DocSageMigrationPlan.stages` describing how to translate old
/// rows into the new shape. Adding *optional* fields is handled by lightweight
/// migration automatically and does not require a new version.
enum DocSageSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            DocumentFile.self,
            ChatMessage.self,
            Conversation.self,
            ChatMemory.self,
            DocumentFolder.self
        ]
    }
}

enum DocSageMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [DocSageSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
