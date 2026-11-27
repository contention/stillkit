import UIKit
import StillKit

/// Interactive haptic tester: individual triggers (`touch`, `snap`, `tick`) plus a draggable
/// piece on `Still.canvas` that snaps onto targets with `shadow-lift` while dragged.
@MainActor
final class HapticsViewController: UIViewController {
    private let stage = HapticSnapStageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Haptics"
        view.backgroundColor = Still.background

        let stack = ShowcaseUI.installScrollableStack(in: view, spacing: StillSpace.s4, topPadding: StillSpace.s5)

        let buttonsRow = UIStackView()
        buttonsRow.axis = .vertical
        buttonsRow.spacing = StillSpace.s3

        let touchButton = UIButton(configuration: .stillSecondary("StillHaptics.touch()"))
        touchButton.addAction(UIAction { _ in StillHaptics.touch() }, for: .primaryActionTriggered)

        let snapButton = UIButton(configuration: .stillSecondary("StillHaptics.snap()"))
        snapButton.addAction(UIAction { _ in StillHaptics.snap() }, for: .primaryActionTriggered)

        let tickButton = UIButton(configuration: .stillSecondary("StillHaptics.tick()"))
        tickButton.addAction(UIAction { _ in StillHaptics.tick() }, for: .primaryActionTriggered)

        buttonsRow.addArrangedSubview(touchButton)
        buttonsRow.addArrangedSubview(snapButton)
        buttonsRow.addArrangedSubview(tickButton)

        let stageHeading = ShowcaseUI.makeHeading("Drag and snap")
        let note = ShowcaseUI.makeNote(
            "Drag the pebble over the three wells. Calls prepare() on drag start, snap() as it locks onto a well, and touch() when released."
        )

        stage.translatesAutoresizingMaskIntoConstraints = false
        stage.heightAnchor.constraint(equalToConstant: 220).isActive = true

        stack.addArrangedSubview(buttonsRow)
        stack.addArrangedSubview(stageHeading)
        stack.addArrangedSubview(note)
        stack.addArrangedSubview(stage)
    }
}

@MainActor
private final class HapticSnapStageView: UIView {
    private let piece = AdjustablePebbleView()
    private var wells: [UIView] = []
    private var snappedIndex: Int? = 1
    private var isDragging = false

    private let pieceSize: CGFloat = 52
    private let wellSize: CGFloat = 60
    private let snapRadius: CGFloat = 44

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Still.canvas
        stillCorners(StillRadius.xl)

        for index in 0..<3 {
            let well = UIView()
            well.backgroundColor = Still.pieceAmbient
            well.alpha = 0.45
            well.stillCorners(wellSize / 2)
            well.isAccessibilityElement = false
            well.tag = index
            addSubview(well)
            wells.append(well)
        }

        piece.backgroundColor = Still.pieceStrong
        piece.stillCorners(pieceSize / 2)
        piece.frame = CGRect(x: 0, y: 0, width: pieceSize, height: pieceSize)
        piece.isAccessibilityElement = true
        piece.accessibilityLabel = "Draggable pebble"
        piece.accessibilityTraits = .adjustable
        piece.onAdjust = { [weak self] delta in
            self?.stepWell(by: delta)
        }
        addSubview(piece)
        updateAccessibilityValue()

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        piece.addGestureRecognizer(pan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let positions = wellCenters()
        for (well, center) in zip(wells, positions) {
            well.frame = CGRect(x: center.x - wellSize / 2, y: center.y - wellSize / 2,
                                width: wellSize, height: wellSize)
        }
        if !isDragging, let index = snappedIndex, index < positions.count {
            piece.center = positions[index]
        }
    }

    private func wellCenters() -> [CGPoint] {
        [
            CGPoint(x: bounds.width * 0.22, y: bounds.midY),
            CGPoint(x: bounds.width * 0.50, y: bounds.midY),
            CGPoint(x: bounds.width * 0.78, y: bounds.midY),
        ]
    }

    private func stepWell(by delta: Int) {
        let current = snappedIndex ?? 1
        let next = min(max(current + delta, 0), wells.count - 1)
        guard next != current else { return }
        snappedIndex = next
        updateAccessibilityValue()
        StillHaptics.snap()
        let target = wellCenters()[next]
        StillMotion.animate { self.piece.center = target }
    }

    private func updateAccessibilityValue() {
        if let index = snappedIndex {
            piece.accessibilityValue = "Well \(index + 1) of \(wells.count)"
        } else {
            piece.accessibilityValue = nil
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        let centers = wellCenters()

        switch gesture.state {
        case .began:
            isDragging = true
            StillHaptics.prepare()
            setLifted(true)
        case .changed:
            if let hit = centers.enumerated().first(where: { hypot($0.element.x - point.x, $0.element.y - point.y) <= snapRadius }) {
                if snappedIndex != hit.offset {
                    snappedIndex = hit.offset
                    StillHaptics.snap()
                }
                piece.center = hit.element
            } else {
                snappedIndex = nil
                let half = pieceSize / 2 + StillSpace.s2
                piece.center = CGPoint(
                    x: min(max(point.x, half), bounds.width - half),
                    y: min(max(point.y, half), bounds.height - half)
                )
            }
        case .ended, .cancelled:
            isDragging = false
            setLifted(false)
            let nearest = centers.enumerated().min {
                hypot($0.element.x - piece.center.x, $0.element.y - piece.center.y)
                    < hypot($1.element.x - piece.center.x, $1.element.y - piece.center.y)
            }
            if let nearest {
                snappedIndex = nearest.offset
                updateAccessibilityValue()
                StillHaptics.touch()
                StillMotion.animate { self.piece.center = nearest.element }
            }
        default:
            break
        }
    }

    private func setLifted(_ lifted: Bool) {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let shadowColor = (isDark ? Still.background : Still.pieceStrong).resolvedColor(with: traitCollection)
        StillMotion.animate {
            self.piece.layer.shadowColor = shadowColor.cgColor
            self.piece.layer.shadowOpacity = lifted ? (isDark ? 0.45 : 0.16) : 0
            self.piece.layer.shadowRadius = lifted ? 12 : 0
            self.piece.layer.shadowOffset = lifted ? CGSize(width: 0, height: 8) : .zero
        }
    }
}

@MainActor
private final class AdjustablePebbleView: UIView {
    var onAdjust: ((Int) -> Void)?

    override func accessibilityIncrement() {
        onAdjust?(1)
    }

    override func accessibilityDecrement() {
        onAdjust?(-1)
    }
}
