import UIKit
import StillKit

/// Builds the cold-launch splash and the menu navigation bar logo.
@MainActor
enum StillSampleSplash {
    /// Creates a calm ring containing a solid pebble. The pebble carries over into the
    /// restored game mode while the ring and app name fade away.
    static func make() -> StillSplash {
        let container = UIView()
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false

        let ring = StillRingView()
        ring.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(ring)

        let pebble = StillPebbleView(color: Still.pieceStrong)
        pebble.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pebble)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 88),
            container.heightAnchor.constraint(equalToConstant: 88),
            ring.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            ring.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ring.topAnchor.constraint(equalTo: container.topAnchor),
            ring.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            pebble.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            pebble.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            pebble.widthAnchor.constraint(equalToConstant: 36),
            pebble.heightAnchor.constraint(equalToConstant: 36),
        ])

        return StillSplash(logo: container, showsName: true, carriedView: pebble)
    }
}

/// Small version of the app mark for the series menu's navigation bar.
@MainActor
final class StillSampleLogoView: UIView {
    private let markSize: CGFloat

    init(size: CGFloat = 24) {
        self.markSize = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false

        let ring = StillRingView()
        ring.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ring)

        let dot = StillPebbleView(color: Still.pieceStrong)
        dot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)

        let dotSize = size * 0.42
        NSLayoutConstraint.activate([
            ring.leadingAnchor.constraint(equalTo: leadingAnchor),
            ring.trailingAnchor.constraint(equalTo: trailingAnchor),
            ring.topAnchor.constraint(equalTo: topAnchor),
            ring.bottomAnchor.constraint(equalTo: bottomAnchor),
            dot.centerXAnchor.constraint(equalTo: centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: dotSize),
            dot.heightAnchor.constraint(equalToConstant: dotSize),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: markSize, height: markSize)
    }
}

/// A circular pebble drawn in a Still role colour.
@MainActor
final class StillPebbleView: UIView {
    init(color: UIColor) {
        super.init(frame: .zero)
        backgroundColor = color
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        stillCorners(min(bounds.width, bounds.height) / 2)
    }
}

/// A soft circular outline drawn in `Still.pieceAmbient`.
@MainActor
final class StillRingView: UIView {
    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 2.5
        layer.addSublayer(shapeLayer)
        updateColours()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: StillRingView, _) in
            view.updateColours()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        let inset = shapeLayer.lineWidth / 2
        shapeLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset)).cgPath
    }

    private func updateColours() {
        shapeLayer.strokeColor = Still.pieceAmbient.resolvedColor(with: traitCollection).cgColor
    }
}
