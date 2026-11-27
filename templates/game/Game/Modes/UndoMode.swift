import UIKit
import StillKit

/// A mode that supports shake to undo and a clear row action.
///
/// Tap anywhere on the canvas to step the pebble to that spot, leaving quiet stones behind.
/// Shake the device (or use the menu's Undo button when Shake to Undo is off) to step back.
@MainActor
final class UndoMode: StillGameMode {
    static let id = "undo"

    let title = "Trace"
    let detail: String? = "Tap to place stepping stones. Shake to undo."
    let supportsUndo = true

    var canUndo: Bool {
        canvasView?.canUndo ?? false
    }

    var actions: [StillModeAction] {
        guard let canvasView, canvasView.canUndo else { return [] }
        return [
            .clear { [weak self] in
                self?.canvasView?.clearAll()
            }
        ]
    }

    var howToPlay: [String] {
        ["Tap anywhere to place a stepping stone."]
    }

    private var canvasView: TraceCanvasView?

    func makeGameView(context: StillModeContext) -> UIView {
        let view = TraceCanvasView()
        canvasView = view
        return view
    }

    func splashLanding(in gameView: UIView, carriedFrame: CGRect) -> StillSplashLanding? {
        guard let canvasView else { return nil }
        canvasView.layoutIfNeeded()
        return StillSplashLanding(onto: canvasView.activePebble, in: gameView)
    }

    func begin() {
        canvasView?.ensureInitialPosition()
    }

    func undo() {
        canvasView?.undoStep()
    }
}

@MainActor
private final class TraceCanvasView: UIView {
    let activePebble = StillPebbleView(color: Still.pieceStrong)
    private let activeSize: CGFloat = 44
    private let stoneSize: CGFloat = 20
    private var history: [CGPoint] = []
    private var stones: [UIView] = []
    private var hasPositioned = false

    var canUndo: Bool { !history.isEmpty }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Still.canvas

        activePebble.frame = CGRect(x: 0, y: 0, width: activeSize, height: activeSize)
        activePebble.isAccessibilityElement = true
        activePebble.accessibilityLabel = "Active pebble"
        addSubview(activePebble)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTouchesRequired = 1
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        ensureInitialPosition()
    }

    func ensureInitialPosition() {
        guard !hasPositioned, bounds.width > 0, bounds.height > 0 else { return }
        hasPositioned = true
        activePebble.center = defaultPoint()
    }

    private func defaultPoint() -> CGPoint {
        CGPoint(x: bounds.midX, y: bounds.height * 0.35)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        let previous = activePebble.center
        history.append(previous)

        let stone = StillPebbleView(color: Still.pieceAmbient)
        stone.frame = CGRect(x: 0, y: 0, width: stoneSize, height: stoneSize)
        stone.center = previous
        stone.alpha = 0
        stone.isAccessibilityElement = false
        insertSubview(stone, belowSubview: activePebble)
        stones.append(stone)

        StillHaptics.touch()
        StillMotion.animate {
            stone.alpha = 1
            self.activePebble.center = point
        }
    }

    func undoStep() {
        guard let previous = history.popLast() else { return }
        let removedStone = stones.popLast()
        StillHaptics.tick()
        StillMotion.animate({
            self.activePebble.center = previous
            removedStone?.alpha = 0
        }, completion: { _ in
            removedStone?.removeFromSuperview()
        })
    }

    func clearAll() {
        let toRemove = stones
        stones.removeAll()
        history.removeAll()
        let home = defaultPoint()
        StillHaptics.touch()
        StillMotion.animate({
            self.activePebble.center = home
            toRemove.forEach { $0.alpha = 0 }
        }, completion: { _ in
            toRemove.forEach { $0.removeFromSuperview() }
        })
    }
}
