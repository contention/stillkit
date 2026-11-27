import UIKit
import StillKit

/// Shared layout and label helpers used across the StillShowcase catalogue screens.
@MainActor
enum ShowcaseUI {
    /// Installs a full-screen `UIScrollView` containing a vertical `UIStackView` aligned
    /// to `view.readableContentGuide`.
    static func installScrollableStack(
        in view: UIView,
        spacing: CGFloat = StillSpace.s4,
        topPadding: CGFloat = StillSpace.s5
    ) -> UIStackView {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let guide = scrollView.contentLayoutGuide
        let readable = view.readableContentGuide
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: topPadding),
            stack.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -StillSpace.s6),
            stack.leadingAnchor.constraint(equalTo: readable.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: readable.trailingAnchor),
        ])
        return stack
    }

    /// Installs a full-screen inset-grouped `UICollectionView` on `Still.groupedBackground`.
    static func installGroupedCollectionView(
        in view: UIView,
        layout: UICollectionViewLayout,
        dataSource: UICollectionViewDataSource,
        delegate: UICollectionViewDelegate? = nil,
        allowsSelection: Bool = true
    ) -> UICollectionView {
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = Still.groupedBackground
        collectionView.allowsSelection = allowsSelection
        collectionView.dataSource = dataSource
        collectionView.delegate = delegate
        view.addSubview(collectionView)
        return collectionView
    }

    static func makeHeading(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = StillFont.rounded(.title3)
        label.textColor = Still.label
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    static func makeNote(_ text: String, alignment: NSTextAlignment = .natural) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = Still.labelSecondary
        label.textAlignment = alignment
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}
