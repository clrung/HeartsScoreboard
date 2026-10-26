import XCTest
import SwiftUI
@testable import HeartsScoreboard

final class ChipMetricsTests: XCTestCase {
    /// Regression: the "+remaining" chip rendered as "+…" because the min width (44pt) left only 20pt
    /// of text room after padding, less than "+26" needs.
    func testMinWidthFitsWidestChipText() {
        for size in [15.0, 17.0, 20.0, 28.0] {
            let font = UIFont.systemFont(ofSize: size, weight: .semibold)
            let text = ("+26" as NSString).size(withAttributes: [.font: font]).width
            XCTAssertGreaterThanOrEqual(
                ChipMetrics.minWidth(fontSize: size) - 2 * ChipMetrics.horizontalPadding, text,
                "chip too narrow for \"+26\" at \(size)pt")
        }
        // The old width (the 44pt tap size) was too narrow at the default size.
        XCTAssertGreaterThan(ChipMetrics.baseMinWidth, 44)
    }

    func testWidestTextIsAtLeastAsWideAsOtherChipTexts() {
        let font = UIFont.systemFont(ofSize: ChipMetrics.baseFontSize, weight: .semibold)
        let widest = ("+26" as NSString).size(withAttributes: [.font: font]).width
        for t in ["+0", "+5", "+10", "+21", "Q♠"] {
            XCTAssertLessThanOrEqual((t as NSString).size(withAttributes: [.font: font]).width, widest, t)
        }
    }
}
