import XCTest

final class SalahUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingCanBeSkippedAndRootTabsAppear() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-state"]
        app.launch()
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 3) { skip.tap() }
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
        XCTAssertTrue(app.tabBars.buttons["Tracker"].exists)
        XCTAssertTrue(app.tabBars.buttons["Qibla"].exists)
        XCTAssertTrue(app.tabBars.buttons["More"].exists)
        let locationMenu = app.buttons["today.location.menu"]
        XCTAssertTrue(locationMenu.exists)
        locationMenu.tap()
        XCTAssertTrue(app.buttons["Choose District Manually"].waitForExistence(timeout: 2))
    }

    func testManualDistrictSelectionAndLocationDeniedRecovery() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-state", "-location-denied"]
        app.launch()
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Choose Prayer Location"].tap()
        app.buttons["Use Current Location"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Location access is denied'")).firstMatch.waitForExistence(timeout: 3))
        app.buttons["Choose District Manually"].tap()
        let dhaka = app.buttons["Dhaka, ঢাকা"]
        XCTAssertTrue(dhaka.waitForExistence(timeout: 3))
        dhaka.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 3))
    }

    func testTodayShowsLoadingThenLoadedAndCachedOfflineState() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-state", "-onboarding-complete", "-slow-loading"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Loading prayer times…"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Prayer Schedule"].waitForExistence(timeout: 7))

        app.terminate()
        app.launchArguments = ["-ui-testing", "-onboarding-complete", "-offline"]
        app.launch()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Offline'" )).firstMatch.waitForExistence(timeout: 4))
    }

    func testMarkingPrayerCompletedPersistsAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-state", "-reset-tracker", "-onboarding-complete"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Prayer Schedule"].waitForExistence(timeout: 4))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Fajr, starts'")).firstMatch.tap()
        app.tabBars.buttons["Tracker"].tap()
        XCTAssertTrue(app.buttons["Fajr, completed"].waitForExistence(timeout: 3))

        app.terminate()
        app.launchArguments = ["-ui-testing", "-onboarding-complete"]
        app.launch()
        app.tabBars.buttons["Tracker"].tap()
        XCTAssertTrue(app.buttons["Fajr, completed"].waitForExistence(timeout: 3))
    }

    func testTrackerCompletionControlIsAccessible() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-complete"]
        app.launch()
        app.tabBars.buttons["Tracker"].tap()
        XCTAssertTrue(app.segmentedControls["Tracker section"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Today’s Ṣalāh"].waitForExistence(timeout: 3))
        let fajr = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Fajr'")).firstMatch
        XCTAssertTrue(fajr.exists)
        fajr.tap()
    }

    func testTasbihCounterAndConfirmedReset() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-tracker", "-onboarding-complete"]
        app.launch()
        app.tabBars.buttons["Tracker"].tap()
        app.segmentedControls.buttons["Tasbih"].tap()

        let emptyCounter = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tasbih counter. Current count 0'")).firstMatch
        XCTAssertTrue(emptyCounter.waitForExistence(timeout: 3))
        emptyCounter.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tasbih counter. Current count 1'")).firstMatch.waitForExistence(timeout: 2))

        app.buttons["Reset counter"].tap()
        let confirmReset = app.buttons["Confirm reset counter"]
        XCTAssertTrue(confirmReset.waitForExistence(timeout: 2))
        confirmReset.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tasbih counter. Current count 0'")).firstMatch.waitForExistence(timeout: 2))
    }

    func testTasbihGoalCompletionResetsAfterAcknowledgement() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-tracker", "-onboarding-complete"]
        app.launch()
        app.tabBars.buttons["Tracker"].tap()
        app.segmentedControls.buttons["Tasbih"].tap()

        let goalMenu = app.buttons["tasbih.goal.menu"]
        XCTAssertTrue(goalMenu.waitForExistence(timeout: 3))
        goalMenu.tap()
        let goal33 = app.buttons["33"]
        XCTAssertTrue(goal33.waitForExistence(timeout: 2))
        goal33.tap()

        let counter = app.buttons["tasbih.counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 2))
        for _ in 0..<33 {
            counter.tap()
        }

        let completionAlert = app.alerts["Tasbih goal completed"]
        XCTAssertTrue(completionAlert.waitForExistence(timeout: 3))
        XCTAssertTrue(completionAlert.staticTexts["You completed 33 counts."].exists)
        completionAlert.buttons["OK"].tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tasbih counter. Current count 0'")).firstMatch.waitForExistence(timeout: 2))
    }

    func testCalculationAndReminderScreensRemainReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-onboarding-complete"]
        app.launch()
        app.tabBars.buttons["More"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Location & Calculation'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Location & Calculation"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Prayer Reminders'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Reminders"].waitForExistence(timeout: 3))
    }

    func testChangingCalculationMethodAndEnablingReminder() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-state", "-onboarding-complete"]
        app.launch()
        app.tabBars.buttons["More"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Location & Calculation'")).firstMatch.tap()
        let method = app.buttons.matching(NSPredicate(format: "label CONTAINS 'UIS Karachi'")).firstMatch
        XCTAssertTrue(method.waitForExistence(timeout: 3))
        method.tap()
        let isna = app.buttons["ISNA"]
        XCTAssertTrue(isna.waitForExistence(timeout: 3))
        isna.tap()
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Prayer Reminders'")).firstMatch.tap()
        let fajrOff = app.buttons["Fajr reminder, off"]
        XCTAssertTrue(fajrOff.waitForExistence(timeout: 3))
        fajrOff.tap()
        let enable = app.buttons["Enable Reminder"]
        XCTAssertTrue(enable.waitForExistence(timeout: 3))
        enable.tap()
        let fajr = app.switches["Fajr"]
        XCTAssertTrue(fajr.waitForExistence(timeout: 3))
        XCTAssertEqual(fajr.value as? String, "1")
    }

    func testNotificationDeniedRecoveryKeepsRemindersUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-state", "-onboarding-complete", "-notification-denied"]
        app.launch()
        app.tabBars.buttons["More"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Prayer Reminders'")).firstMatch.tap()
        let fajrOff = app.buttons["Fajr reminder, off"]
        XCTAssertTrue(fajrOff.waitForExistence(timeout: 3))
        fajrOff.tap()
        let enable = app.buttons["Enable Reminder"]
        XCTAssertTrue(enable.waitForExistence(timeout: 3))
        enable.tap()
        XCTAssertTrue(app.buttons["Open Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'currently denied'")).firstMatch.exists)
    }
}
