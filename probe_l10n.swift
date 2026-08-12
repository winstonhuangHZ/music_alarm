import Foundation

let appPath = "V2/dist/MusicAlarm.app"
guard let bundle = Bundle(path: appPath) else {
    print("FAIL: cannot open bundle at \(appPath)")
    exit(1)
}

// 1) Explicit-preferences API (no UserDefaults involved): proves the lproj
//    → language mapping that Bundle.localizedString uses internally.
print("localizations = \(bundle.localizations)")
print("")
for lang in ["en", "fr", "es", "ru", "zh-Hans", "zh-Hant", "ar"] {
    let pl = Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: [lang])
    print("preferred(from:forPreferences: [\(lang)]) = \(pl)")
}
print("")

// 2) Confirm translations actually exist in each bundled strings file.
for lang in ["en", "fr", "es", "ru", "zh-Hans", "zh-Hant", "ar"] {
    guard let p = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: lang),
          let s = try? String(contentsOfFile: p, encoding: .utf8) else {
        print("[\(lang)] FILE NOT FOUND")
        continue
    }
    var line = ""
    for l in s.split(separator: "\n") where l.hasPrefix("\"Add Alarm\"") {
        line = String(l)
    }
    print("[\(lang)] \(line)")
}
