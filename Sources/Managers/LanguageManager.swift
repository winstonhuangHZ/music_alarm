import Foundation
import Combine

/// In-app language switcher. Persists the user's chosen language in
/// UserDefaults; `""` means "follow the system language".
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    /// Selected language code (e.g. "en", "zh-Hans"). Empty string = system default.
    @Published var selectedLanguage: String {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: languageKey)
            UserDefaults.standard.synchronize()
        }
    }

    private let languageKey = "MusicAlarm.language.v1"

    /// All languages supported by the app (code + native display name).
    /// The names are shown in their own language so users can identify them.
    static let supportedLanguages: [(code: String, displayName: String)] = [
        ("", "System Default"),
        ("en", "English"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("fr", "Français"),
        ("es", "Español"),
        ("ru", "Русский"),
        ("ar", "العربية")
    ]

    private init() {
        let saved = UserDefaults.standard.string(forKey: languageKey) ?? ""
        selectedLanguage = saved
    }

    /// Resolves a `.lproj` bundle for the selected language, if the user
    /// explicitly chose one. Returns nil to fall back to system language.
    var selectedBundle: Bundle? {
        guard !selectedLanguage.isEmpty,
              let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}