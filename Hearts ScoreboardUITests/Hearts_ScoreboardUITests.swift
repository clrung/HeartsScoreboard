//
//  Hearts_ScoreboardUITests.swift
//  Hearts ScoreboardUITests
//
//  Created by Christopher Rung on 4/4/16.
//  Copyright © 2016 Christopher Rung. All rights reserved.
//

import XCTest

class Hearts_ScoreboardUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    func testExample() {
        let app = XCUIApplication()
        app.buttons["Settings Button"].tap()
        
        let elementsQuery = app.scrollViews.otherElements
        let player1TextField = elementsQuery.textFields["Player 1"]
        player1TextField.tap()
        
        elementsQuery.buttons["Clear text"].tap()
        elementsQuery.textFields["Player 1"].typeText("Christopher");

        let forwardButton = app.toolbars.buttons["Forward"]
        forwardButton.tap()
        
        elementsQuery.buttons["Clear text"].tap()
        elementsQuery.textFields["Player 2"].typeText("Mary");
        forwardButton.tap()
        elementsQuery.buttons["Clear text"].tap()
        elementsQuery.textFields["Player 3"].typeText("George");
        forwardButton.tap()
        elementsQuery.buttons["Clear text"].tap()
        elementsQuery.textFields["Player 4"].typeText("Cathy");

        app.toolbars.buttons["Done"].tap()
        
        snapshot("2Settings")
        
        let settingsButtonButton = app.buttons["Settings Button"]
        settingsButtonButton.tap()
        app.buttons["Start Game"].tap()
        
        let element = app.otherElements.containingType(.Button, identifier:"Settings Button").childrenMatchingType(.Other).elementBoundByIndex(3)
        let qButton = element.childrenMatchingType(.Button).matchingIdentifier("Q♠︎").elementBoundByIndex(0)
        qButton.tap()
        
        let button = element.childrenMatchingType(.Button).matchingIdentifier("+5").elementBoundByIndex(1)
        button.tap()
        button.tap()
        element.childrenMatchingType(.Button).matchingIdentifier("+     ").elementBoundByIndex(2).tap()
        
        let button2 = element.childrenMatchingType(.Button).matchingIdentifier("+2").elementBoundByIndex(3)
        button2.tap()
        
        let submitButton = app.buttons["Submit"]
        submitButton.tap()
        
        let nextRoundButton = app.buttons["Next Round"]
        nextRoundButton.tap()
        
        let button3 = element.childrenMatchingType(.Button).matchingIdentifier("+5").elementBoundByIndex(0)
        button3.tap()
        
        let button4 = element.childrenMatchingType(.Button).matchingIdentifier("+     ").elementBoundByIndex(0)
        button4.tap()
        button4.tap()
        element.childrenMatchingType(.Button).matchingIdentifier("Q♠︎").elementBoundByIndex(2).tap()
        
        snapshot("3Scores")
        
        element.childrenMatchingType(.Button).matchingIdentifier("+6").elementBoundByIndex(3).tap()
        submitButton.tap()
        nextRoundButton.tap()
        button3.tap()
        button4.tap()
        element.childrenMatchingType(.Button).matchingIdentifier("Q♠︎").elementBoundByIndex(1).tap()
        
        let button5 = element.childrenMatchingType(.Button).matchingIdentifier("+5").elementBoundByIndex(2)
        button5.tap()
        button2.tap()
        submitButton.tap()
        nextRoundButton.tap()
        element.childrenMatchingType(.Button).matchingIdentifier("Moon").elementBoundByIndex(2).tap()
        submitButton.tap()
        nextRoundButton.tap()
        qButton.tap()
        button.tap()
        button5.tap()
        element.childrenMatchingType(.Button).matchingIdentifier("+3").elementBoundByIndex(3).tap()
        submitButton.tap()
        
        snapshot("1MainScreen")
        
        settingsButtonButton.tap()
        app.buttons["Light"].tap()
        settingsButtonButton.tap()
        snapshot("4Light");
        
        
        settingsButtonButton.tap()
        app.buttons["Dark"].tap()
        settingsButtonButton.tap()
        snapshot("5Dark");
        
    }
    
}
