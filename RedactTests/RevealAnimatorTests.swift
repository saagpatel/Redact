import XCTest
import UIKit
@testable import Redact

/// Coverage for the reveal cascade — the payoff animation at the end of a session.
///
/// `revealDuration` is pure and gets exhaustive boundary coverage. `animate` is checked
/// through the animations it installs and the layer state it leaves behind, since the
/// visual cascade itself is not something a unit test can observe.
@MainActor
final class RevealAnimatorTests: XCTestCase {

    private let animator = RevealAnimator()

    // MARK: - Helpers

    private func makeLayers(_ count: Int) -> (host: CALayer, layers: [CAShapeLayer]) {
        let host = CALayer()
        let layers = (0..<count).map { _ -> CAShapeLayer in
            let layer = CAShapeLayer()
            layer.opacity = 1
            host.addSublayer(layer)
            return layer
        }
        return (host, layers)
    }

    private func grouped(_ layers: [CAShapeLayer]) -> [(paragraphIndex: Int, layers: [CAShapeLayer])] {
        layers.enumerated().map { (paragraphIndex: $0.offset, layers: [$0.element]) }
    }

    // MARK: - revealDuration bounds

    func testRevealDurationFloorsAtTwoSeconds() {
        // 400 words / 200 lands exactly on the floor; anything below is clamped up to it.
        XCTAssertEqual(RevealAnimator.revealDuration(wordCount: 0), 2.0)
        XCTAssertEqual(RevealAnimator.revealDuration(wordCount: 1), 2.0)
        XCTAssertEqual(RevealAnimator.revealDuration(wordCount: 399), 2.0)
        XCTAssertEqual(RevealAnimator.revealDuration(wordCount: 400), 2.0)
    }

    func testRevealDurationCeilingsAtFiveSeconds() {
        // 1000 words / 200 lands exactly on the ceiling; anything above is clamped down.
        XCTAssertEqual(RevealAnimator.revealDuration(wordCount: 1000), 5.0)
        XCTAssertEqual(RevealAnimator.revealDuration(wordCount: 1001), 5.0)
        XCTAssertEqual(RevealAnimator.revealDuration(wordCount: 50_000), 5.0)
    }

    func testRevealDurationScalesLinearlyBetweenTheBounds() {
        XCTAssertEqual(RevealAnimator.revealDuration(wordCount: 600), 3.0, accuracy: 0.0001)
        XCTAssertEqual(RevealAnimator.revealDuration(wordCount: 800), 4.0, accuracy: 0.0001)
        XCTAssertEqual(RevealAnimator.revealDuration(wordCount: 900), 4.5, accuracy: 0.0001)
    }

    func testRevealDurationNeverLeavesTheTwoToFiveSecondRange() {
        for wordCount in stride(from: 0, through: 3000, by: 25) {
            let duration = RevealAnimator.revealDuration(wordCount: wordCount)
            XCTAssertGreaterThanOrEqual(duration, 2.0, "word count \(wordCount)")
            XCTAssertLessThanOrEqual(duration, 5.0, "word count \(wordCount)")
        }
    }

    func testRevealDurationNeverDecreasesAsDocumentsGrow() {
        var previous = RevealAnimator.revealDuration(wordCount: 0)
        for wordCount in stride(from: 0, through: 2000, by: 10) {
            let duration = RevealAnimator.revealDuration(wordCount: wordCount)
            XCTAssertGreaterThanOrEqual(duration, previous, "regressed at word count \(wordCount)")
            previous = duration
        }
    }

    func testRevealDurationClampsNegativeWordCountToTheFloor() {
        // Not reachable through the UI, but the formula must not return a negative
        // duration if a caller ever passes garbage.
        XCTAssertEqual(RevealAnimator.revealDuration(wordCount: -500), 2.0)
    }

    // MARK: - animate: empty input

    func testAnimateWithNoLayersCallsCompletionImmediately() {
        var completed = false
        animator.animate(overlayLayers: [], wordCount: 100) { completed = true }

        XCTAssertTrue(completed, "an unredacted document must not wait on an empty cascade")
    }

    func testAnimateWithParagraphsButNoLayersCallsCompletionImmediately() {
        var completed = false
        animator.animate(overlayLayers: [(paragraphIndex: 0, layers: [])], wordCount: 100) {
            completed = true
        }

        XCTAssertTrue(completed)
    }

    // MARK: - animate: installed animations

    func testAnimateAddsACascadeAnimationToEveryLayer() {
        let (_, layers) = makeLayers(5)
        animator.animate(overlayLayers: grouped(layers), wordCount: 400) {}

        for (index, layer) in layers.enumerated() {
            XCTAssertNotNil(layer.animation(forKey: "cascadeReveal"), "layer \(index) was not animated")
        }
    }

    func testAnimateFadesLayersToFullyTransparent() throws {
        let (_, layers) = makeLayers(2)
        animator.animate(overlayLayers: grouped(layers), wordCount: 400) {}

        let animation = try XCTUnwrap(layers[0].animation(forKey: "cascadeReveal") as? CABasicAnimation)
        XCTAssertEqual(animation.keyPath, "opacity")
        XCTAssertEqual(animation.toValue as? Float, 0)
        XCTAssertEqual(animation.fillMode, .forwards)
        XCTAssertFalse(animation.isRemovedOnCompletion,
                       "layers must stay hidden after the animation rather than snapping back")
    }

    func testAnimateStaggersLayersInParagraphOrder() throws {
        let (_, layers) = makeLayers(4)
        animator.animate(overlayLayers: grouped(layers), wordCount: 400) {}

        let beginTimes = try layers.map {
            try XCTUnwrap($0.animation(forKey: "cascadeReveal") as? CABasicAnimation).beginTime
        }

        for (index, beginTime) in beginTimes.enumerated().dropFirst() {
            XCTAssertGreaterThan(beginTime, beginTimes[index - 1],
                                 "layer \(index) must start after layer \(index - 1) — the reveal is a cascade")
        }
    }

    func testAnimateSpreadsTheCascadeAcrossTheRevealDuration() throws {
        let layerCount = 4
        let (_, layers) = makeLayers(layerCount)
        animator.animate(overlayLayers: grouped(layers), wordCount: 600) {}  // 3.0s total

        let first = try XCTUnwrap(layers[0].animation(forKey: "cascadeReveal") as? CABasicAnimation)
        let last = try XCTUnwrap(layers[layerCount - 1].animation(forKey: "cascadeReveal") as? CABasicAnimation)

        // Last layer starts (layerCount - 1)/layerCount of the way through the total.
        XCTAssertEqual(last.beginTime - first.beginTime, 3.0 * 3.0 / 4.0, accuracy: 0.05)
    }

    // MARK: - animate: teardown

    func testAnimateHidesAndDetachesLayersThenCallsCompletion() {
        let (host, layers) = makeLayers(1)
        XCTAssertEqual(host.sublayers?.count, 1)

        let finished = expectation(description: "cascade completes")
        animator.animate(overlayLayers: grouped(layers), wordCount: 0) { finished.fulfill() }

        // Single layer: the cascade is one 0.3s animation with no stagger ahead of it.
        wait(for: [finished], timeout: 3.0)

        XCTAssertEqual(layers[0].opacity, 0, "text must end fully revealed")
        XCTAssertNil(layers[0].superlayer, "spent overlays must be detached, not left stacked")
        XCTAssertTrue(host.sublayers?.isEmpty ?? true)
    }
}
