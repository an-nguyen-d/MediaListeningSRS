import UIKit

final class CreateAllProgressView: UIView {

  private let titleLabel = UILabel()
  private let progressLabel = UILabel()
  private let progressBar = UIProgressView(progressViewStyle: .default)
  private let dismissButton = UIButton(type: .system)
  private var onDismiss: (() -> Void)?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    layer.cornerRadius = 14
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.3
    layer.shadowOffset = .init(width: 0, height: 6)
    layer.shadowRadius = 16

    titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
    titleLabel.textColor = .label
    titleLabel.textAlignment = .center
    titleLabel.text = "Creating Cards…"

    progressLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
    progressLabel.textColor = .secondaryLabel
    progressLabel.textAlignment = .center

    progressBar.progressTintColor = .systemGreen
    progressBar.trackTintColor = .systemGray5

    var config = UIButton.Configuration.filled()
    config.title = "Done"
    config.baseBackgroundColor = .systemGreen
    config.baseForegroundColor = .white
    config.buttonSize = .large
    config.cornerStyle = .medium
    dismissButton.configuration = config
    dismissButton.isHidden = true
    dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

    let stack = UIStackView(arrangedSubviews: [titleLabel, progressBar, progressLabel, dismissButton])
    stack.axis = .vertical
    stack.spacing = 20
    stack.alignment = .fill
    addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 40),
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -40),
      widthAnchor.constraint(equalToConstant: 440),
      progressBar.heightAnchor.constraint(equalToConstant: 8),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func update(completed: Int, total: Int) {
    progressLabel.text = "\(completed) / \(total)"
    let fraction = total > 0 ? Float(completed) / Float(total) : 0
    progressBar.setProgress(fraction, animated: completed > 0)
  }

  func showCompleted(created: Int, errors: Int, onDismiss: @escaping () -> Void) {
    self.onDismiss = onDismiss
    titleLabel.text = "Complete"
    progressBar.setProgress(1.0, animated: true)
    if errors > 0 {
      progressLabel.text = "\(created) created, \(errors) failed"
    } else {
      progressLabel.text = "\(created) cards created"
    }
    dismissButton.isHidden = false
  }

  @objc private func dismissTapped() {
    onDismiss?()
  }
}
