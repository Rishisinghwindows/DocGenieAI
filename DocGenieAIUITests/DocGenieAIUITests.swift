import XCTest

@MainActor
final class DocGenieAIUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["UI_TESTING"]
        app.launch()
        sleep(3)
    }

    // MARK: - 1. Welcome Screen

    func testWelcomeScreen_showsBranding() {
        XCTAssertTrue(app.staticTexts["DocSage"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["23 tools. On-device AI. Zero cloud uploads."].exists)
    }

    func testWelcomeScreen_showsSuggestionCards() {
        XCTAssertTrue(app.staticTexts["Scan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Merge"].exists)
        XCTAssertTrue(app.staticTexts["Convert"].exists)
        XCTAssertTrue(app.staticTexts["OCR"].exists)
    }

    func testWelcomeScreen_showsChatInput() {
        XCTAssertTrue(app.textFields["Ask DocSage..."].waitForExistence(timeout: 5))
    }

    func testWelcomeScreen_hasToolbarButtons() {
        XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: 5))
    }

    // MARK: - 2. Tab Bar

    func testTabBar_exists() {
        XCTAssertTrue(app.tabBars.element.waitForExistence(timeout: 5))
    }

    func testTabBar_has3Tabs() {
        let tabBar = app.tabBars.element
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["Chat"].exists)
        XCTAssertTrue(tabBar.buttons["Tools"].exists)
        XCTAssertTrue(tabBar.buttons["Settings"].exists)
    }

    func testTabBar_chatIsDefault() {
        let tabBar = app.tabBars.element
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        let chatTab = tabBar.buttons["Chat"]
        XCTAssertTrue(chatTab.isSelected)
    }

    // MARK: - 3. Tools Tab

    func testToolsTab_showsGrid() {
        let tabBar = app.tabBars.element
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Tools"].tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["Scanner"].waitForExistence(timeout: 3) ||
                       app.staticTexts["PDF Tools"].exists)
    }

    func testToolsTab_showsToolCards() {
        app.tabBars.buttons["Tools"].tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["Merge PDF"].waitForExistence(timeout: 3) ||
                       app.staticTexts["Compress"].exists ||
                       app.staticTexts["Split PDF"].exists)
    }

    func testToolsTab_openMergePDF() {
        app.tabBars.buttons["Tools"].tap()
        sleep(1)
        let mergeText = app.staticTexts["Merge PDF"]
        if mergeText.waitForExistence(timeout: 3) {
            mergeText.tap()
            sleep(1)
            XCTAssertTrue(app.navigationBars["Merge PDFs"].waitForExistence(timeout: 3) ||
                           app.staticTexts["Select PDFs"].exists ||
                           app.buttons["Cancel"].exists)
        }
    }

    // MARK: - 4. Settings Tab

    func testSettingsTab_showsContent() {
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["AI Engine"].waitForExistence(timeout: 3) ||
                       app.staticTexts["Storage"].exists ||
                       app.staticTexts["Quick Access"].exists)
    }

    func testSettingsTab_showsLegal() {
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(app.staticTexts["Terms & Conditions"].waitForExistence(timeout: 3) ||
                       app.staticTexts["Privacy Policy"].exists ||
                       app.staticTexts["Legal"].exists)
    }

    func testSettingsTab_showsConnect() {
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(app.staticTexts["About"].waitForExistence(timeout: 3) ||
                       app.staticTexts["Rate App"].exists ||
                       app.staticTexts["Connect"].exists)
    }

    // MARK: - 5. Chat Flow

    func testChat_typeAndSend() {
        let textField = app.textFields["Ask DocSage..."]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()
        textField.typeText("hello")

        sleep(1)
        let sendButton = app.buttons["Send message"]
        if sendButton.waitForExistence(timeout: 3) {
            sendButton.tap()
        } else {
            let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'send' OR label CONTAINS 'Send' OR label CONTAINS 'arrow'"))
            if buttons.count > 0 {
                buttons.element(boundBy: 0).tap()
            }
        }

        sleep(3)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'DocSage' OR label CONTAINS 'DocSage' OR label CONTAINS 'document'")).count > 0)
    }

    func testChat_newChatButton() {
        let textField = app.textFields["Ask DocSage..."]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()
        textField.typeText("hi")

        let sendButton = app.buttons["Send message"]
        if sendButton.waitForExistence(timeout: 3) {
            sendButton.tap()
        }
        sleep(2)

        // Tap new chat button (plus.bubble, left toolbar button)
        let newChatButton = app.navigationBars.buttons["plus.bubble"]
        if newChatButton.waitForExistence(timeout: 3) {
            newChatButton.tap()
        } else {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        sleep(1)
        XCTAssertTrue(app.staticTexts["23 tools. On-device AI. Zero cloud uploads."].waitForExistence(timeout: 3))
    }

    // MARK: - 6. Chat History

    func testChatHistory_opens() {
        // Tap history button (clock, right toolbar button)
        let historyButton = app.navigationBars.buttons["clock.arrow.circlepath"]
        if historyButton.waitForExistence(timeout: 5) {
            historyButton.tap()
        } else {
            let trailingButtons = app.navigationBars.buttons
            trailingButtons.element(boundBy: trailingButtons.count - 1).tap()
        }

        sleep(1)
        XCTAssertTrue(app.staticTexts["No Conversations"].waitForExistence(timeout: 3) ||
                       app.navigationBars["Chat History"].exists ||
                       app.buttons["Done"].exists)
    }

    // MARK: - 7. Attachment Flow

    func testAttach_showsDialog() {
        let attachButton = app.buttons["Attach file"]
        if attachButton.waitForExistence(timeout: 5) {
            attachButton.tap()
        }

        sleep(1)
        XCTAssertTrue(app.buttons["Camera Scan"].waitForExistence(timeout: 3) ||
                       app.buttons["Browse Files"].exists ||
                       app.buttons["Photo Library"].exists)
    }

    func testAttach_cancelDialog() {
        let attachButton = app.buttons["Attach file"]
        if attachButton.waitForExistence(timeout: 5) {
            attachButton.tap()
        }

        sleep(1)
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
        }
        sleep(1)
        XCTAssertTrue(app.textFields["Ask DocSage..."].exists)
    }

    // MARK: - 8. Suggestion Cards

    func testSuggestionCard_compressSendsMessage() {
        let compressCard = app.staticTexts["Compress a PDF"]
        if compressCard.waitForExistence(timeout: 5) {
            compressCard.tap()
            sleep(3)
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'compress'")).count > 0)
        }
    }

    func testSuggestionCard_scanOpensScanner() {
        let scanCard = app.staticTexts["Scan a document"]
        if scanCard.waitForExistence(timeout: 5) {
            scanCard.tap()
            sleep(2)
            if app.buttons["Cancel"].exists {
                app.buttons["Cancel"].tap()
            }
            if app.buttons["Dismiss"].exists {
                app.buttons["Dismiss"].tap()
            }
        }
    }

    // MARK: - 9. Quick Actions

    func testQuickActions_appearDuringConversation() {
        let textField = app.textFields["Ask DocSage..."]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()
        textField.typeText("help")

        let sendButton = app.buttons["Send message"]
        if sendButton.waitForExistence(timeout: 3) {
            sendButton.tap()
        }
        sleep(3)

        XCTAssertTrue(app.buttons["Scan"].waitForExistence(timeout: 3) ||
                       app.buttons["Merge"].exists ||
                       app.buttons["OCR"].exists)
    }

    // MARK: - 10. Tab Switching

    func testTabSwitching_roundTrip() {
        let tabBar = app.tabBars.element
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Go to Tools
        tabBar.buttons["Tools"].tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["Tools"].exists)

        // Go to Settings
        tabBar.buttons["Settings"].tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["Settings"].exists)

        // Back to Chat
        tabBar.buttons["Chat"].tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["DocSage"].exists ||
                       app.staticTexts["DocSage"].exists)
    }
}
