import SwiftUI
import SubstratalKit

/// One window's place in the app. Sidebar selection and the current route are
/// per window, so two windows can show different screens.
@MainActor @Observable
final class WindowNavigation {
    var route: Route

    init(route: Route = .home) {
        self.route = route
    }

    /// The sidebar selection: the screen ID of the current route's sidebar root.
    var sidebarSelection: String? {
        get { route.screenID }
        set { if let newValue { route = Route(newValue) } }
    }

    func go(_ screenID: String) {
        route = Route(screenID)
    }
}

extension FocusedValues {
    /// The key window's navigation, for menu commands.
    @Entry var navigation: WindowNavigation?
}

/// `cmd+1`, `opt+cmd+2`, `ctrl+cmd+3` (screens.json) → a SwiftUI shortcut.
enum KeyCombo {
    static func shortcut(_ spec: String?) -> KeyboardShortcut? {
        guard let spec else { return nil }
        var modifiers: EventModifiers = []
        var key: Character?
        for part in spec.split(separator: "+") {
            switch part {
            case "cmd": modifiers.insert(.command)
            case "opt": modifiers.insert(.option)
            case "ctrl": modifiers.insert(.control)
            case "shift": modifiers.insert(.shift)
            default: key = part.first
            }
        }
        guard let key else { return nil }
        return KeyboardShortcut(KeyEquivalent(key), modifiers: modifiers)
    }
}
