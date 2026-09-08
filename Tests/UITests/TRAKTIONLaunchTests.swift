import XCTest

@MainActor
final class TRAKTIONLaunchTests: XCTestCase {
  func testReadOnlyShellFitsPortraitAndLandscape() {
    let app = XCUIApplication()
    XCUIDevice.shared.orientation = .portrait
    app.launch()
    XCTAssertLessThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
    verifyShell(in: app)

    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
    verifyShell(in: app)
    XCUIDevice.shared.orientation = .portrait
  }

  func testReadOnlyShellRemainsReachableWithLargeText() {
    let app = XCUIApplication()
    XCUIDevice.shared.orientation = .portrait
    app.launch()
    let title = app.staticTexts["workspace.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    let defaultTitleHeight = title.frame.height
    app.terminate()
    app.launchArguments += [
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ]
    XCUIDevice.shared.orientation = .portrait
    app.launch()
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertGreaterThan(title.frame.height, defaultTitleHeight)
    verifyShell(in: app)
  }

  private func verifyShell(in app: XCUIApplication) {
    let scroll = app.scrollViews["workspace.scroll"]
    XCTAssertTrue(scroll.waitForExistence(timeout: 10))
    // Return to the heading after a rotation, which can retain scroll position.
    for _ in 0..<8 where !app.staticTexts["workspace.title"].isHittable {
      scroll.swipeDown()
    }
    let title = app.staticTexts["workspace.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertTrue(title.isHittable)
    XCTAssertEqual(title.label, "TRAKTION")
    assertHorizontallyContained(title, in: app)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Read-only shell"
    screenshot.lifetime = .keepAlways
    add(screenshot)

    let steps = [
      "Import PNG captures", "Confirm supplied order", "Reconstruct locally",
      "Inspect uncertain joints", "Export a new image",
    ]
    for (index, label) in steps.enumerated() {
      let step = app.staticTexts["workspace.step.\(index)"]
      reveal(step, in: scroll)
      XCTAssertEqual(step.label, label)
      assertHorizontallyContained(step, in: app)
    }
    let status = app.staticTexts["workspace.status"]
    reveal(status, in: scroll)
    XCTAssertTrue(status.label.contains("read-only"))
    assertHorizontallyContained(status, in: app)
  }

  private func reveal(_ element: XCUIElement, in scroll: XCUIElement) {
    for _ in 0..<8 where !element.isHittable {
      scroll.swipeUp()
    }
    XCTAssertTrue(element.exists)
    XCTAssertTrue(element.isHittable)
  }

  private func assertHorizontallyContained(_ element: XCUIElement, in app: XCUIApplication) {
    let viewport = app.windows.firstMatch.frame
    XCTAssertGreaterThan(element.frame.width, 0)
    XCTAssertGreaterThanOrEqual(element.frame.minX, viewport.minX - 1)
    XCTAssertLessThanOrEqual(element.frame.maxX, viewport.maxX + 1)
  }
}
