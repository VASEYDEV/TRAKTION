import XCTest

@MainActor
final class TRAKTIONLaunchTests: XCTestCase {
  func testImportedCapturesRequireConfirmedOrderAndReconstructInBothOrientations() {
    let app = launch(scenario: "baseline")
    let scroll = app.scrollViews["workspace.scroll"]
    let reconstruct = app.buttons["workspace.reconstruct"]
    reveal(reconstruct, in: scroll)
    XCTAssertFalse(reconstruct.isEnabled)
    confirmOrder(in: app)
    XCTAssertTrue(reconstruct.isEnabled)

    // Reordering must move stable captures and invalidate the prior confirmation.
    let moveUp = app.buttons["capture.1.moveUp"]
    reveal(moveUp, in: scroll)
    moveUp.tap()
    XCTAssertEqual(app.staticTexts["capture.0.name"].label, "1. capture-002.png")
    XCTAssertEqual(app.staticTexts["capture.1.name"].label, "2. capture-001.png")
    XCTAssertFalse(reconstruct.isEnabled)
    let moveDown = app.buttons["capture.0.moveDown"]
    reveal(moveDown, in: scroll)
    moveDown.tap()
    XCTAssertEqual(app.staticTexts["capture.0.name"].label, "1. capture-001.png")
    XCTAssertEqual(app.staticTexts["capture.1.name"].label, "2. capture-002.png")
    confirmOrder(in: app)
    reconstruct.tap()
    verifyResult(in: app, dimensions: "96 × 384 pixels", joints: 2)
    attachScreenshot(app, name: "Reconstruction portrait")

    XCUIDevice.shared.orientation = .landscapeLeft
    waitForOrientation(in: app, landscape: true)
    verifyResult(in: app, dimensions: "96 × 384 pixels", joints: 2)
    attachScreenshot(app, name: "Reconstruction landscape")
    reset(in: app)
  }

  func testLargeTextKeepsCaptureControlsAndReconstructionReachable() {
    let app = XCUIApplication()
    XCUIDevice.shared.orientation = .portrait
    app.launch()
    let title = app.staticTexts["workspace.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    let defaultTitleHeight = title.frame.height
    app.terminate()
    app.launchEnvironment["TRAKTION_UI_FIXTURE"] = "baseline"
    app.launchArguments += [
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ]
    app.launch()
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertGreaterThan(title.frame.height, defaultTitleHeight)
    waitForImport(in: app, count: 3)
    let scroll = app.scrollViews["workspace.scroll"]
    for element in [
      app.buttons["workspace.import"], app.staticTexts["capture.0.name"],
      app.staticTexts["capture.0.dimensions"], app.buttons["capture.0.moveDown"],
      app.buttons["capture.1.moveUp"], app.buttons["capture.2.remove"],
    ] {
      reveal(element, in: scroll)
      assertHorizontallyContained(element, in: app)
    }
    app.buttons["capture.2.remove"].tap()
    XCTAssertFalse(app.staticTexts["capture.2.name"].exists)
    XCTAssertFalse(app.buttons["workspace.reconstruct"].isEnabled)
    confirmOrder(in: app)
    let reconstruct = app.buttons["workspace.reconstruct"]
    reveal(reconstruct, in: scroll)
    assertHorizontallyContained(reconstruct, in: app)
    reconstruct.tap()
    verifyResult(in: app, dimensions: "96 × 272 pixels", joints: 1)
    attachScreenshot(app, name: "Large text reconstruction")
    reset(in: app)
  }

  func testDuplicateCapturesKeepVisibleSourcesAndShowFailure() {
    let app = launch(scenario: "duplicate-capture", count: 4)
    confirmOrder(in: app)
    app.buttons["workspace.reconstruct"].tap()
    verifyFailure(
      in: app, containing: "same image", sourceNames: ["capture-001.png", "capture-004.png"])
    XCTAssertTrue(app.staticTexts["capture.3.name"].exists)
    attachScreenshot(app, name: "Duplicate capture refusal")
    reset(in: app)
  }

  func testMissingCoverageShowsFailureWithoutComposite() {
    let app = launch(scenario: "missing-middle", count: 2)
    confirmOrder(in: app)
    app.buttons["workspace.reconstruct"].tap()
    verifyFailure(
      in: app, containing: "overlap", sourceNames: ["capture-001.png", "capture-002.png"])
    attachScreenshot(app, name: "Missing coverage refusal")
    reset(in: app)
  }

  func testFilesPickerPresentationAndCancellationPreserveWorkspace() {
    let app = launch(scenario: "baseline")
    confirmOrder(in: app)
    let scroll = app.scrollViews["workspace.scroll"]
    let importButton = app.buttons["workspace.import"]
    reveal(importButton, in: scroll)
    importButton.tap()

    // This is the actual system Files picker. Synthetic-service tests above do
    // not claim to automate selecting documents from a third-party provider.
    let pickerCancel = app.buttons["Cancel"].firstMatch
    XCTAssertTrue(pickerCancel.waitForExistence(timeout: 15))
    XCTAssertTrue(pickerCancel.isHittable)
    attachScreenshot(app, name: "Files picker presented")
    pickerCancel.tap()
    let dismissed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: pickerCancel
    )
    XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
    XCTAssertTrue(importButton.waitForExistence(timeout: 10))
    XCTAssertTrue(importButton.isHittable)
    XCTAssertEqual(app.staticTexts["capture.0.name"].label, "1. capture-001.png")
    XCTAssertEqual(app.staticTexts["capture.1.name"].label, "2. capture-002.png")
    XCTAssertEqual(app.staticTexts["capture.2.name"].label, "3. capture-003.png")
    XCTAssertEqual(app.buttons["workspace.order.confirm"].label, "Order confirmed")
    XCTAssertTrue(app.buttons["workspace.reconstruct"].isEnabled)
    XCTAssertFalse(app.staticTexts["workspace.failure"].exists)
  }

  private func launch(scenario: String, count: Int = 3) -> XCUIApplication {
    let app = XCUIApplication()
    XCUIDevice.shared.orientation = .portrait
    app.launchEnvironment["TRAKTION_UI_FIXTURE"] = scenario
    app.launch()
    waitForOrientation(in: app, landscape: false)
    waitForImport(in: app, count: count)
    return app
  }

  private func waitForImport(in app: XCUIApplication, count: Int) {
    XCTAssertTrue(app.staticTexts["capture.\(count - 1).name"].waitForExistence(timeout: 20))
    XCTAssertFalse(app.staticTexts["workspace.failure"].exists)
    XCTAssertFalse(app.buttons["workspace.cancel"].exists)
  }

  private func confirmOrder(in app: XCUIApplication) {
    let scroll = app.scrollViews["workspace.scroll"]
    let confirm = app.buttons["workspace.order.confirm"]
    reveal(confirm, in: scroll)
    assertHorizontallyContained(confirm, in: app)
    XCTAssertTrue(confirm.isEnabled)
    confirm.tap()
    let reconstruct = app.buttons["workspace.reconstruct"]
    reveal(reconstruct, in: scroll)
    XCTAssertTrue(reconstruct.isEnabled)
  }

  private func verifyResult(in app: XCUIApplication, dimensions: String, joints: Int) {
    let scroll = app.scrollViews["workspace.scroll"]
    let size = app.staticTexts["workspace.result.dimensions"]
    XCTAssertTrue(size.waitForExistence(timeout: 30))
    reveal(size, in: scroll)
    XCTAssertEqual(size.label, dimensions)
    assertHorizontallyContained(size, in: app)
    let preview = app.images["workspace.result.preview"]
    reveal(preview, in: scroll)
    assertHorizontallyContained(preview, in: app)
    for index in 0..<joints {
      let joint = app.staticTexts["workspace.result.joint.\(index)"]
      reveal(joint, in: scroll)
      XCTAssertEqual(joint.label, "Joint \(index + 1): Exact")
      assertHorizontallyContained(joint, in: app)
    }
    XCTAssertFalse(app.staticTexts["workspace.failure"].exists)
  }

  private func verifyFailure(
    in app: XCUIApplication, containing word: String, sourceNames: [String]
  ) {
    let failure = app.staticTexts["workspace.failure"]
    XCTAssertTrue(failure.waitForExistence(timeout: 30))
    reveal(failure, in: app.scrollViews["workspace.scroll"])
    XCTAssertTrue(failure.label.lowercased().contains(word))
    for name in sourceNames { XCTAssertTrue(failure.label.contains(name)) }
    assertHorizontallyContained(failure, in: app)
    XCTAssertFalse(app.images["workspace.result.preview"].exists)
    XCTAssertFalse(app.staticTexts["workspace.result.dimensions"].exists)
  }

  private func reset(in app: XCUIApplication) {
    let reset = app.buttons["workspace.reset"]
    reveal(reset, in: app.scrollViews["workspace.scroll"])
    assertHorizontallyContained(reset, in: app)
    reset.tap()
    XCTAssertFalse(app.staticTexts["capture.0.name"].exists)
    XCTAssertFalse(app.staticTexts["workspace.result.dimensions"].exists)
    XCTAssertFalse(app.staticTexts["workspace.failure"].exists)
    XCTAssertTrue(app.buttons["workspace.import"].isEnabled)
    XCTAssertEqual(app.buttons["workspace.import"].label, "Import PNG captures")
  }

  private func waitForOrientation(in app: XCUIApplication, landscape: Bool) {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        let frame = app.windows.firstMatch.frame
        return landscape ? frame.width > frame.height : frame.height > frame.width
      }, object: nil
    )
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
  }

  private func reveal(_ element: XCUIElement, in scroll: XCUIElement) {
    // A previous action or rotation can retain a position below this element.
    for _ in 0..<20 where !element.isHittable {
      if element.exists && element.frame.maxY <= scroll.frame.minY {
        scroll.swipeDown()
      } else {
        scroll.swipeUp()
      }
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

  private func attachScreenshot(_ app: XCUIApplication, name: String) {
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = name
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}
