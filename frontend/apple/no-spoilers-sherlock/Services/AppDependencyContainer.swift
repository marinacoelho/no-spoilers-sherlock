import Foundation
import AppCore
import FirebaseCore
import FirebaseAppCheck

/// Dependency container that wires live `FirestoreBookRepository` and `FirebaseSherlockAIService` into `ChatViewModel`.
@MainActor
public final class AppDependencyContainer {
    public static let shared = AppDependencyContainer()

    public let bookRepository: any BookRepositoryProtocol
    public let aiService: any AiServiceProtocol

    public init(
        bookRepository: (any BookRepositoryProtocol)? = nil,
        aiService: (any AiServiceProtocol)? = nil
    ) {
        if FirebaseApp.app() == nil,
           Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            let providerFactory = AppCheckDebugProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
            FirebaseApp.configure()
        }

        self.bookRepository = bookRepository ?? FirestoreBookRepository()
        self.aiService = aiService ?? FirebaseSherlockAIService()
    }

    public func makeChatViewModel() -> ChatViewModel {
        ChatViewModel(
            repository: bookRepository,
            aiService: aiService
        )
    }
}
