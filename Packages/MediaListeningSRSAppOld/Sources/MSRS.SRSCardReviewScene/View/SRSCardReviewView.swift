import UIKit
import AVFoundation
import MSRS_Shared

final class SRSCardReviewView: UIView {

  var onReplayTapped: (() -> Void)?
  var onRevealBackTapped: (() -> Void)?
  var onGraded: ((SRSCardReviewModels.Grade) -> Void)?
  var onTermTapped: ((Int64) -> Void)?

  private static let loopGapSeconds: TimeInterval = 0.5

  private enum FrontVideoVisibility {
    case blackThumbnail
    case blurredVideo
    case clearVideo
  }

  // MARK: - Common (used on both sides)

  private let positionLabel = UILabel()
  private let videoStageView = UIView()
  private let playerView = PlayerLayerView()
  private let blurOverlayView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
  private let blackMaskView = UIView()

  // MARK: - Front

  private let frontContainer = UIView()
  private let frontVideoTapView = UIView()
  private let frontTranscriptRevealContainer = UIView()
  private let frontTranscriptRevealHint = UILabel()
  private let frontTranscriptLabel = UILabel()
  private let frontReplayButton = UIButton(type: .system)
  private let frontRevealBackButton = UIButton(type: .system)

  // MARK: - Back

  private let backContainer = UIView()
  private let backTranscriptView = HighlightableTranscriptView()
  private let backTranslationLabel = UILabel()
  private let backFailButton = UIButton(type: .system)
  private let backPassButton = UIButton(type: .system)

  // MARK: - Other

  private let emptyLabel = UILabel()

  // MARK: - State

  private var frontVideoVisibility: FrontVideoVisibility = .blackThumbnail
  private var isShowingBack = false
  private var isFrontTranscriptRevealed = false

  private var player: AVPlayer?
  private var currentClipStartTime: TimeInterval = 0
  private var currentClipEndTime: TimeInterval = 0
  private var loopObserver: Any?
  private var pendingLoopRestartTask: Task<Void, Never>?
  private var isLooping = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    setUpPositionLabel()
    setUpVideoStage()
    setUpFront()
    setUpBack()
    setUpEmptyLabel()
    setUpLayout()
    showEmptyState(message: "Loading deck…")
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError()
  }

  deinit {
    pendingLoopRestartTask?.cancel()
  }

  // MARK: - Setup

  private func setUpPositionLabel() {
    positionLabel.font = .preferredFont(forTextStyle: .footnote)
    positionLabel.textColor = .secondaryLabel
    positionLabel.textAlignment = .center
    addSubview(positionLabel)
    positionLabel.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpVideoStage() {
    videoStageView.backgroundColor = .black
    videoStageView.translatesAutoresizingMaskIntoConstraints = false

    playerView.translatesAutoresizingMaskIntoConstraints = false
    videoStageView.addSubview(playerView)

    blurOverlayView.translatesAutoresizingMaskIntoConstraints = false
    videoStageView.addSubview(blurOverlayView)

    blackMaskView.backgroundColor = .black
    blackMaskView.translatesAutoresizingMaskIntoConstraints = false
    videoStageView.addSubview(blackMaskView)

    NSLayoutConstraint.activate([
      playerView.topAnchor.constraint(equalTo: videoStageView.topAnchor),
      playerView.leadingAnchor.constraint(equalTo: videoStageView.leadingAnchor),
      playerView.trailingAnchor.constraint(equalTo: videoStageView.trailingAnchor),
      playerView.bottomAnchor.constraint(equalTo: videoStageView.bottomAnchor),

      blurOverlayView.topAnchor.constraint(equalTo: videoStageView.topAnchor),
      blurOverlayView.leadingAnchor.constraint(equalTo: videoStageView.leadingAnchor),
      blurOverlayView.trailingAnchor.constraint(equalTo: videoStageView.trailingAnchor),
      blurOverlayView.bottomAnchor.constraint(equalTo: videoStageView.bottomAnchor),

      blackMaskView.topAnchor.constraint(equalTo: videoStageView.topAnchor),
      blackMaskView.leadingAnchor.constraint(equalTo: videoStageView.leadingAnchor),
      blackMaskView.trailingAnchor.constraint(equalTo: videoStageView.trailingAnchor),
      blackMaskView.bottomAnchor.constraint(equalTo: videoStageView.bottomAnchor),

      videoStageView.heightAnchor.constraint(equalToConstant: 360),
    ])
  }

  private func setUpFront() {
    frontContainer.translatesAutoresizingMaskIntoConstraints = false

    frontVideoTapView.translatesAutoresizingMaskIntoConstraints = false
    frontVideoTapView.backgroundColor = .clear
    let tap = UITapGestureRecognizer(target: self, action: #selector(handleFrontVideoTap))
    frontVideoTapView.addGestureRecognizer(tap)

    frontTranscriptRevealContainer.translatesAutoresizingMaskIntoConstraints = false
    frontTranscriptRevealContainer.backgroundColor = .secondarySystemBackground
    frontTranscriptRevealContainer.layer.cornerRadius = 10
    let revealTap = UITapGestureRecognizer(target: self, action: #selector(handleFrontTranscriptRevealTap))
    frontTranscriptRevealContainer.addGestureRecognizer(revealTap)

    frontTranscriptRevealHint.text = "Tap to reveal Japanese transcript"
    frontTranscriptRevealHint.font = .systemFont(ofSize: 18, weight: .medium)
    frontTranscriptRevealHint.textColor = .secondaryLabel
    frontTranscriptRevealHint.textAlignment = .center
    frontTranscriptRevealHint.translatesAutoresizingMaskIntoConstraints = false
    frontTranscriptRevealContainer.addSubview(frontTranscriptRevealHint)

    frontTranscriptLabel.font = .systemFont(ofSize: 28, weight: .regular)
    frontTranscriptLabel.numberOfLines = 0
    frontTranscriptLabel.textAlignment = .center
    frontTranscriptLabel.isHidden = true
    frontTranscriptLabel.translatesAutoresizingMaskIntoConstraints = false
    frontTranscriptRevealContainer.addSubview(frontTranscriptLabel)

    Self.styleAction(frontReplayButton, title: "Replay", hotkey: "R", backgroundColor: .systemBlue)
    frontReplayButton.addTarget(self, action: #selector(handleFrontReplayTap), for: .touchUpInside)

    Self.styleAction(frontRevealBackButton, title: "Reveal Back", hotkey: "Space", backgroundColor: .systemIndigo)
    frontRevealBackButton.addTarget(self, action: #selector(handleFrontRevealBackTap), for: .touchUpInside)

    NSLayoutConstraint.activate([
      frontTranscriptRevealContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),

      frontTranscriptRevealHint.centerXAnchor.constraint(equalTo: frontTranscriptRevealContainer.centerXAnchor),
      frontTranscriptRevealHint.centerYAnchor.constraint(equalTo: frontTranscriptRevealContainer.centerYAnchor),
      frontTranscriptRevealHint.leadingAnchor.constraint(greaterThanOrEqualTo: frontTranscriptRevealContainer.leadingAnchor, constant: 16),
      frontTranscriptRevealHint.trailingAnchor.constraint(lessThanOrEqualTo: frontTranscriptRevealContainer.trailingAnchor, constant: -16),

      frontTranscriptLabel.topAnchor.constraint(equalTo: frontTranscriptRevealContainer.topAnchor, constant: 16),
      frontTranscriptLabel.leadingAnchor.constraint(equalTo: frontTranscriptRevealContainer.leadingAnchor, constant: 16),
      frontTranscriptLabel.trailingAnchor.constraint(equalTo: frontTranscriptRevealContainer.trailingAnchor, constant: -16),
      frontTranscriptLabel.bottomAnchor.constraint(equalTo: frontTranscriptRevealContainer.bottomAnchor, constant: -16),
    ])
  }

  private func setUpBack() {
    backContainer.translatesAutoresizingMaskIntoConstraints = false

    backTranscriptView.transcriptFont = .systemFont(ofSize: 56, weight: .regular)
    backTranscriptView.onTermTapped = { [weak self] termID in
      self?.onTermTapped?(termID)
    }
    backTranscriptView.translatesAutoresizingMaskIntoConstraints = false

    backTranslationLabel.font = .preferredFont(forTextStyle: .title3)
    backTranslationLabel.textColor = .secondaryLabel
    backTranslationLabel.numberOfLines = 0
    backTranslationLabel.translatesAutoresizingMaskIntoConstraints = false

    Self.styleAction(backFailButton, title: "Fail", hotkey: "1", backgroundColor: .systemRed)
    backFailButton.addTarget(self, action: #selector(handleFailTap), for: .touchUpInside)
    Self.styleAction(backPassButton, title: "Pass", hotkey: "2", backgroundColor: .systemGreen)
    backPassButton.addTarget(self, action: #selector(handlePassTap), for: .touchUpInside)
  }

  private func setUpEmptyLabel() {
    emptyLabel.font = .preferredFont(forTextStyle: .title2)
    emptyLabel.textColor = .secondaryLabel
    emptyLabel.textAlignment = .center
    emptyLabel.numberOfLines = 0
    emptyLabel.isHidden = true
    addSubview(emptyLabel)
    emptyLabel.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpLayout() {
    addSubview(videoStageView)
    addSubview(frontContainer)
    addSubview(backContainer)

    frontContainer.addSubview(frontVideoTapView)
    frontContainer.addSubview(frontTranscriptRevealContainer)

    let frontButtonsRow = UIStackView.leadingPinnedRow(
      children: [frontReplayButton, frontRevealBackButton],
      spacing: 16
    )
    frontButtonsRow.translatesAutoresizingMaskIntoConstraints = false
    frontContainer.addSubview(frontButtonsRow)

    let backButtonsRow = UIStackView.leadingPinnedRow(
      children: [backFailButton, backPassButton],
      spacing: 16
    )
    backButtonsRow.translatesAutoresizingMaskIntoConstraints = false
    backContainer.addSubview(backTranscriptView)
    backContainer.addSubview(backTranslationLabel)
    backContainer.addSubview(backButtonsRow)

    NSLayoutConstraint.activate([
      positionLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
      positionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      positionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

      videoStageView.topAnchor.constraint(equalTo: positionLabel.bottomAnchor, constant: 16),
      videoStageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
      videoStageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

      frontContainer.topAnchor.constraint(equalTo: videoStageView.bottomAnchor, constant: 16),
      frontContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
      frontContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
      frontContainer.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),

      frontVideoTapView.topAnchor.constraint(equalTo: frontContainer.topAnchor),
      frontVideoTapView.leadingAnchor.constraint(equalTo: frontContainer.leadingAnchor),
      frontVideoTapView.trailingAnchor.constraint(equalTo: frontContainer.trailingAnchor),
      frontVideoTapView.heightAnchor.constraint(equalToConstant: 1),

      frontTranscriptRevealContainer.topAnchor.constraint(equalTo: frontVideoTapView.bottomAnchor, constant: 12),
      frontTranscriptRevealContainer.leadingAnchor.constraint(equalTo: frontContainer.leadingAnchor),
      frontTranscriptRevealContainer.trailingAnchor.constraint(equalTo: frontContainer.trailingAnchor),

      frontButtonsRow.topAnchor.constraint(equalTo: frontTranscriptRevealContainer.bottomAnchor, constant: 24),
      frontButtonsRow.leadingAnchor.constraint(equalTo: frontContainer.leadingAnchor),
      frontButtonsRow.bottomAnchor.constraint(equalTo: frontContainer.bottomAnchor),

      backContainer.topAnchor.constraint(equalTo: videoStageView.bottomAnchor, constant: 16),
      backContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
      backContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
      backContainer.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),

      backTranscriptView.topAnchor.constraint(equalTo: backContainer.topAnchor),
      backTranscriptView.leadingAnchor.constraint(equalTo: backContainer.leadingAnchor),
      backTranscriptView.trailingAnchor.constraint(equalTo: backContainer.trailingAnchor),

      backTranslationLabel.topAnchor.constraint(equalTo: backTranscriptView.bottomAnchor, constant: 12),
      backTranslationLabel.leadingAnchor.constraint(equalTo: backContainer.leadingAnchor),
      backTranslationLabel.trailingAnchor.constraint(equalTo: backContainer.trailingAnchor),

      backButtonsRow.topAnchor.constraint(equalTo: backTranslationLabel.bottomAnchor, constant: 24),
      backButtonsRow.leadingAnchor.constraint(equalTo: backContainer.leadingAnchor),
      backButtonsRow.bottomAnchor.constraint(equalTo: backContainer.bottomAnchor),

      emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
      emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
      emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
    ])
  }

  // MARK: - Public API

  var isShowingBackSide: Bool { isShowingBack }

  func boundingFrameForTermID(_ termID: Int64, in containerView: UIView) -> CGRect? {
    backTranscriptView.boundingFrameForTermID(termID, in: containerView)
  }

  func setSelectedTermID(_ termID: Int64?) {
    backTranscriptView.selectedTermID = termID
  }

  func setCard(_ viewModel: SRSCardReviewModels.CardViewModel) {
    emptyLabel.isHidden = true
    positionLabel.text = viewModel.cardPositionLabel
    videoStageView.isHidden = false

    backTranscriptView.setTranscript(
      text: viewModel.transcriptText,
      labeledRanges: viewModel.transcriptLabeledRanges
    )
    backTranslationLabel.text = viewModel.englishTranslationText ?? "(no translation)"
    frontTranscriptLabel.text = viewModel.transcriptText

    stopLoop()

    let asset = AVURLAsset(url: viewModel.videoFileURL)
    let item = AVPlayerItem(asset: asset)
    let newPlayer = AVPlayer(playerItem: item)
    self.player = newPlayer
    self.currentClipStartTime = viewModel.clipStartTimeSeconds
    self.currentClipEndTime = viewModel.clipEndTimeSeconds
    self.playerView.attach(player: newPlayer)

    // Reset front state for the new card.
    frontVideoVisibility = .blackThumbnail
    isShowingBack = false
    isFrontTranscriptRevealed = false
    applyFrontVideoVisibility()
    updateFrontTranscriptRevealView()
    showFront()
    startLoop()
  }

  func revealBack() {
    isShowingBack = true
    // Once revealed, video is always clear regardless of prior front state.
    frontVideoVisibility = .clearVideo
    applyFrontVideoVisibility()
    frontContainer.isHidden = true
    backContainer.isHidden = false
  }

  func replay() {
    startLoop()
  }

  func showEmptyState(message: String) {
    emptyLabel.text = message
    emptyLabel.isHidden = false
    videoStageView.isHidden = true
    frontContainer.isHidden = true
    backContainer.isHidden = true
    stopLoop()
  }

  // MARK: - Private layout

  private func showFront() {
    frontContainer.isHidden = false
    backContainer.isHidden = true
  }

  private func applyFrontVideoVisibility() {
    if isShowingBack {
      blackMaskView.isHidden = true
      blurOverlayView.isHidden = true
      return
    }
    switch frontVideoVisibility {
    case .blackThumbnail:
      blackMaskView.isHidden = false
      blurOverlayView.isHidden = true
    case .blurredVideo:
      blackMaskView.isHidden = true
      blurOverlayView.isHidden = false
    case .clearVideo:
      blackMaskView.isHidden = true
      blurOverlayView.isHidden = true
    }
  }

  private func updateFrontTranscriptRevealView() {
    if isFrontTranscriptRevealed {
      frontTranscriptRevealHint.isHidden = true
      frontTranscriptLabel.isHidden = false
    } else {
      frontTranscriptRevealHint.isHidden = false
      frontTranscriptLabel.isHidden = true
    }
  }

  // MARK: - Looping

  private func startLoop() {
    guard let player = self.player else { return }
    isLooping = true
    pendingLoopRestartTask?.cancel()
    pendingLoopRestartTask = nil
    let startCMTime = CMTime(seconds: currentClipStartTime, preferredTimescale: 600)
    player.seek(to: startCMTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self = self, self.isLooping else { return }
        player.play()
        self.installLoopObserver()
      }
    }
  }

  private func stopLoop() {
    isLooping = false
    pendingLoopRestartTask?.cancel()
    pendingLoopRestartTask = nil
    player?.pause()
    removeLoopObserver()
  }

  private func installLoopObserver() {
    removeLoopObserver()
    let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
    loopObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self = self,
              self.isLooping,
              let player = self.player else { return }
        let endCMTime = CMTime(seconds: self.currentClipEndTime, preferredTimescale: 600)
        if CMTimeCompare(player.currentTime(), endCMTime) >= 0 {
          self.scheduleLoopRestart()
        }
      }
    }
  }

  private func removeLoopObserver() {
    if let observer = loopObserver {
      player?.removeTimeObserver(observer)
      loopObserver = nil
    }
  }

  private func scheduleLoopRestart() {
    guard let player = self.player, isLooping else { return }
    player.pause()
    removeLoopObserver()
    pendingLoopRestartTask?.cancel()
    pendingLoopRestartTask = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(Self.loopGapSeconds * 1_000_000_000))
      guard let self = self, self.isLooping else { return }
      self.startLoop()
    }
  }

  // MARK: - Actions

  @objc private func handleFrontVideoTap() {
    switch frontVideoVisibility {
    case .blackThumbnail: frontVideoVisibility = .blurredVideo
    case .blurredVideo: frontVideoVisibility = .clearVideo
    case .clearVideo: break
    }
    applyFrontVideoVisibility()
  }

  @objc private func handleFrontTranscriptRevealTap() {
    isFrontTranscriptRevealed = true
    updateFrontTranscriptRevealView()
  }

  @objc private func handleFrontReplayTap() {
    onReplayTapped?()
  }

  @objc private func handleFrontRevealBackTap() {
    onRevealBackTapped?()
  }

  @objc private func handleFailTap() {
    onGraded?(.fail)
  }

  @objc private func handlePassTap() {
    onGraded?(.pass)
  }

  // MARK: - Helpers

  private static func styleAction(
    _ button: UIButton,
    title: String,
    hotkey: String,
    backgroundColor: UIColor
  ) {
    var config = UIButton.Configuration.filled()
    config.title = title
    config.subtitle = "(\(hotkey))"
    config.baseBackgroundColor = backgroundColor
    config.baseForegroundColor = .white
    config.cornerStyle = .medium
    config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
    config.titleAlignment = .center
    button.configuration = config
    button.translatesAutoresizingMaskIntoConstraints = false
  }
}

// MARK: - PlayerLayerView

private final class PlayerLayerView: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }
  private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    playerLayer.videoGravity = .resizeAspect
  }
  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
  func attach(player: AVPlayer) { playerLayer.player = player }
}
