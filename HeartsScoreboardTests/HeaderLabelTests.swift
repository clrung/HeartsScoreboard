import XCTest
@testable import HeartsScoreboard

final class HeaderLabelTests: XCTestCase {
    private func labels(_ names: String...) -> [String] { HeartsGame.headerLabels(for: names) }

    func testSingleWord() { XCTAssertEqual(labels("Alexandra", "Bob"), ["A", "B"]) }
    func testTwoWords() { XCTAssertEqual(labels("Mary Ann", "Bob"), ["MA", "B"]) }
    func testThreeWordsUseFirstTwo() { XCTAssertEqual(labels("mary ann lee", "Bob"), ["MA", "B"]) }
    func testExtraWhitespace() { XCTAssertEqual(labels("  Mary   Ann ", "Bob"), ["MA", "B"]) }

    func testEmojiAndComposedCharacters() {
        XCTAssertEqual(labels("🐻 Bear", "👨‍👩‍👧 Family", "Émile"), ["🐻B", "👨‍👩‍👧F", "É"])
    }

    func testEmptyFallsBackToOriginalName() {
        XCTAssertEqual(labels("", "   ", "Bob"), ["", "   ", "B"])
    }

    func testCollisionsUseFirstTwoCharacters() {
        XCTAssertEqual(labels("Alexandra", "Andrew", "Bob"), ["Al", "An", "B"])
    }

    func testCollisionOnlyAffectsCollidingPlayers() {
        XCTAssertEqual(labels("Mary Ann", "Bob", "Alexandra", "Andrew"), ["MA", "B", "Al", "An"])
    }

    func testStillCollidingFallsBackToFullName() {
        // Alice/Alex collide on "A" and again on "Al"; Alan Smith's "AS" is unique.
        XCTAssertEqual(labels("Alice", "Alan Smith", "Alex", "Bob"), ["Alice", "AS", "Alex", "B"])
    }
}
