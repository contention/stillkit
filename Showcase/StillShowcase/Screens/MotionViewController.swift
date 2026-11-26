import UIKit
import StillKit

/// Interactive demonstration of `StillMotion.animate`, honouring Reduce Motion automatically.
@MainActor
final class MotionViewController: UIViewController {
    private let stage = UIView()
    private let pebbleA = UIView()
    private let pebbleB = UIView()
    private let statusLabel = UILabel()
    private var movedRight = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Motion"
        view.backgroundColor = Still.background

        stage.backgroundColor = Still.canvas
        stage.stillCorners(StillRadius.xl)
        stage.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stage)

        pebbleA.backgroundColor = Still.pieceStrong
        pebbleA.stillCorners(28)
        pebbleA.frame = CGRect(x: 0, y: 0, width: 56, height: 56)
        stage.addSubview(pebbleA)

        // Used under Reduce Motion to demonstrate a pure crossfade with zero movement.
        pebbleB.backgroundColor = Still.pieceMid
        pebbleB.stillCorners(28)
        pebbleB.frame = CGRect(x: 0, y: 0, width: 56, height: 56)
        pebbleB.alpha = 0
        stage.addSubview(pebbleB)

        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = Still.labelSecondary
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        let button = UIButton(configuration: .stillPrimary("Animate"))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addAction(UIAction { [weak self] _ in
            self?.triggerMotion()
        }, for: .primaryActionTriggered)
        view.addSubview(button)

        let readable = view.readableContentGuide
        NSLayoutConstraint.activate([
            stage.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: StillSpace.s6),
            stage.leadingAnchor.constraint(equalTo: readable.leadingAnchor),
            stage.trailingAnchor.constraint(equalTo: readable.trailingAnchor),
            stage.heightAnchor.constraint(equalToConstant: 180),

            statusLabel.topAnchor.constraint(equalTo: stage.bottomAnchor, constant: StillSpace.s5),
            statusLabel.leadingAnchor.constraint(equalTo: readable.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: readable.trailingAnchor),

            button.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: StillSpace.s5),
            button.leadingAnchor.constraint(equalTo: readable.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: readable.trailingAnchor),
        ])

        updateStatus()
        NotificationCenter.default.addObserver(self, selector: #selector(reduceMotionChanged),
                                               name: UIAccessibility.reduceMotionStatusDidChangeNotification,
                                               object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        positionPebbles()
    }

    @objc private func reduceMotionChanged() {
        updateStatus()
        positionPebbles()
    }

    private func updateStatus() {
        if UIAccessibility.isReduceMotionEnabled {
            statusLabel.text = "Reduce Motion is ON: StillMotion uses a 0.3s crossfade with no movement."
        } else {
            statusLabel.text = "Reduce Motion is OFF: StillMotion uses a 0.5s spring with bounce 0."
        }
    }

    private func positionPebbles() {
        guard stage.bounds.width > 0 else { return }
        let left = CGPoint(x: StillSpace.s8 + 28, y: stage.bounds.midY)
        let right = CGPoint(x: stage.bounds.width - StillSpace.s8 - 28, y: stage.bounds.midY)

        if UIAccessibility.isReduceMotionEnabled {
            pebbleA.center = left
            pebbleB.center = right
            pebbleA.alpha = movedRight ? 0 : 1
            pebbleB.alpha = movedRight ? 1 : 0
        } else {
            pebbleA.alpha = 1
            pebbleB.alpha = 0
            pebbleA.center = movedRight ? right : left
        }
    }

    private func triggerMotion() {
        movedRight.toggle()
        StillHaptics.touch(0.5)
        StillMotion.animate {
            self.positionPebbles()
        }
    }
}
