import XCTest
import SwiftUI
@testable import HeartsScoreboard

/// The "took all 26" tint must stay a muted wash with readable text in every appearance.
final class ThemeContrastTests: XCTestCase {
    private func rgba(_ color: Color, _ traits: UITraitCollection) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var c: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        UIColor(color).resolvedColor(with: traits).getRed(&c.0, green: &c.1, blue: &c.2, alpha: &c.3)
        return (c.0, c.1, c.2, c.3)
    }

    private func luminance(_ c: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        func f(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }

    func testAllPointsTextIsReadableOnItsFillInEveryVariant() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let t = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: style),
                                                        UITraitCollection(accessibilityContrast: contrast)])
                let card = rgba(Theme.cardSurface, t), fill = rgba(Theme.allPointsFill, t), text = rgba(Theme.allPointsText, t)
                let bg = (r: card.r * (1 - fill.a) + fill.r * fill.a, g: card.g * (1 - fill.a) + fill.g * fill.a,
                          b: card.b * (1 - fill.a) + fill.b * fill.a)
                let l1 = luminance((text.r, text.g, text.b)), l2 = luminance(bg)
                let ratio = (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "style \(style.rawValue) contrast \(contrast.rawValue)")
                if style == .dark, contrast == .normal {
                    XCTAssertLessThanOrEqual(fill.a, 0.3, "dark fill must stay a muted wash, not a solid block")
                }
            }
        }
    }
}
