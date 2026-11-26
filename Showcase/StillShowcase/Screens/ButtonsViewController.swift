import UIKit
import StillKit

/// Displays the three capsule button presets in enabled and disabled states.
@MainActor
final class ButtonsViewController: UIViewController {
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Buttons"
        view.backgroundColor = Still.background

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = StillSpace.s4
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        statusLabel.text = "Tap any enabled button."
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = Still.labelSecondary
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.adjustsFontForContentSizeCategory = true

        stack.addArrangedSubview(makeHeading("Enabled"))
        stack.addArrangedSubview(makeButton(.stillPrimary("Primary action"), name: "Primary"))
        stack.addArrangedSubview(makeButton(.stillSecondary("Secondary action"), name: "Secondary"))
        stack.addArrangedSubview(makeButton(.stillPlain("Plain action"), name: "Plain"))
        stack.addArrangedSubview(statusLabel)

        stack.addArrangedSubview(makeHeading("Disabled"))
        stack.addArrangedSubview(makeButton(.stillPrimary("Primary disabled"), name: nil, enabled: false))
        stack.addArrangedSubview(makeButton(.stillSecondary("Secondary disabled"), name: nil, enabled: false))
        stack.addArrangedSubview(makeButton(.stillPlain("Plain disabled"), name: nil, enabled: false))

        let guide = scrollView.contentLayoutGuide
        let readable = view.readableContentGuide
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: StillSpace.s6),
            stack.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -StillSpace.s6),
            stack.leadingAnchor.constraint(equalTo: readable.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: readable.trailingAnchor),
        ])
    }

    private func makeHeading(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = StillFont.rounded(.title3)
        label.textColor = Still.label
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func makeButton(_ config: UIButton.Configuration, name: String?, enabled: Bool = true) -> UIButton {
        let button = UIButton(configuration: config)
        button.isEnabled = enabled
        if let name {
            button.addAction(UIAction { [weak self] _ in
                StillHaptics.touch(0.55)
                self?.statusLabel.text = "\(name) tapped."
            }, for: .primaryActionTriggered)
        }
        return button
    }
}
