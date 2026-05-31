import UIKit
import IYO_DictionaryUIKit

/// Drives iYomi's rich `DictionaryPopupPresenter` and pairs it with a Mark-as-Known pill,
/// positioning everything relative to the word the user tapped.
@MainActor
public final class RichDictionaryPopupController {

  private weak var hostView: UIView?
  private let presenter: DictionaryPopupPresenter
  private let markAsKnownButton: UIButton
  private let configuration: DictionaryPopupConfiguration

  private var onMarkAsKnownTapped: (() -> Void)?
  private var onDismiss: (() -> Void)?

  public init(hostView: UIView) {
    self.hostView = hostView

    // We don't use iYomi's "set word / add exact match / copy ID / copy word" actions in MSRS —
    // they belong to the MWBT tagging UI. Hide them so the popup is read-only dictionary info.
    let config = DictionaryPopupConfiguration()
    config.buttons.addExactMatchWord = false
    config.buttons.setWord = false
    config.buttons.copyID = false
    config.buttons.copyWord = false
    self.configuration = config

    self.presenter = DictionaryPopupPresenter(containerView: hostView, configuration: config)

    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.layer.cornerRadius = 16
    button.layer.masksToBounds = true
    button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
    button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
    self.markAsKnownButton = button

    button.addTarget(self, action: #selector(handleMarkAsKnownTapped), for: .touchUpInside)

    presenter.didDismiss = { [weak self] in
      self?.cleanUpMarkAsKnownButton()
      self?.onDismiss?()
    }
  }

  /// Shows the rich popup populated from `viewModel`, positioned around `tappedWordFrame`
  /// (in the host view's coordinate space). The Mark-as-Known pill renders next to the popup
  /// — its label flips to "✓ Known" when `isAlreadyKnown` is true.
  public func show(
    viewModel: DictionaryLookupViewModel,
    tappedWordFrame: CGRect,
    isAlreadyKnown: Bool,
    onMarkAsKnownTapped: @escaping () -> Void,
    onDismiss: @escaping () -> Void
  ) {
    guard let hostView = hostView else { return }
    self.onMarkAsKnownTapped = onMarkAsKnownTapped
    self.onDismiss = onDismiss

    configureMarkAsKnownButton(isAlreadyKnown: isAlreadyKnown)

    presenter.configurePopup(with: viewModel, showDeleteButton: false)
    let popupSize = presenter.measureContentSize()

    let positionerOutput = PopupPositioner.calculatePosition(input: .init(
      popupSize: popupSize,
      canvasSize: hostView.bounds.size,
      avoidFrames: [tappedWordFrame],
      preferredPoint: CGPoint(x: tappedWordFrame.midX, y: tappedWordFrame.midY),
      avoidPadding: configuration.sizing.popupAvoidPadding,
      edgeInsets: configuration.sizing.popupEdgeInsets
    ))

    presenter.show(
      viewModel: viewModel,
      frame: positionerOutput.frame,
      showDeleteButton: false
    )

    layoutMarkAsKnownButton(relativeTo: positionerOutput.frame, in: hostView)
  }

  public func dismiss() {
    presenter.dismiss()
  }

  // MARK: - Mark-as-Known pill

  private func configureMarkAsKnownButton(isAlreadyKnown: Bool) {
    if isAlreadyKnown {
      markAsKnownButton.setTitle("✓ Known", for: .normal)
      markAsKnownButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.85)
      markAsKnownButton.setTitleColor(.white, for: .normal)
      markAsKnownButton.isEnabled = false
    } else {
      markAsKnownButton.setTitle("Mark as Known", for: .normal)
      markAsKnownButton.backgroundColor = UIColor.systemGreen
      markAsKnownButton.setTitleColor(.white, for: .normal)
      markAsKnownButton.isEnabled = true
    }
  }

  private func layoutMarkAsKnownButton(relativeTo popupFrame: CGRect, in hostView: UIView) {
    markAsKnownButton.removeFromSuperview()
    hostView.addSubview(markAsKnownButton)

    // Compute size from intrinsic title + insets.
    markAsKnownButton.sizeToFit()
    let buttonSize = CGSize(
      width: max(markAsKnownButton.bounds.width, 140),
      height: 32
    )
    let spacing: CGFloat = 8

    // Prefer placing the pill above the popup; if no space, place below.
    let aboveY = popupFrame.minY - buttonSize.height - spacing
    let belowY = popupFrame.maxY + spacing
    let yPosition: CGFloat = (aboveY >= configuration.sizing.popupEdgeInsets.top)
      ? aboveY
      : belowY

    var xPosition = popupFrame.minX
    let maxX = hostView.bounds.width - buttonSize.width - configuration.sizing.popupEdgeInsets.right
    xPosition = max(configuration.sizing.popupEdgeInsets.left, min(xPosition, maxX))

    markAsKnownButton.frame = CGRect(
      origin: CGPoint(x: xPosition, y: yPosition),
      size: buttonSize
    )
  }

  private func cleanUpMarkAsKnownButton() {
    markAsKnownButton.removeFromSuperview()
  }

  @objc private func handleMarkAsKnownTapped() {
    onMarkAsKnownTapped?()
    presenter.dismiss()
  }
}
