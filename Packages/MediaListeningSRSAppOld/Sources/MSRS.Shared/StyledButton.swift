import UIKit

public extension UIButton {

  /// Filled button with a background color, optional `(hotkey)` subtitle, and rounded corners.
  /// Hugs and resists compression at the highest priority so it stays at its intrinsic width
  /// inside `UIStackView`s with `.fill` distribution.
  static func makeStyled(
    title: String,
    hotkey: String? = nil,
    backgroundColor: UIColor,
    foregroundColor: UIColor = .white
  ) -> UIButton {
    let button = UIButton(type: .system)
    var config = UIButton.Configuration.filled()
    config.title = title
    if let hotkey = hotkey {
      config.subtitle = "(\(hotkey))"
    }
    config.baseBackgroundColor = backgroundColor
    config.baseForegroundColor = foregroundColor
    config.cornerStyle = .medium
    config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
    config.titleAlignment = .center
    button.configuration = config
    button.setContentHuggingPriority(.required, for: .horizontal)
    button.setContentCompressionResistancePriority(.required, for: .horizontal)
    return button
  }
}

public extension UIStackView {

  /// Horizontal row that left-aligns `children` with constant `spacing` and pushes any extra
  /// width into a trailing flexible spacer. Place this inside a full-width parent without worrying
  /// about it stretching its buttons.
  static func leadingPinnedRow(
    children: [UIView],
    spacing: CGFloat = 12,
    alignment: UIStackView.Alignment = .center
  ) -> UIStackView {
    let spacer = UIView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    let stack = UIStackView(arrangedSubviews: children + [spacer])
    stack.axis = .horizontal
    stack.spacing = spacing
    stack.alignment = alignment
    stack.distribution = .fill
    return stack
  }
}
