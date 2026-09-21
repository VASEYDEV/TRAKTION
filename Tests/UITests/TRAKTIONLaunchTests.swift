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

  func testLongPixelInspectionPanZoomJointSourcesAndReturn() {
    let app = launch(scenario: "inspection-long")
    confirmOrder(in: app)
    app.buttons["workspace.reconstruct"].tap()
    guard app.staticTexts["workspace.result.dimensions"].waitForExistence(timeout: 30) else {
      attachScreenshot(app, name: "Long reconstruction not ready")
      XCTFail("Phone-size reconstruction did not complete: \(app.staticTexts["workspace.status"].label)")
      return
    }
    openInspection(in: app)
    let scroll = app.scrollViews["inspection.scroll"]
    XCTAssertEqual(app.staticTexts["inspection.dimensions"].label,
      String.localizedStringWithFormat("%lld × %lld pixels", 1170, 6196))
    let one = app.buttons["inspection.oneToOne"]
    reveal(one, in: scroll)
    one.tap()
    XCTAssertEqual(app.staticTexts["inspection.zoom"].label, "Zoom: 100.00% (1:1)")
    let canvas = app.images["inspection.canvas"]
    reveal(canvas, in: scroll)
    let beforeDrag = app.staticTexts["inspection.coordinates"].label
    canvas.swipeUp()
    XCTAssertNotEqual(app.staticTexts["inspection.coordinates"].label, beforeDrag)
    let down = app.buttons["inspection.pan.down"]
    reveal(down, in: scroll)
    let before = app.staticTexts["inspection.coordinates"].label
    down.tap()
    XCTAssertNotEqual(app.staticTexts["inspection.coordinates"].label, before)
    let right = app.buttons["inspection.pan.right"]
    let beforeRight = app.staticTexts["inspection.coordinates"].label
    right.tap()
    XCTAssertNotEqual(app.staticTexts["inspection.coordinates"].label, beforeRight)
    app.buttons["inspection.bottom"].tap()
    reveal(app.images["inspection.canvas"], in: scroll)
    attachScreenshot(app, name: "Pixel inspection 1 to 1 bottom")

    let region = app.buttons["inspection.region"]
    reveal(region, in: scroll)
    region.tap()
    app.buttons["inspection.region.joint.1"].tap()
    XCTAssertEqual(app.staticTexts["inspection.joint.names"].label,
      "First: capture-002.png\nSecond: capture-003.png")
    XCTAssertEqual(app.staticTexts["inspection.joint.positions"].label, "Capture 2 → capture 3")
    XCTAssertEqual(app.staticTexts["inspection.joint.confidence"].label,
      "Confidence: Exact. Overlap: 700 rows.")
    XCTAssertTrue(app.staticTexts["inspection.joint.seam"].label.contains(String.localizedStringWithFormat("output row %lld", 4014)))
    let source = app.buttons["inspection.source.choose"]
    reveal(source, in: scroll)
    source.tap()
    app.buttons["inspection.source.preceding"].tap()
    XCTAssertEqual(app.staticTexts["inspection.source"].label, "Pixels: capture-002.png")
    source.tap()
    app.buttons["inspection.source.following"].tap()
    XCTAssertEqual(app.staticTexts["inspection.source"].label, "Pixels: capture-003.png")
    reveal(app.images["inspection.canvas"], in: scroll)
    attachScreenshot(app, name: "Joint second original portrait")
    XCUIDevice.shared.orientation = .landscapeLeft
    waitForOrientation(in: app, landscape: true)
    reveal(one, in: scroll)
    one.tap()
    XCTAssertEqual(app.staticTexts["inspection.zoom"].label, "Zoom: 100.00% (1:1)")
    reveal(app.images["inspection.canvas"], in: scroll)
    assertHorizontallyContained(app.images["inspection.canvas"], in: app)
    attachScreenshot(app, name: "Joint second original landscape")
    app.buttons["inspection.done"].tap()
    XCTAssertFalse(app.staticTexts["inspection.dimensions"].exists)
    openInspection(in: app)
    XCTAssertFalse(app.staticTexts["inspection.joint.names"].exists)
    XCTAssertEqual(app.staticTexts["inspection.source"].label, "Pixels: Result")
    app.buttons["inspection.done"].tap()
    reset(in: app)
    XCTAssertFalse(app.buttons["workspace.result.inspect"].exists)
  }

  func testSeamAdjustmentCancelApplyUndoRedoAndReopen() {
    let app = launch(scenario: "baseline")
    confirmOrder(in: app)
    app.buttons["workspace.reconstruct"].tap()
    XCTAssertTrue(app.staticTexts["workspace.result.dimensions"].waitForExistence(timeout: 30))
    openInspection(in: app)
    let scroll = app.scrollViews["inspection.scroll"]
    let region = app.buttons["inspection.region"]
    reveal(region, in: scroll); region.tap()
    app.buttons["inspection.region.joint.0"].tap()
    let seam = app.staticTexts["inspection.joint.seam"]
    let automatic = app.staticTexts["inspection.joint.automaticSeam"].label
    let initial = seam.label
    XCTAssertTrue(initial.contains("output row 136; overlap row 24"))
    let confidence = app.staticTexts["inspection.joint.confidence"].label
    func tap(_ id: String) {
      let button = app.buttons[id]
      reveal(button, in: scroll)
      let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: button)
      XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
      button.tap()
    }
    tap("inspection.edit.begin")
    tap("inspection.edit.down")
    XCTAssertTrue(seam.label.contains("output row 137; overlap row 25"))
    XCTAssertEqual(app.staticTexts["inspection.joint.automaticSeam"].label, automatic)
    tap("inspection.edit.cancel")
    XCTAssertEqual(seam.label, initial)
    XCTAssertFalse(app.buttons["inspection.edit.undo"].isEnabled)
    tap("inspection.edit.begin")
    tap("inspection.edit.down")
    let changed = seam.label
    tap("inspection.edit.apply")
    let state = app.staticTexts["inspection.edit.state"]
    let applied = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Modified seams'"), object: state)
    XCTAssertEqual(XCTWaiter.wait(for: [applied], timeout: 10), .completed)
    XCTAssertEqual(seam.label, changed)
    XCTAssertEqual(app.staticTexts["inspection.joint.confidence"].label, confidence)
    tap("inspection.edit.undo")
    let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", initial), object: seam)
    XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
    tap("inspection.edit.redo")
    let redone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", changed), object: seam)
    XCTAssertEqual(XCTWaiter.wait(for: [redone], timeout: 10), .completed)
    reveal(state, in: scroll)
    attachScreenshot(app, name: "Applied seam with reversible history")
    app.buttons["inspection.done"].tap()
    XCTAssertTrue(app.staticTexts["workspace.result.editState"].label.contains("Modified seams"))
    openInspection(in: app)
    XCTAssertTrue(app.buttons["inspection.edit.undo"].isEnabled)
    reveal(region, in: scroll); region.tap()
    app.buttons["inspection.region.joint.0"].tap()
    XCTAssertEqual(seam.label, changed)
    app.buttons["inspection.done"].tap()
    reset(in: app)
    XCTAssertFalse(app.buttons["workspace.result.inspect"].exists)
  }

  func testDraftSeamOriginalSourcesAndOrientation() {
    let app = launch(scenario: "baseline")
    confirmOrder(in: app)
    app.buttons["workspace.reconstruct"].tap()
    XCTAssertTrue(app.staticTexts["workspace.result.dimensions"].waitForExistence(timeout: 30))
    openInspection(in: app)
    let scroll = app.scrollViews["inspection.scroll"]
    app.buttons["inspection.region"].tap()
    app.buttons["inspection.region.joint.0"].tap()
    let begin = app.buttons["inspection.edit.begin"]
    reveal(begin, in: scroll); begin.tap()
    let down = app.buttons["inspection.edit.down"]
    reveal(down, in: scroll); down.tap()
    let source = app.buttons["inspection.source.choose"]
    reveal(source, in: scroll); source.tap()
    app.buttons["inspection.source.preceding"].tap()
    XCTAssertEqual(app.staticTexts["inspection.source"].label, "Pixels: capture-001.png")
    source.tap(); app.buttons["inspection.source.following"].tap()
    XCTAssertEqual(app.staticTexts["inspection.source"].label, "Pixels: capture-002.png")
    source.tap(); app.buttons["inspection.source.result"].tap()
    XCTAssertEqual(app.staticTexts["inspection.source"].label, "Pixels: Draft result")
    XCUIDevice.shared.orientation = .landscapeLeft
    waitForOrientation(in: app, landscape: true)
    let draft = app.staticTexts["inspection.edit.draft"]
    reveal(draft, in: scroll)
    XCTAssertEqual(draft.label, "Draft seam: overlap row 25")
    assertHorizontallyContained(draft, in: app)
    attachScreenshot(app, name: "Seam draft in landscape")
    let cancel = app.buttons["inspection.edit.cancel"]
    reveal(cancel, in: scroll); cancel.tap()
    XCTAssertTrue(app.staticTexts["inspection.joint.seam"].label.contains("output row 136; overlap row 24"))
    app.buttons["inspection.done"].tap()
  }

  func testLargeTextInspectionControlsRemainReachable() {
    let app = XCUIApplication()
    XCUIDevice.shared.orientation = .portrait
    app.launchEnvironment["TRAKTION_UI_FIXTURE"] = "baseline"
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    app.launch()
    waitForImport(in: app, count: 3)
    confirmOrder(in: app)
    app.buttons["workspace.reconstruct"].tap()
    XCTAssertTrue(app.staticTexts["workspace.result.dimensions"].waitForExistence(timeout: 30))
    openInspection(in: app)
    let scroll = app.scrollViews["inspection.scroll"]
    for id in ["inspection.oneToOne", "inspection.fit", "inspection.zoomIn", "inspection.pan.down", "inspection.bottom"] {
      let button = app.buttons[id]
      reveal(button, in: scroll)
      assertHorizontallyContained(button, in: app)
      XCTAssertTrue(button.isEnabled)
      button.tap()
    }
    app.buttons["inspection.done"].tap()
  }

  // Keep viewport and editing accessibility flows independently below the
  // existing per-case time budget; every original assertion remains exercised.
  func testLargeTextSeamControlsRemainReachable() {
    let app = XCUIApplication()
    XCUIDevice.shared.orientation = .portrait
    app.launchEnvironment["TRAKTION_UI_FIXTURE"] = "baseline"
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    app.launch()
    waitForImport(in: app, count: 3)
    confirmOrder(in: app)
    app.buttons["workspace.reconstruct"].tap()
    XCTAssertTrue(app.staticTexts["workspace.result.dimensions"].waitForExistence(timeout: 30))
    openInspection(in: app)
    let scroll = app.scrollViews["inspection.scroll"]
    let region = app.buttons["inspection.region"]
    reveal(region, in: scroll)
    region.tap()
    app.buttons["inspection.region.joint.0"].tap()
    let seam = app.staticTexts["inspection.joint.seam"]
    reveal(seam, in: scroll)
    assertHorizontallyContained(seam, in: app)
    attachScreenshot(app, name: "Large text joint evidence")
    let begin = app.buttons["inspection.edit.begin"]
    reveal(begin, in: scroll); begin.tap()
    for id in ["inspection.edit.up", "inspection.edit.down", "inspection.edit.apply", "inspection.edit.cancel"] {
      let button = app.buttons[id]
      reveal(button, in: scroll)
      assertHorizontallyContained(button, in: app)
    }
    attachScreenshot(app, name: "Large text deliberate seam controls")
    app.buttons["inspection.edit.cancel"].tap()
    app.buttons["inspection.done"].tap()
  }

  func testEditedProjectSavesThroughFilesAndReopensAfterEmptyLaunch() {
    let app = launch(scenario: "baseline")
    confirmOrder(in: app)
    app.buttons["workspace.reconstruct"].tap()
    XCTAssertTrue(app.staticTexts["workspace.result.dimensions"].waitForExistence(timeout: 30))
    openInspection(in: app)
    let inspection = app.scrollViews["inspection.scroll"]
    app.buttons["inspection.region"].tap()
    app.buttons["inspection.region.joint.0"].tap()
    for id in ["inspection.edit.begin", "inspection.edit.down", "inspection.edit.apply"] {
      let button = app.buttons[id]
      reveal(button, in: inspection)
      let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: button)
      XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
      button.tap()
    }
    let changed = app.staticTexts["inspection.edit.state"]
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == 'Modified seams'"), object: changed)], timeout: 10), .completed)
    XCTAssertTrue(app.staticTexts["inspection.joint.seam"].label.contains("output row 137; overlap row 25"))
    app.buttons["inspection.done"].tap()
    let save = app.buttons["workspace.project.save"]
    reveal(save, in: app.scrollViews["workspace.scroll"])
    XCTAssertTrue(save.isEnabled)
    save.tap()
    let name = "Native roundtrip " + String(UUID().uuidString.prefix(8))
    let field = app.alerts.textFields["project.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText(name)
    app.alerts.buttons["project.folder"].tap()
    guard chooseCurrentFilesFolder(in: app) else { return }
    let status = app.staticTexts["workspace.project.status"]
    XCTAssertTrue(status.waitForExistence(timeout: 15))
    XCTAssertTrue(status.label.contains("Saved " + name + ".traktion"))
    attachScreenshot(app, name: "Local project saved with committed seam")

    app.terminate()
    app.launchEnvironment.removeValue(forKey: "TRAKTION_UI_FIXTURE")
    app.launch()
    XCTAssertTrue(app.buttons["workspace.project.open"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.staticTexts["capture.0.name"].exists)
    XCTAssertFalse(app.buttons["workspace.project.save"].isEnabled)
    app.buttons["workspace.project.open"].tap()
    guard chooseProjectInFiles(name, app: app) else { return }
    XCTAssertTrue(app.staticTexts["capture.2.name"].waitForExistence(timeout: 30))
    XCTAssertFalse(app.staticTexts["workspace.failure"].exists)
    XCTAssertTrue(status.label.contains("Opened " + name + ".traktion"))
    for index in 0..<3 {
      XCTAssertEqual(app.staticTexts["capture.\(index).name"].label,
        String(format: "%d. capture-%03d.png", index + 1, index + 1))
    }
    XCTAssertEqual(app.staticTexts["workspace.result.dimensions"].label, "96 × 384 pixels")
    XCTAssertTrue(app.staticTexts["workspace.result.editState"].label.contains("Modified seams"))
    openInspection(in: app)
    XCTAssertTrue(app.buttons["inspection.edit.undo"].exists)
    XCTAssertTrue(app.buttons["inspection.edit.redo"].exists)
    XCTAssertFalse(app.buttons["inspection.edit.undo"].isEnabled)
    XCTAssertFalse(app.buttons["inspection.edit.redo"].isEnabled)
    app.buttons["inspection.region"].tap()
    app.buttons["inspection.region.joint.0"].tap()
    XCTAssertTrue(app.staticTexts["inspection.joint.seam"].label.contains("output row 137; overlap row 25"))
    XCTAssertTrue(app.staticTexts["inspection.joint.automaticSeam"].label.contains("136"))
    XCTAssertTrue(app.staticTexts["inspection.joint.confidence"].label.contains("Exact"))
    attachScreenshot(app, name: "Reopened project original evidence and committed seam")
    app.buttons["inspection.done"].tap()
  }

  func testProjectPickerCancellationAndLargeTextControlsPreserveWorkspace() {
    let app = XCUIApplication()
    XCUIDevice.shared.orientation = .portrait
    app.launchEnvironment["TRAKTION_UI_FIXTURE"] = "baseline"
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    app.launch()
    waitForImport(in: app, count: 3)
    let scroll = app.scrollViews["workspace.scroll"]
    for id in ["workspace.project.open", "workspace.project.save"] {
      let button = app.buttons[id]
      reveal(button, in: scroll)
      assertHorizontallyContained(button, in: app)
    }
    XCTAssertFalse(app.buttons["workspace.project.save"].isEnabled)
    let open = app.buttons["workspace.project.open"]
    reveal(open, in: scroll); open.tap()
    let cancel = app.navigationBars.buttons["Cancel"].firstMatch
    guard cancel.waitForExistence(timeout: 15) else { recordFilesState(app); XCTFail("Project Files picker was not presented"); return }
    cancel.tap()
    XCTAssertTrue(open.waitForExistence(timeout: 10))
    XCTAssertEqual(app.staticTexts["capture.0.name"].label, "1. capture-001.png")
    XCTAssertFalse(app.staticTexts["workspace.failure"].exists)
    XCTAssertFalse(app.staticTexts["workspace.project.status"].exists)
    attachScreenshot(app, name: "Accessible project controls after Files cancellation")
  }

  func testSaveCancellationAndCorruptFilesProjectKeepReconstruction() {
    let app = launch(scenario: "baseline")
    confirmOrder(in: app)
    app.buttons["workspace.reconstruct"].tap()
    let dimensions = app.staticTexts["workspace.result.dimensions"]
    XCTAssertTrue(dimensions.waitForExistence(timeout: 30))
    let scroll = app.scrollViews["workspace.scroll"]
    let save = app.buttons["workspace.project.save"]
    reveal(save, in: scroll); save.tap()
    XCTAssertTrue(app.alerts.textFields["project.name"].waitForExistence(timeout: 5))
    app.alerts.buttons["Cancel"].tap()
    XCTAssertEqual(dimensions.label, "96 × 384 pixels")
    XCTAssertFalse(app.staticTexts["workspace.project.status"].exists)
    save.tap()
    let field = app.alerts.textFields["project.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap(); field.typeText("Cancelled project")
    app.alerts.buttons["project.folder"].tap()
    let cancel = app.navigationBars.buttons["Cancel"].firstMatch
    guard cancel.waitForExistence(timeout: 15) else {
      recordFilesState(app); XCTFail("Save folder picker did not appear"); return
    }
    cancel.tap()
    XCTAssertTrue(save.waitForExistence(timeout: 10))
    XCTAssertEqual(dimensions.label, "96 × 384 pixels")
    XCTAssertFalse(app.staticTexts["workspace.project.status"].exists)
    XCTAssertFalse(app.staticTexts["workspace.failure"].exists)
    let open = app.buttons["workspace.project.open"]
    reveal(open, in: scroll); open.tap()
    guard chooseProjectInFiles("Corrupt native fixture", app: app) else { return }
    let failure = app.staticTexts["workspace.failure"]
    XCTAssertTrue(failure.waitForExistence(timeout: 15))
    XCTAssertTrue(failure.label.contains("corrupt"))
    XCTAssertEqual(dimensions.label, "96 × 384 pixels")
    XCTAssertEqual(app.staticTexts["capture.0.name"].label, "1. capture-001.png")
    XCTAssertEqual(app.staticTexts["capture.2.name"].label, "3. capture-003.png")
    XCTAssertTrue(app.staticTexts["workspace.result.editState"].label.contains("Automatic seams"))
    XCTAssertTrue(save.isEnabled)
    reveal(failure, in: scroll)
    attachScreenshot(app, name: "Corrupt project refusal preserves reconstruction")
  }

  private func chooseCurrentFilesFolder(in app: XCUIApplication) -> Bool {
    // The production default directory is this app's local Documents folder.
    // This is the real system folder picker, with no injected URL or test save path.
    let open = app.navigationBars.buttons["Open"].firstMatch
    guard open.waitForExistence(timeout: 15), open.isEnabled else {
      recordFilesState(app); XCTFail("Files did not offer the local folder confirmation"); return false
    }
    recordFilesState(app)
    open.tap()
    return true
  }

  private func chooseProjectInFiles(_ name: String, app: XCUIApplication) -> Bool {
    let file = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    let text = app.staticTexts.matching(NSPredicate(format: "label == %@ OR label == %@", name, name + ".traktion")).firstMatch
    guard file.waitForExistence(timeout: 15) || text.exists else {
      recordFilesState(app); XCTFail("Saved project was absent from the actual Files picker"); return false
    }
    recordFilesState(app)
    if file.exists { file.tap() } else { text.tap() }
    let confirm = app.navigationBars.buttons["Open"].firstMatch
    if confirm.exists && confirm.isHittable { confirm.tap() }
    return true
  }

  private func recordFilesState(_ app: XCUIApplication) {
    let tree = XCTAttachment(string: app.debugDescription)
    tree.name = "Actual Files picker accessibility tree"
    tree.lifetime = .keepAlways
    add(tree)
    attachScreenshot(app, name: "Actual Files picker")
  }

  private func openInspection(in app: XCUIApplication) {
    let inspect = app.buttons["workspace.result.inspect"]
    reveal(inspect, in: app.scrollViews["workspace.scroll"])
    inspect.tap()
    XCTAssertTrue(app.staticTexts["inspection.dimensions"].waitForExistence(timeout: 10))
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
    for _ in 0..<20 {
      if element.isHittable { break }
      if scroll.identifier == "inspection.scroll" {
        // The image intentionally consumes drags for pixel panning. Scroll the
        // padding and move the target toward the viewport center. Fixed full
        // swipes can oscillate past a large-text control hidden by the toolbar.
        let viewport = scroll.frame
        let targetY = element.exists ? element.frame.midY : viewport.maxY
        let distance = (viewport.midY - targetY) / max(1, viewport.height)
        let bounded = max(-0.3, min(0.3, distance))
        let movement = abs(bounded) < 0.1 ? (bounded < 0 ? -0.1 : 0.1) : bounded
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5 + movement))
        start.press(forDuration: 0.01, thenDragTo: end)
      } else if element.exists && element.frame.maxY <= scroll.frame.minY {
        scroll.swipeDown()
      } else {
        scroll.swipeUp()
      }
    }
    XCTAssertTrue(element.exists)
    XCTAssertTrue(element.isHittable, "Could not reveal \(element.identifier)")
  }

  private func assertHorizontallyContained(_ element: XCUIElement, in app: XCUIApplication) {
    let viewport = app.windows.firstMatch.frame
    XCTAssertGreaterThan(element.frame.width, 0)
    XCTAssertGreaterThanOrEqual(element.frame.minX, viewport.minX - 1)
    XCTAssertLessThanOrEqual(element.frame.maxX, viewport.maxX + 1)
  }

  private func attachScreenshot(_ app: XCUIApplication, name: String) {
    // Capture the display rather than a rotated application's cropped bounds.
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = name
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}
