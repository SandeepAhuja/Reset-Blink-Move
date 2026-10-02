//
//  OverlayWindowPresenterTests.swift
//
//  Host-app tests for the NSPanel-backed overlay adapter. Requires a screen
//  (skipped otherwise), so it runs on a developer Mac / GUI CI but never fails
//  headless.
//

import XCTest
import Cocoa
@testable import Reset

final class OverlayWindowPresenterTests: XCTestCase {

    @MainActor
    func testPresentShowsPanelAndDismissHidesIt() throws {
        try XCTSkipIf(NSScreen.main == nil, "overlay needs a screen")

        let presenter = OverlayWindowPresenter()
        XCTAssertFalse(presenter.isShowing)

        presenter.present(OverlayRequest(title: "Look away for 20 seconds",
                                         subtitle: "Focus on something ~20 feet away",
                                         seconds: 20))
        XCTAssertTrue(presenter.isShowing)

        presenter.dismiss()
        XCTAssertFalse(presenter.isShowing)
    }

    @MainActor
    func testWrappedTextHeightGrowsWithLength() {
        let font = NSFont.systemFont(ofSize: 13)
        let width: CGFloat = 380
        let shortText = OverlayWindowPresenter.textHeight("Focus on something far away", font: font, width: width)
        let longText = OverlayWindowPresenter.textHeight(
            "Stand and walk for a minute. Movement pumps blood back up your legs and keeps you limber and comfortable.",
            font: font, width: width)
        // Long copy reserves more vertical space (wraps to multiple lines) rather
        // than being clipped to one truncated line.
        XCTAssertGreaterThan(longText, shortText)
    }

    @MainActor
    func testLongSubtitleWrapsAndStaysWithinPanel() {
        let longBody = "Stand and walk for a minute. Movement pumps blood back up your legs and keeps you limber and comfortable."
        let oneLine = OverlayWindowPresenter.textHeight("One line", font: .systemFont(ofSize: 13), width: 380)

        let built = OverlayWindowPresenter.buildOverlay(
            OverlayRequest(title: "Stand up & move", subtitle: longBody, seconds: 30),
            skipTitle: "Skip", target: nil, skipAction: nil)

        // The subtitle wrapped to more than one line instead of truncating...
        XCTAssertGreaterThan(built.subtitle.frame.height, oneLine)
        // ...and its box is fully inside the panel (nothing clipped top/bottom).
        XCTAssertGreaterThanOrEqual(built.subtitle.frame.minY, 0)
        XCTAssertLessThanOrEqual(built.subtitle.frame.maxY, built.size.height)
        XCTAssertLessThanOrEqual(built.subtitle.frame.width, built.size.width)

        // Optional visual artifact for manual inspection.
        if let path = ProcessInfo.processInfo.environment["OVERLAY_SNAPSHOT_PATH"] {
            Self.writePNG(built.view, size: built.size, to: URL(fileURLWithPath: path))
        }
    }

    @MainActor
    private static func writePNG(_ view: NSView, size: NSSize, to url: URL) {
        let wrapper = NSView(frame: NSRect(origin: .zero, size: size))
        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 1).cgColor
        wrapper.layer?.cornerRadius = 18
        wrapper.addSubview(view)
        guard let rep = wrapper.bitmapImageRepForCachingDisplay(in: wrapper.bounds) else { return }
        wrapper.cacheDisplay(in: wrapper.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    @MainActor
    func testPresentWithLongSubtitleShows() throws {
        try XCTSkipIf(NSScreen.main == nil, "overlay needs a screen")
        let presenter = OverlayWindowPresenter()
        presenter.present(OverlayRequest(
            title: "Stand up & move",
            subtitle: "Stand and walk for a minute. Movement pumps blood back up your legs and keeps you limber.",
            seconds: 30))
        XCTAssertTrue(presenter.isShowing)
        presenter.dismiss()
    }

    @MainActor
    func testPresentWhileShowingIsANoOp() throws {
        try XCTSkipIf(NSScreen.main == nil, "overlay needs a screen")

        let presenter = OverlayWindowPresenter()
        presenter.present(OverlayRequest(title: "First", subtitle: "sub", seconds: 20))
        XCTAssertTrue(presenter.isShowing)

        // Presenting again while visible must not replace/relaunch the panel.
        presenter.present(OverlayRequest(title: "Second", subtitle: "sub", seconds: 20))
        XCTAssertTrue(presenter.isShowing)

        presenter.dismiss()
        XCTAssertFalse(presenter.isShowing)
    }
}
