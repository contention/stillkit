import UIKit
import StillKit

/// Displays the three capsule button presets in enabled and disabled states.
@MainActor
final class ButtonsViewController: UIViewController {
    private let statusLabel = ShowcaseUI.makeNote("Tap any enabled button.", alignment: .center)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Buttons"
        view.backgroundColor = Still.background

        let stack = ShowcaseUI.installScrollableStack(in: view, spacing: StillSpace.s4, topPadding: StillSpace.s6)

        stack.addArrangedSubview(ShowcaseUI.makeHeading("Enabled"))
        stack.addArrangedSubview(makeButton(.stillPrimary("Primary action"), name: "Primary"))
        stack.addArrangedSubview(makeButton(.stillSecondary("Secondary action"), name: "Secondary"))
        stack.addArrangedSubview(makeButton(.stillPlain("Plain action"), name: "Plain"))
        stack.addArrangedSubview(statusLabel)

        stack.addArrangedSubview(ShowcaseUI.makeHeading("Disabled"))
        stack.addArrangedSubview(makeButton(.stillPrimary("Primary disabled"), name: nil, enabled: false))
        stack.addArrangedSubview(makeButton(.stillSecondary("Secondary disabled"), name: nil, enabled: false))
        stack.addArrangedSubview(makeButton(.stillPlain("Plain disabled"), name: nil, enabled: false))
    }

    private func makeButton(_ config: UIButton.Configuration, name: String?, enabled: Bool = true) -> UIButton {
        let button = UIButton(configuration: config)
        button.isEnabled = enabled
        if let name {
            button.addAction(UIAction { [weak self] _ in
                StillHaptics.touch()
                self?.statusLabel.text = "\(name) tapped."
            }, for: .primaryActionTriggered)
        }
        return button
    }
}
