import UIKit
import StillKit

/// Displays continuous corner radii (`StillRadius`), counter pebbles and the spacing scale (`StillSpace`).
@MainActor
final class ShapeSpaceViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shape & spacing"
        view.backgroundColor = Still.groupedBackground

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = StillSpace.s6
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        // Radii
        stack.addArrangedSubview(makeHeading("Continuous corners (StillRadius)"))
        let radii: [(String, CGFloat)] = [
            ("sm (8pt)", StillRadius.sm),
            ("md (12pt)", StillRadius.md),
            ("lg (20pt)", StillRadius.lg),
            ("xl (32pt)", StillRadius.xl),
        ]
        for (name, radius) in radii {
            let card = UIView()
            card.backgroundColor = Still.groupedSurface
            card.stillCorners(radius)
            let label = UILabel()
            label.text = name
            label.font = StillFont.rounded(.headline)
            label.textColor = Still.label
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
            label.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: StillSpace.s5),
                label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -StillSpace.s5),
                label.topAnchor.constraint(equalTo: card.topAnchor, constant: StillSpace.s5),
                label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -StillSpace.s5),
            ])
            stack.addArrangedSubview(card)
        }

        // Counter pebbles
        stack.addArrangedSubview(makeHeading("Counter pebbles"))
        let pebbleRow = UIStackView()
        pebbleRow.axis = .vertical
        pebbleRow.spacing = StillSpace.s3
        pebbleRow.addArrangedSubview(makeCounterPebble(label: "Best", value: "128",
                                                       ground: Still.backgroundSecondary,
                                                       labelColor: Still.labelSecondary,
                                                       valueColor: Still.label))
        pebbleRow.addArrangedSubview(makeCounterPebble(label: "New best", value: "144",
                                                       ground: Still.tintSoft,
                                                       labelColor: Still.onTintSoft,
                                                       valueColor: Still.onTintSoft))
        pebbleRow.addArrangedSubview(makeCounterPebble(label: "Combo", value: "3x",
                                                       ground: Still.tint,
                                                       labelColor: Still.onTint,
                                                       valueColor: Still.onTint))
        stack.addArrangedSubview(pebbleRow)

        // Spacing scale
        stack.addArrangedSubview(makeHeading("Spacing rhythm (StillSpace)"))
        let spaces: [(String, CGFloat)] = [
            ("s1", StillSpace.s1),
            ("s2", StillSpace.s2),
            ("s3", StillSpace.s3),
            ("s4", StillSpace.s4),
            ("s5", StillSpace.s5),
            ("s6", StillSpace.s6),
            ("s8", StillSpace.s8),
            ("s12", StillSpace.s12),
        ]
        let spaceCard = UIView()
        spaceCard.backgroundColor = Still.groupedSurface
        spaceCard.stillCorners(StillRadius.lg)
        let spaceStack = UIStackView()
        spaceStack.axis = .vertical
        spaceStack.spacing = StillSpace.s3
        spaceStack.translatesAutoresizingMaskIntoConstraints = false
        spaceCard.addSubview(spaceStack)
        NSLayoutConstraint.activate([
            spaceStack.leadingAnchor.constraint(equalTo: spaceCard.leadingAnchor, constant: StillSpace.s4),
            spaceStack.trailingAnchor.constraint(equalTo: spaceCard.trailingAnchor, constant: -StillSpace.s4),
            spaceStack.topAnchor.constraint(equalTo: spaceCard.topAnchor, constant: StillSpace.s4),
            spaceStack.bottomAnchor.constraint(equalTo: spaceCard.bottomAnchor, constant: -StillSpace.s4),
        ])
        for (name, value) in spaces {
            spaceStack.addArrangedSubview(makeSpaceRow(name: name, value: value))
        }
        stack.addArrangedSubview(spaceCard)

        let guide = scrollView.contentLayoutGuide
        let readable = view.readableContentGuide
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: StillSpace.s5),
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

    private func makeCounterPebble(label title: String, value: String, ground: UIColor,
                                   labelColor: UIColor, valueColor: UIColor) -> UIView {
        let pebble = CapsuleView()
        pebble.backgroundColor = ground

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.textColor = labelColor
        titleLabel.adjustsFontForContentSizeCategory = true

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = StillFont.rounded(.title3, weight: .medium)
        valueLabel.textColor = valueColor
        valueLabel.adjustsFontForContentSizeCategory = true

        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        row.axis = .horizontal
        row.spacing = StillSpace.s3
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        pebble.addSubview(row)

        NSLayoutConstraint.activate([
            pebble.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            row.leadingAnchor.constraint(equalTo: pebble.leadingAnchor, constant: StillSpace.s5),
            row.trailingAnchor.constraint(equalTo: pebble.trailingAnchor, constant: -StillSpace.s5),
            row.topAnchor.constraint(equalTo: pebble.topAnchor, constant: StillSpace.s2),
            row.bottomAnchor.constraint(equalTo: pebble.bottomAnchor, constant: -StillSpace.s2),
        ])
        return pebble
    }

    private func makeSpaceRow(name: String, value: CGFloat) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = StillSpace.s3
        row.alignment = .center

        let label = UILabel()
        label.text = "\(name) (\(Int(value))pt)"
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = Still.label
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.required, for: .horizontal)

        let bar = UIView()
        bar.backgroundColor = Still.tint
        bar.stillCorners(StillRadius.sm / 2)
        bar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.widthAnchor.constraint(equalToConstant: value * 3),
            bar.heightAnchor.constraint(equalToConstant: 12),
        ])

        let spacer = UIView()
        row.addArrangedSubview(label)
        row.addArrangedSubview(bar)
        row.addArrangedSubview(spacer)
        return row
    }
}

@MainActor
private final class CapsuleView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        stillCorners(min(bounds.height / 2, StillRadius.xl))
    }
}
