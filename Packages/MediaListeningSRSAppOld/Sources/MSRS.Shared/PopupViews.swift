import UIKit

// MARK: - PopupOverlayView

public final class PopupOverlayView: UIView {

  public var onDismiss: (() -> Void)?

  private weak var contentView: UIView?

  /// Adds an overlay over `hostView`, centers `content`. Tap outside `content` dismisses.
  @discardableResult
  public static func present(
    content: UIView,
    in hostView: UIView,
    onDismiss: (() -> Void)? = nil
  ) -> PopupOverlayView {
    let overlay = PopupOverlayView(frame: hostView.bounds)
    overlay.contentView = content
    overlay.onDismiss = onDismiss
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)

    overlay.addSubview(content)
    content.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      content.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      content.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
      content.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 24),
      content.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -24),
      content.topAnchor.constraint(greaterThanOrEqualTo: overlay.topAnchor, constant: 24),
      content.bottomAnchor.constraint(lessThanOrEqualTo: overlay.bottomAnchor, constant: -24),
    ])

    let tap = UITapGestureRecognizer(target: overlay, action: #selector(handleBackdropTap(_:)))
    tap.cancelsTouchesInView = false
    overlay.addGestureRecognizer(tap)

    hostView.addSubview(overlay)
    return overlay
  }

  public func dismiss() {
    let cb = onDismiss
    onDismiss = nil
    removeFromSuperview()
    cb?()
  }

  @objc private func handleBackdropTap(_ gesture: UITapGestureRecognizer) {
    guard let contentView = self.contentView else { return }
    let pointInOverlay = gesture.location(in: self)
    let pointInContent = convert(pointInOverlay, to: contentView)
    if !contentView.bounds.contains(pointInContent) {
      dismiss()
    }
  }
}

// MARK: - ConfirmationPopupContentView

public final class ConfirmationPopupContentView: UIView {

  public var onConfirm: (() -> Void)?

  public init(message: String, hint: String, accentColor: UIColor) {
    super.init(frame: .zero)
    backgroundColor = accentColor
    layer.cornerRadius = 14
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.3
    layer.shadowOffset = .init(width: 0, height: 6)
    layer.shadowRadius = 16

    let messageLabel = UILabel()
    messageLabel.text = message
    messageLabel.font = .systemFont(ofSize: 30, weight: .bold)
    messageLabel.textColor = .white
    messageLabel.numberOfLines = 0
    messageLabel.textAlignment = .center

    let hintLabel = UILabel()
    hintLabel.text = hint
    hintLabel.font = .systemFont(ofSize: 16, weight: .medium)
    hintLabel.textColor = UIColor.white.withAlphaComponent(0.85)
    hintLabel.textAlignment = .center
    hintLabel.numberOfLines = 0

    let stack = UIStackView(arrangedSubviews: [messageLabel, hintLabel])
    stack.axis = .vertical
    stack.spacing = 20
    addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 48),
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 48),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -48),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -48),
      widthAnchor.constraint(equalToConstant: 560),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 240),
    ])

    let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    addGestureRecognizer(tap)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc private func handleTap() {
    onConfirm?()
  }
}
