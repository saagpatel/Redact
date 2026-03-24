import UIKit

struct RevealAnimator {

    /// Duration formula: min(5.0, max(2.0, Double(wordCount) / 200.0))
    static func revealDuration(wordCount: Int) -> TimeInterval {
        min(5.0, max(2.0, Double(wordCount) / 200.0))
    }

    /// Cascade-reveals all overlay layers from first to last.
    /// Each layer animates opacity 1→0 with staggered delay.
    /// Completion fires after the last layer finishes.
    @MainActor
    func animate(
        overlayLayers: [(paragraphIndex: Int, layers: [CAShapeLayer])],
        wordCount: Int,
        completion: @escaping @MainActor @Sendable () -> Void
    ) {
        let allLayers = overlayLayers.flatMap(\.layers)
        guard !allLayers.isEmpty else {
            completion()
            return
        }

        let totalDuration = Self.revealDuration(wordCount: wordCount)
        let layerCount = allLayers.count
        let perLayerDelay = totalDuration / Double(layerCount)
        let animationDuration: TimeInterval = 0.3

        let startTime = CACurrentMediaTime()

        for (index, layer) in allLayers.enumerated() {
            let delay = Double(index) * perLayerDelay

            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = layer.presentation()?.opacity ?? layer.opacity
            animation.toValue = 0
            animation.duration = animationDuration
            animation.beginTime = startTime + delay
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: "cascadeReveal")
        }

        // Fire completion after the last layer's animation ends
        let lastLayerEnd = Double(layerCount - 1) * perLayerDelay + animationDuration
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(lastLayerEnd))
            for layer in allLayers {
                layer.opacity = 0
                layer.removeAllAnimations()
                layer.removeFromSuperlayer()
            }
            completion()
        }
    }
}
