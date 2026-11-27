import UIKit
import StillKit

/// A mode exercising all four `StillSetting` kinds: toggle, choice, stepper and slider.
///
/// Changes made in the menu's settings screen apply live and persist between launches.
@MainActor
final class SettingsMode: StillGameMode {
    static let id = "settings"

    let title = "Garden"
    let detail: String? = "Pebbles shaped by toggle, choice, stepper and slider settings."

    let settings: [StillSetting] = [
        .toggle("Outer ring", key: "ring", default: true),
        .choice("Arrangement", key: "arrangement", options: ["Circle", "Line", "Arc"], default: "Circle"),
        .stepper("Pebbles", key: "pebbles", range: 1...9, default: 5),
        .slider("Scale", key: "scale", range: 0.6...1.4, default: 1.0, valueLabel: { value in
            "\(Int((value * 100).rounded()))%"
        }),
    ]

    private var canvasView: GardenCanvasView?
    private var activeContext: StillModeContext?

    func makeGameView(context: StillModeContext) -> UIView {
        activeContext = context
        let view = GardenCanvasView()
        canvasView = view
        applySettings(from: context, animated: false)
        return view
    }

    func splashLanding(in gameView: UIView, carriedFrame: CGRect) -> StillSplashLanding? {
        guard let canvasView, let first = canvasView.primaryPebble else { return nil }
        canvasView.layoutIfNeeded()
        return StillSplashLanding(onto: first, in: gameView)
    }

    func begin() {
        guard let activeContext else { return }
        applySettings(from: activeContext, animated: false)
    }

    func settingDidChange(key: String, context: StillModeContext) {
        activeContext = context
        applySettings(from: context, animated: true)
    }

    private func applySettings(from context: StillModeContext, animated: Bool) {
        canvasView?.configure(
            showsRing: context.settings.bool("ring"),
            arrangement: context.settings.string("arrangement"),
            count: context.settings.int("pebbles"),
            scale: CGFloat(context.settings.double("scale")),
            animated: animated
        )
    }
}

@MainActor
private final class GardenCanvasView: UIView {
    private let ringView = StillRingView()
    private var pebbles: [StillPebbleView] = []
    private var showsRing = true
    private var arrangement = "Circle"
    private var count = 5
    private var scale: CGFloat = 1.0

    var primaryPebble: UIView? { pebbles.first }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Still.canvas
        ringView.isAccessibilityElement = false
        addSubview(ringView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(showsRing: Bool, arrangement: String, count: Int, scale: CGFloat, animated: Bool) {
        self.showsRing = showsRing
        self.arrangement = arrangement
        self.count = count
        self.scale = scale

        while pebbles.count < count {
            let color: UIColor = pebbles.isEmpty ? Still.pieceStrong : (pebbles.count % 2 == 1 ? Still.pieceMid : Still.pieceAmbient)
            let pebble = StillPebbleView(color: color)
            pebble.isAccessibilityElement = true
            pebble.accessibilityLabel = "Pebble \(pebbles.count + 1)"
            addSubview(pebble)
            pebbles.append(pebble)
        }
        while pebbles.count > count {
            pebbles.removeLast().removeFromSuperview()
        }

        if animated {
            StillMotion.animate { self.layoutElements() }
        } else {
            layoutElements()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutElements()
    }

    private func layoutElements() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let orbit = min(bounds.width, bounds.height) * 0.28 * scale
        let diameter = 36 * scale

        ringView.alpha = showsRing ? 1 : 0
        ringView.frame = CGRect(x: center.x - orbit, y: center.y - orbit,
                                width: orbit * 2, height: orbit * 2)

        for (index, pebble) in pebbles.enumerated() {
            let point: CGPoint
            if count == 1 {
                point = center
            } else {
                switch arrangement {
                case "Line":
                    let span = min(bounds.width - StillSpace.s8 * 2, orbit * 2.2)
                    let t = CGFloat(index) / CGFloat(max(1, count - 1)) - 0.5
                    point = CGPoint(x: center.x + t * span, y: center.y)
                case "Arc":
                    let t = CGFloat(index) / CGFloat(max(1, count - 1))
                    let angle = -.pi * 0.85 + t * (.pi * 0.7)
                    point = CGPoint(x: center.x + cos(angle) * orbit,
                                    y: center.y + sin(angle) * orbit + orbit * 0.25)
                default: // Circle
                    let angle = -.pi / 2 + CGFloat(index) * (2 * .pi / CGFloat(count))
                    point = CGPoint(x: center.x + cos(angle) * orbit,
                                    y: center.y + sin(angle) * orbit)
                }
            }
            pebble.frame = CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                                  width: diameter, height: diameter)
        }
    }
}
