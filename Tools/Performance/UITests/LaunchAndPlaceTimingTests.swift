import XCTest

/// Timings for Tools/Performance/measure.sh. Every sample is printed as one `MINIFARM_PERF {json}` line.
/// Run only through measure.sh: it installs the Release app, prepares the scenario and owns the simulator.
@MainActor
final class LaunchAndPlaceTimingTests: XCTestCase {
    private let app = XCUIApplication()
    private let clock = ContinuousClock()
    private let environment = ProcessInfo.processInfo.environment
    /// Avatar of the injected QA farm, see Tools/Performance/QAFarm/main.swift.
    private let qaProfile = "family.picker.profile.animal.rabbit"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private var samples: Int { max(1, Int(environment["MINIFARM_PERF_SAMPLES"] ?? "") ?? 5) }

    /// Every measured control is a Button. A typed query keeps XCTest's in-app snapshot matching
    /// cheap; `descendants(matching: .any)` in a busy loop occupied the app's main thread itself.
    private func node(_ id: String) -> XCUIElement { app.buttons[id] }

    /// Any control that only exists once a place is shown: its resident, beds, shelf, tree,
    /// decoration box, discoveries or the targets of a running activity.
    private var placeControl: XCUIElement {
        app.buttons.matching(NSPredicate(format:
            "identifier IN %@ OR identifier BEGINSWITH 'world.bed.' OR identifier BEGINSWITH 'world.target.' "
            + "OR identifier BEGINSWITH 'world.discover.'",
            ["world.resident", "world.shelf", "world.tree", "world.decorationBox"])).firstMatch
    }

    private func milliseconds(since start: ContinuousClock.Instant) -> Double {
        (clock.now - start) / .milliseconds(1)
    }

    /// Waits for the element, then polls every 100 ms until it can receive a tap. The measured
    /// time therefore includes XCTest's accessibility snapshot latency (resolution ≈ 0.1–0.5 s).
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 90,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        _ = element.waitForExistence(timeout: timeout)
        while !(element.exists && element.isHittable) {
            if Date() > deadline {
                XCTFail("Nicht bedienbar: \(element)\n\(app.debugDescription)", file: file, line: line)
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func record(_ metric: String, _ fields: [String: Any]) throws {
        var line = fields
        line["metric"] = metric
        let json = try JSONSerialization.data(withJSONObject: line, options: [.sortedKeys])
        print("MINIFARM_PERF " + String(decoding: json, as: UTF8.self))
    }

    private func screenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Process start after terminate until the first view accepts a tap: the profile picker.
    /// `MINIFARM_PERF_SCENARIO=fresh` expects a new install, `qa` the injected QA farm.
    func testColdLaunchToOperablePicker() throws {
        let scenario = environment["MINIFARM_PERF_SCENARIO"] ?? "fresh"
        let target = scenario == "qa" ? qaProfile : "family.picker.setupButton"
        for sample in 0..<samples {
            app.terminate()
            let start = clock.now
            app.launch()
            let launchReturned = milliseconds(since: start)
            waitUntilHittable(node(target))
            try record("coldLaunch", ["scenario": scenario, "sample": sample, "unit": "ms",
                                      "launchReturned": launchReturned, "operable": milliseconds(since: start)])
        }
        screenshot("picker-\(scenario)")
    }

    /// Apple's launch metric (process start until the app is responsive) as a cross-check.
    func testSystemLaunchMetric() {
        let options = XCTMeasureOptions()
        options.iterationCount = samples
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.launch()
            app.terminate()
        }
    }

    /// QA farm only: overview to a location until one of that location's own scene controls is
    /// operable and the overview's location buttons are gone. Covers one level-1 and one level-5
    /// location. The QA farm may have a running activity, then its targets mark the shown place.
    func testOverviewToPlaceOnQAFarm() throws {
        app.terminate()
        app.launch()
        let profile = node(qaProfile)
        waitUntilHittable(profile)
        let open = clock.now
        profile.tap()
        let places = ["loc.henhouse", "loc.paddock"]
        waitUntilHittable(node("world.place." + places[0]))
        try record("openFarm", ["scenario": "qa", "sample": 0, "unit": "ms", "operable": milliseconds(since: open)])
        screenshot("overview-qa")

        for sample in 0..<samples {
            for id in places {
                let button = node("world.place." + id)
                waitUntilHittable(button)
                let start = clock.now
                button.tap()
                let control = placeControl
                waitUntilHittable(control)
                let operable = milliseconds(since: start)
                XCTAssertFalse(node("world.place." + id).exists, "Übersicht ist noch sichtbar")
                try record("placeSwitch", ["scenario": "qa", "sample": sample, "unit": "ms", "place": id,
                                           "operable": operable, "control": control.identifier])
                if sample == 0 { screenshot("place-\(id)") }
                node("world.home").tap()
            }
        }
    }
}
