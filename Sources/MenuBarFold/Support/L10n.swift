import Foundation

enum L10n {
  static func string(_ key: String, language: AppLanguage) -> String {
    let code = resolvedLanguageCode(for: language)

    guard let path = Bundle.module.path(forResource: code, ofType: "lproj"),
      let bundle = Bundle(path: path)
    else {
      return key
    }

    return bundle.localizedString(forKey: key, value: key, table: nil)
  }

  static func formatted(
    _ key: String,
    language: AppLanguage,
    arguments: CVarArg...
  ) -> String {
    let format = string(key, language: language)
    return String(format: format, locale: locale(for: language), arguments: arguments)
  }

  static func locale(for language: AppLanguage) -> Locale {
    Locale(identifier: resolvedLanguageCode(for: language))
  }

  private static func resolvedLanguageCode(for language: AppLanguage) -> String {
    if let explicit = language.localizationCode {
      return explicit
    }

    let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
    return preferred.hasPrefix("pl") ? "pl" : "en"
  }
}
