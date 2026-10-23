import XCTest

/// Smoke test: the app launches to the sign-in screen with no stored session.
final class LaunchTests: XCTestCase {
    @MainActor
    func testLaunchShowsSignIn() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Sign In"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Email"].exists)
    }
}
