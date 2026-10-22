import Foundation

/// Namespace and version metadata for the `AppCore` domain and state module.
public struct AppCoreModel: Sendable, Equatable {
    /// Identifier of the `AppCoreModel` instance.
    public var id: String

    /// Creates a new `AppCoreModel` instance.
    ///
    /// - Parameter id: Unique identifier string.
    public init(id: String) {
        self.id = id
    }
}
