import UIKit
import StillKit

/// A quiet mode with neither undo nor settings.
///
/// Drag the pebble around the canvas; it settles calmly with a soft touch haptic.
@MainActor
final class PlainMode: StillGameMode {
    static let id = "plain"

    let title = "Drift"
    let detail: String? = "A single quiet pebble with neither undo nor settings."

    private var canvasView: PlainCanvasView?

    func makeGameView(context: StillModeContext) -> UIView {
        let view = PlainCanvasView()
        canvasView = view
        return view
    }

    func splashLanding(in gameView: UIView, carriedFrame: CGRect) -> StillSplashLanding? {
        guard let canvasView else { return nil }
        canvasView.layoutIfNeeded()
        return StillSplashLanding(onto: canvasView.pebble, in: gameView)
    }

    func begin() {
        canvasView?.resetToCenter(animated: false)
    }
}

@MainActor
private final class PlainCanvasView: UIView {
    let pebble = StillPebbleView(color: Still.pieceStrong)
    private let pebbleDiameter: CGFloat = 56
    private var hasPositioned = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Still.canvas

        pebble.frame = CGRect(x: 0, y: 0, width: pebbleDiameter, height: pebbleDiameter)
        pebble.isAccessibilityElement = true
        pebble.accessibilityLabel = "Pebble"
        pebble.accessibilityHint = "Drag to move across the canvas"
        addSubview(pebble)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pebble.addGestureRecognizer(pan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if !hasPositioned {
            hasPositioned = true
            pebble.center = CGPoint(x: bounds.midX, y: bounds.midY)
        } else {
            pebble.center = clampedPoint(pebble.center)
        }
    }

    func resetToCenter(animated: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let target = CGPoint(x: bounds.midX, y: bounds.midY)
        if animated {
            StillMotion.animate { self.pebble.center = target }
        } else {
            pebble.center = target
        }
    }

    private func clampedPoint(_ point: CGPoint) -> CGPoint {
        let inset = safeAreaInsets
        let half = pebbleDiameter / 2 + StillSpace.s4
        return CGPoint(
            x: min(max(point.x, inset.left + half), bounds.width - inset.right - half),
            y: min(max(point.y, inset.top + half), bounds.height - inset.bottom - half)
        )
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let clamped = clampedPoint(gesture.location(in: self))

        switch gesture.state {
        case .began:
            StillHaptics.prepare()
            setLifted(true)
        case .changed:
            pebble.center = clamped
        case .ended, .cancelled:
            setLifted(false)
            StillHaptics.touch()
        default:
            break
        }
    }

    private func setLifted(_ lifted: Bool) {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let shadowColor = (isDark ? Still.background : Still.pieceStrong).resolvedColor(with: traitCollection)
        StillMotion.animate {
            self.pebble.layer.shadowColor = shadowColor.cgColor
            self.pebble.layer.shadowOpacity = lifted ? (isDark ? 0.45 : 0.16) : 0
            self.pebble.layer.shadowRadius = lifted ? 12 : 0
            self.pebble.layer.shadowOffset = lifted ? CGSize(width: 0, height: 8) : .zero
        }
    }
}
