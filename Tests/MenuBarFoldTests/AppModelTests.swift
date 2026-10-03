import XCTest

@testable import MenuBarFold

@MainActor
final class AppModelTests: XCTestCase {
  func testDefaultsAreSafeAndEnglishCapable() {
    let suiteName = "MenuBarFoldTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let model = AppModel(defaults: defaults)

    XCTAssertTrue(model.autoCollapseEnabled)
    XCTAssertEqual(model.autoCollapseDelay, 10)
    XCTAssertTrue(model.protectCaptureIndicators)
    XCTAssertTrue(model.alwaysHiddenEnabled)
    XCTAssertFalse(model.isHiddenSectionExpanded)
    XCTAssertFalse(model.isAlwaysHiddenSectionExpanded)
    XCTAssertEqual(model.language, .english)
    XCTAssertEqual(model.shortcutPreset, .optionCommandH)
  }

  func testPreferencesPersist() {
    let suiteName = "MenuBarFoldTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let first = AppModel(defaults: defaults)
    first.language = .polish
    first.autoCollapseDelay = 30
    first.alwaysHiddenEnabled = true

    let second = AppModel(defaults: defaults)
    XCTAssertEqual(second.language, .polish)
    XCTAssertEqual(second.autoCollapseDelay, 30)
    XCTAssertTrue(second.alwaysHiddenEnabled)
  }

  func testExplicitLanguageLoadsLocalizedResources() {
    XCTAssertEqual(L10n.string("action.expand", language: .english), "Expand")
    XCTAssertEqual(L10n.string("action.expand", language: .polish), "Rozwiń")
  }
}
