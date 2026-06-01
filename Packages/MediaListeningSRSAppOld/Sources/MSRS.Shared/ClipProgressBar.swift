import UIKit

public final class ClipProgressBar: UIView {

  private let trackView = UIView()
  private let fillView = UIView()
  private var fillWidthConstraint: NSLayoutConstraint!

  public override init(frame: CGRect) {
    super.init(frame: frame)
    translatesAutoresizingMaskIntoConstraints = false

    trackView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
    trackView.layer.cornerRadius = 3
    trackView.clipsToBounds = true
    trackView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(trackView)

    fillView.backgroundColor = .white
    fillView.translatesAutoresizingMaskIntoConstraints = false
    trackView.addSubview(fillView)

    fillWidthConstraint = fillView.widthAnchor.constraint(equalToConstant: 0)

    NSLayoutConstraint.activate([
      heightAnchor.constraint(equalToConstant: 6),

      trackView.topAnchor.constraint(equalTo: topAnchor),
      trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
      trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
      trackView.bottomAnchor.constraint(equalTo: bottomAnchor),

      fillView.topAnchor.constraint(equalTo: trackView.topAnchor),
      fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
      fillView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
      fillWidthConstraint,
    ])
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) { fatalError() }

  public override func layoutSubviews() {
    super.layoutSubviews()
    updateFillWidth()
  }

  private var progress: Double = 0

  public func setProgress(_ value: Double) {
    progress = max(0, min(1, value))
    updateFillWidth()
  }

  public func reset() {
    progress = 0
    updateFillWidth()
  }

  private func updateFillWidth() {
    fillWidthConstraint.constant = trackView.bounds.width * progress
  }
}
