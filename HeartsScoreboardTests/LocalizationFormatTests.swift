import XCTest
@testable import HeartsScoreboard

/// Every translation must keep the English format specifiers (machine translation can mangle them,
/// e.g. Serbian transliterated "%d" into "%д", which printed literally).
final class LocalizationFormatTests: XCTestCase {
    private static let specifier = try! NSRegularExpression(pattern: #"%(?:(\d+)\$)?(lld|ld|d|@|f)"#)

    /// Specifiers as a sorted list of conversion types; positional ("%2$@") counts as "@".
    private func specifiers(_ s: String) -> [String] {
        let range = NSRange(s.startIndex..., in: s)
        return Self.specifier.matches(in: s, range: range)
            .map { String(s[Range($0.range(at: 2), in: s)!]) }
            .sorted()
    }

    private func table(_ locale: String) throws -> [String: String] {
        let bundle = Bundle(for: GameViewModel.self)
        let path = try XCTUnwrap(bundle.path(forResource: "Localizable", ofType: "strings",
                                             inDirectory: nil, forLocalization: locale), locale)
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String], locale)
    }

    func testEveryLocaleKeepsEnglishFormatSpecifiers() throws {
        let english = try table("en")
        let locales = Bundle(for: GameViewModel.self).localizations.filter { $0 != "en" && $0 != "Base" }
        XCTAssertGreaterThan(locales.count, 50)
        var problems: [String] = []
        for locale in locales {
            for (key, value) in try table(locale) {
                guard let source = english[key] else { continue }
                if specifiers(value) != specifiers(source) || value.contains("%д") {
                    problems.append("\(locale): \(key) -> \(value)")
                }
            }
        }
        XCTAssertEqual(problems, [], problems.joined(separator: "\n"))
    }

    /// The quick-add settings label and caption must exist in every locale, with their "%d" intact.
    func testQuickAddSettingsKeysExistInEveryLocale() throws {
        let keys = ["Quick-add button: +%d",
                    "The +%d button in score entry adds this many points per tap."]
        let locales = Bundle(for: GameViewModel.self).localizations.filter { $0 != "Base" }
        for locale in locales {
            let t = try table(locale)
            for key in keys {
                let value = try XCTUnwrap(t[key], "\(locale) is missing \(key)")
                XCTAssertEqual(specifiers(value), ["d"], "\(locale): \(key) -> \(value)")
            }
            XCTAssertNil(t["Adds %d points per tap"], "\(locale) still has the removed key")
        }
    }
}
