import Foundation

/// App-wide localization helper.
///
/// Resolves the given English key against `Localizable.strings` in the main
/// bundle's `.lproj` resources. Follows the user's in-app language selection
/// (set via the language picker in the app); when the user chose
/// "System Default", the system's preferred language (System Settings →
/// Language & Region) is used. Falls back to the English key itself when no
/// translation is available, so the app always shows readable text even if a
/// language pack is missing.
func L(_ key: String) -> String {
    // Use the user-selected bundle when one is set.
    if let bundle = LanguageManager.shared.selectedBundle {
        let localized = bundle.localizedString(forKey: key, value: key, table: nil)
        if localized != key {
            return localized
        }
        // Fall through to the system-language lookup if the key is missing
        // from the selected bundle.
    }
    return Bundle.main.localizedString(forKey: key, value: key, table: nil)
}