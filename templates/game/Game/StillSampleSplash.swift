import UIKit
import StillKit

/// Builds the cold-launch splash and the menu navigation bar logo.
@MainActor
enum StillSampleSplash {
    /// Creates a calm ring containing a solid pebble. The pebble carries over into the
    /// restored game mode while the ring and app name fade away.
    static func make() -> StillSplash {
        let logo = StillSampleLogoView(size: 88)
        return StillSplash(logo: logo, showsName: true, carriedView: logo.pebble)
    }
}

/// App mark used on both the splash (88pt) and the series menu's navigation bar (24pt).
@MainActor
final class StillSampleLogoView: UIView {
    private let markSize: CGFloat
    let pebble = StillPebbleView(color: Still.pieceStrong)

    init(size: CGFloat = 24) {
        self.markSize = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false

        let ring = StillRingView()
        ring.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ring)

        pebble.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pebble)

        let dotSize = (size * 0.41).rounded()
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            ring.leadingAnchor.constraint(equalTo: leadingAnchor),
            ring.trailingAnchor.constraint(equalTo: trailingAnchor),
            ring.topAnchor.constraint(equalTo: topAnchor),
            ring.bottomAnchor.constraint(equalTo: bottomAnchor),
            pebble.centerXAnchor.constraint(equalTo: centerXAnchor),
            pebble.centerYAnchor.constraint(equalTo: centerYAnchor),
            pebble.widthAnchor.constraint(equalToConstant: dotSize),
            pebble.heightAnchor.constraint(equalToConstant: dotSize),
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
