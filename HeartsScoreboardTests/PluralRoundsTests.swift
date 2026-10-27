import XCTest
@testable import HeartsScoreboard

/// "%lld rounds" is pluralized by each locale's Localizable.stringsdict (CLDR rules), not by code.
final class PluralRoundsTests: XCTestCase {
    private let key = "%lld rounds"
    private let appBundle = Bundle(for: GameViewModel.self)

    private func localizedBundle(_ locale: String) throws -> Bundle {
        let path = try XCTUnwrap(appBundle.path(forResource: locale, ofType: "lproj"), locale)
        return try XCTUnwrap(Bundle(path: path), locale)
    }

    private func rounds(_ n: Int, _ locale: String) throws -> String {
        let format = try localizedBundle(locale).localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, locale: Locale(identifier: locale), n)
    }

    func testEnglishSingularAndPlural() throws {
        XCTAssertEqual(try rounds(1, "en"), "1 round")
        XCTAssertEqual(try rounds(2, "en"), "2 rounds")
        XCTAssertEqual(try rounds(0, "en"), "0 rounds")
    }

    func testRussianUsesOneFewManyForms() throws {
        XCTAssertEqual(try rounds(1, "ru"), "1 раунд")
        XCTAssertEqual(try rounds(2, "ru"), "2 раунда")
        XCTAssertEqual(try rounds(5, "ru"), "5 раундов")
        XCTAssertEqual(try rounds(21, "ru"), "21 раунд")
        XCTAssertEqual(try rounds(12, "ru"), "12 раундов")
    }

    func testPolishAndArabicAndJapanese() throws {
        XCTAssertEqual(try rounds(1, "pl"), "1 runda")
        XCTAssertEqual(try rounds(3, "pl"), "3 rundy")
        XCTAssertEqual(try rounds(5, "pl"), "5 rund")
        XCTAssertEqual(try rounds(2, "ar"), "جولتان")
        XCTAssertEqual(try rounds(3, "ar"), "3 جولات")
        XCTAssertEqual(try rounds(11, "ar"), "11 جولة")
        XCTAssertEqual(try rounds(1, "ja"), "1ラウンド")
        XCTAssertEqual(try rounds(7, "ja"), "7ラウンド")
    }

    func testCallSitesUsePluralKey() {
        XCTAssertEqual(String(localized: "\(1) rounds"), "1 round")
        XCTAssertEqual(String(localized: "\(4) rounds"), "4 rounds")
    }

    /// Every locale that ships Localizable.strings must also ship a parseable stringsdict whose
    /// "other" form uses the %lld count, and the key must not linger in .strings (it would be dead).
    func testEveryLocaleHasValidPluralEntry() throws {
        let locales = appBundle.localizations.filter { $0 != "Base" }
        XCTAssertGreaterThan(locales.count, 50)
        let categories: Set<String> = ["zero", "one", "two", "few", "many", "other"]
        var problems: [String] = []
        for locale in locales {
            let lproj = try localizedBundle(locale)
            guard let path = lproj.path(forResource: "Localizable", ofType: "stringsdict"),
                  let root = NSDictionary(contentsOfFile: path),
                  let entry = root[key] as? [String: Any],
                  entry["NSStringLocalizedFormatKey"] as? String == "%#@count@",
                  let count = entry["count"] as? [String: Any] else {
                problems.append("\(locale): missing or unparseable stringsdict entry")
                continue
            }
            if count["NSStringFormatSpecTypeKey"] as? String != "NSStringPluralRuleType"
                || count["NSStringFormatValueTypeKey"] as? String != "lld" {
                problems.append("\(locale): wrong plural spec/value type")
            }
            guard let other = count["other"] as? String, other.contains("%lld") else {
                problems.append("\(locale): 'other' form missing or lacks %lld")
                continue
            }
            for (name, value) in count where categories.contains(name) {
                guard let text = value as? String else { problems.append("\(locale): \(name) not a string"); continue }
                if text.components(separatedBy: "%lld").count > 2 {
                    problems.append("\(locale): \(name) repeats %lld")
                }
            }
            if let strings = lproj.path(forResource: "Localizable", ofType: "strings"),
               let table = NSDictionary(contentsOfFile: strings), table[key] != nil {
                problems.append("\(locale): \(key) still in Localizable.strings")
            }
        }
        XCTAssertEqual(problems, [], problems.joined(separator: "\n"))
    }
}
