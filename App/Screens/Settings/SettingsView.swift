import SwiftUI
import SubstratalKit

/// The Settings scene (⌘,): global preferences (SET-01) plus app preferences.
struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettings()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            ConnectionSettings()
                .tabItem { Label("Connection", systemImage: "network") }
        }
        .frame(width: 520, height: 360)
    }
}

/// SET-01 appearance: mode plus the light and dark theme (THEMES.md).
struct AppearanceSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var theme = model.theme
        Form {
            Picker("Appearance", selection: $theme.mode) {
                Text("Match System").tag(ThemeMode.system)
                Text("Light").tag(ThemeMode.light)
                Text("Dark").tag(ThemeMode.dark)
            }
            .pickerStyle(.segmented)
            Picker("Light theme", selection: $theme.light) {
                ForEach(LightTheme.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Dark theme", selection: $theme.dark) {
                ForEach(DarkTheme.allCases) { Text($0.displayName).tag($0) }
            }
        }
        .formStyle(.grouped)
    }
}

/// Which API deployment the Hub talks to. Production for everyone; the local
/// devserver (`make run` in the API repo) for development.
struct ConnectionSettings: View {
    @Environment(AppModel.self) private var model
    @State private var localURL = "http://localhost:8080"

    var body: some View {
        Form {
            Picker("API", selection: Binding(
                get: { model.environment == .production ? 0 : 1 },
                set: { choice in
                    let target: APIEnvironment = choice == 0
                        ? .production
                        : .local(URL(string: localURL) ?? APIEnvironment.localDefault.baseURL)
                    Task { await model.switchEnvironment(to: target) }
                }
            )) {
                Text("Production (api.substratalapps.com)").tag(0)
                Text("Local devserver").tag(1)
            }
            .pickerStyle(.radioGroup)
            TextField("Devserver URL", text: $localURL)
                .disabled(model.environment == .production)
            LabeledContent("API version", value: "Substratal-Version: \(APIVersion.headerValue)")
            LabeledContent("Base URL", value: model.environment.baseURL.absoluteString)
            Text("Switching signs you out. Each environment keeps its own session.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
