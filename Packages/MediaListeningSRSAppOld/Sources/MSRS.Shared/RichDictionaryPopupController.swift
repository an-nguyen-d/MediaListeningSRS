import UIKit
import IYO_DictionaryUIKit

/// Drives iYomi's rich `DictionaryPopupPresenter` and pairs it with a Mark-as-Known button
/// inside the popup, positioning everything relative to the word the user tapped.
@MainActor
public final class RichDictionaryPopupController {

  private weak var hostView: UIView?
  private let presenter: DictionaryPopupPresenter
  private let configuration: DictionaryPopupConfiguration

  private var onMarkAsKnownTapped: (() -> Void)?
  private var onDismiss: (() -> Void)?

  public init(hostView: UIView) {
    self.hostView = hostView

    let config = DictionaryPopupConfiguration()
    config.buttons.addExactMatchWord = false
    config.buttons.setWord = false
    config.buttons.copyID = false
    config.buttons.copyWord = false
    self.configuration = config

    self.presenter = DictionaryPopupPresenter(containerView: hostView, configuration: config)

    presenter.didDismiss = { [weak self] in
      self?.onDismiss?()
    }
  }

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

    presenter.didTapMarkAsKnownButton = { [weak self] in
      self?.onMarkAsKnownTapped?()
    }

    presenter.configurePopup(
      with: viewModel,
      showDeleteButton: false,
      showMarkAsKnownButton: true,
      isAlreadyKnown: isAlreadyKnown
    )
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
      showDeleteButton: false,
      showMarkAsKnownButton: true,
      isAlreadyKnown: isAlreadyKnown
    )
  }

  public func dismiss() {
    presenter.dismiss()
  }
}
