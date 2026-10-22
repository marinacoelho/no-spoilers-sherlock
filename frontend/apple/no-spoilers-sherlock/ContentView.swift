import SwiftUI
import AppCore

public struct ContentView: View {
    @State private var viewModel = AppDependencyContainer.shared.makeChatViewModel()

    public init() {}

    public var body: some View {
        ChatScreen(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
