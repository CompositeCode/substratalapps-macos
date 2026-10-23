import SwiftUI
import SubstratalKit

/// Signed out → the sign-in flow (AUTH-*); signed in → the split view.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var navigation: WindowNavigation

    init(initialRoute: Route? = nil) {
        _navigation = State(initialValue: WindowNavigation(route: initialRoute ?? .home))
    }

    var body: some View {
        Group {
            switch model.phase {
            case .launching:
                ProgressView("Signing in…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                SignInFlowView()
            case .signedIn:
                MainSplitView()
                    .environment(navigation)
                    .focusedSceneValue(\.navigation, navigation)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VersionBanner(status: model.versionStatus)
        }
        .onOpenURL { url in
            if let route = model.resolver.route(for: url) { navigation.route = route }
        }
    }
}
