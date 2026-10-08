import Foundation

enum AppLocalization {
    static var locale: Locale {
        Locale(identifier: UserDefaults.standard.string(forKey: "appLanguage") ?? "en")
    }

    static var isJapanese: Bool { locale.identifier.hasPrefix("ja") }

    static func text(_ english: String) -> String {
        String(localized: String.LocalizationValue(english), table: "Localizable", bundle: .main,
               locale: locale, comment: "")
    }
}
