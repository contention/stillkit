//  StillPromise.swift
//  The series' signature screen: the same sheet, the same words, in every app.
//
//  Usage, from an "About Still" row or an info button:
//      StillPromise.present(from: self,
//                           moreFromStillURL: URL(string: "https://apps.apple.com/developer/idXXXXXXXX"))

import UIKit

public enum StillPromise {
    @MainActor
    public static func present(from presenter: UIViewController,
                               moreFromStillURL: URL? = nil) {
        let controller = StillPromiseViewController(moreFromStillURL: moreFromStillURL)
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        presenter.present(controller, animated: true)
    }
}

public final class StillPromiseViewController: UIViewController {
    private let moreURL: URL?

    public init(moreFromStillURL: URL? = nil) {
        self.moreURL = moreFromStillURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Still.groupedSurface

        let title = makeLabel("A small promise",
                              font: StillFont.rounded(.title1),
                              color: Still.label)
        title.accessibilityTraits = .header

        let intro = makeLabel("This app is part of Still, a series of small, quiet things for your phone.",
                              font: .preferredFont(forTextStyle: .subheadline),
                              color: Still.labelSecondary)

        let promises = ["Free", "No ads", "No tracking", "No account"].map(makePromiseRow)

        let ever = makeLabel("Ever.",
                             font: StillFont.rounded(.title2, weight: .medium),
                             color: Still.label)

        var rows: [UIView] = [title, intro]
        rows += promises
        rows.append(ever)

        if let url = moreURL {
            let more = UIButton(configuration: .stillSecondary("More from Still"),
                                primaryAction: UIAction { _ in
                                    UIApplication.shared.open(url)
                                })
            rows.append(more)
        }

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = StillSpace.s3
        stack.setCustomSpacing(StillSpace.s1, after: title)
        stack.setCustomSpacing(StillSpace.s5, after: intro)
        if let lastPromise = promises.last {
            stack.setCustomSpacing(StillSpace.s5, after: lastPromise)
        }
        stack.setCustomSpacing(StillSpace.s6, after: ever)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: StillSpace.s8),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -StillSpace.s6),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: StillSpace.s6),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -StillSpace.s6)
        ])
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func makePromiseRow(_ text: String) -> UIView {
        let pebble = UIView()
        pebble.backgroundColor = Still.tint
        pebble.stillCorners(5)
        pebble.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pebble.widthAnchor.constraint(equalToConstant: 20),
            pebble.heightAnchor.constraint(equalToConstant: 10)
        ])

        let label = makeLabel(text, font: .preferredFont(forTextStyle: .body), color: Still.label)

        let row = UIStackView(arrangedSubviews: [pebble, label])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = StillSpace.s3
        return row
    }
}
