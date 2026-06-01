import UIKit
import AVFoundation
import MSRS_Shared
import MSRS_SharedModels

final class SRSCardReviewView: UIView {

  var onRevealBackTapped: (() -> Void)?
  var onReplayTapped: (() -> Void)?
  var onGraded: ((SRSCardReviewModels.Grade) -> Void)?
  var onTermTapped: ((Int64) -> Void)?
  var onFrontVideoVisibilityChanged: ((SRSCardModel.FrontVideoVisibility) -> Void)?
  var onPlaybackSpeedChanged: ((Double) -> Void)?

  // MARK: - Common

  private let positionLabel = UILabel()
  private let clipProgressBar = ClipProgressBar()
  private let videoStageView = UIView()
  private let thumbnailImageView = UIImageView()
  private let playerView = PlayerLayerView()
  private let blurContainerView = UIView()
  private let blurOverlayView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
  private let blackMaskView = UIView()

  // MARK: - Speed controls (shared creation, separate instances for front/back)

  private let frontSpeedRow = UIStackView()
  private let frontSpeedLabel = UILabel()
  private let backSpeedRow = UIStackView()
  private let backSpeedLabel = UILabel()
  private let backStreakLabel = UILabel()

  // MARK: - Front

  private let frontContainer = UIView()
  private let frontTranscriptRevealContainer = UIView()
  private let frontTranscriptRevealHint = UILabel()
  private let frontTranscriptLabel = UILabel()
  private let frontToggleButton = UIButton(type: .system)
  private let frontPlayButton = UIButton(type: .system)
  private let frontRevealBackButton = UIButton(type: .system)

  // MARK: - Back

  private let backContainer = UIView()
  private let backTranscriptView = HighlightableTranscriptView()
  private let backInflectionAnnotationsLabel = UILabel()
  private let backTranslationLabel = UILabel()
  private let backPlayButton = UIButton(type: .system)
  private let backFailButton = UIButton(type: .system)
  private let backPassButton = UIButton(type: .system)

  // MARK: - Other

  private let emptyLabel = UILabel()

  // MARK: - State

  private var frontVideoVisibility: SRSCardModel.FrontVideoVisibility = .blackScreen
  private var isShowingBack = false
  private var isFrontTranscriptRevealed = false
  private var isVideoPlaying = false
  private var playbackSpeed: Double = 1.0

  private var player: AVPlayer?
  private var currentClipStartTime: TimeInterval = 0
  private var currentClipEndTime: TimeInterval = 0
  private var endObserver: Any?
  private var thumbnailTask: Task<Void, Never>?
  private var currentThumbnailFileURL: URL?
  private var currentVideoFileURL: URL?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    setUpPositionLabel()
    setUpVideoStage()
    setUpSpeedControls()
    setUpFront()
    setUpBack()
    setUpEmptyLabel()
    setUpLayout()
    showEmptyState(message: "Loading deck…")
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  deinit {
    thumbnailTask?.cancel()
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
    videoStageView.clipsToBounds = true
    videoStageView.translatesAutoresizingMaskIntoConstraints = false

    thumbnailImageView.contentMode = .scaleAspectFit
    thumbnailImageView.backgroundColor = .black
    thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
    videoStageView.addSubview(thumbnailImageView)

    playerView.translatesAutoresizingMaskIntoConstraints = false
    playerView.isHidden = true
    videoStageView.addSubview(playerView)

    blurContainerView.clipsToBounds = true
    blurContainerView.translatesAutoresizingMaskIntoConstraints = false
    videoStageView.addSubview(blurContainerView)
    blurOverlayView.frame = .zero
    blurOverlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    blurContainerView.addSubview(blurOverlayView)

    blackMaskView.backgroundColor = .black
    blackMaskView.translatesAutoresizingMaskIntoConstraints = false
    videoStageView.addSubview(blackMaskView)

    NSLayoutConstraint.activate([
      thumbnailImageView.topAnchor.constraint(equalTo: videoStageView.topAnchor),
      thumbnailImageView.leadingAnchor.constraint(equalTo: videoStageView.leadingAnchor),
      thumbnailImageView.trailingAnchor.constraint(equalTo: videoStageView.trailingAnchor),
      thumbnailImageView.bottomAnchor.constraint(equalTo: videoStageView.bottomAnchor),

      playerView.topAnchor.constraint(equalTo: videoStageView.topAnchor),
      playerView.leadingAnchor.constraint(equalTo: videoStageView.leadingAnchor),
      playerView.trailingAnchor.constraint(equalTo: videoStageView.trailingAnchor),
      playerView.bottomAnchor.constraint(equalTo: videoStageView.bottomAnchor),

      blurContainerView.topAnchor.constraint(equalTo: videoStageView.topAnchor),
      blurContainerView.leadingAnchor.constraint(equalTo: videoStageView.leadingAnchor),
      blurContainerView.trailingAnchor.constraint(equalTo: videoStageView.trailingAnchor),
      blurContainerView.bottomAnchor.constraint(equalTo: videoStageView.bottomAnchor),

      blackMaskView.topAnchor.constraint(equalTo: videoStageView.topAnchor),
      blackMaskView.leadingAnchor.constraint(equalTo: videoStageView.leadingAnchor),
      blackMaskView.trailingAnchor.constraint(equalTo: videoStageView.trailingAnchor),
      blackMaskView.bottomAnchor.constraint(equalTo: videoStageView.bottomAnchor),

      videoStageView.heightAnchor.constraint(equalToConstant: 360),
    ])
  }

  private func setUpSpeedControls() {
    configureSpeedRow(frontSpeedRow, speedLabel: frontSpeedLabel)
    configureSpeedRow(backSpeedRow, speedLabel: backSpeedLabel)

    backStreakLabel.font = .preferredFont(forTextStyle: .footnote)
    backStreakLabel.textColor = .secondaryLabel
    backStreakLabel.textAlignment = .center
    backStreakLabel.translatesAutoresizingMaskIntoConstraints = false
  }

  private func configureSpeedRow(_ row: UIStackView, speedLabel: UILabel) {
    row.axis = .horizontal
    row.spacing = 8
    row.alignment = .center
    row.translatesAutoresizingMaskIntoConstraints = false

    let minus01 = makeSpeedButton(title: "−0.1", delta: -0.1)
    let minus005 = makeSpeedButton(title: "−0.05", delta: -0.05)
    let plus005 = makeSpeedButton(title: "+0.05", delta: 0.05)
    let plus01 = makeSpeedButton(title: "+0.1", delta: 0.1)

    speedLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
    speedLabel.textAlignment = .center
    speedLabel.translatesAutoresizingMaskIntoConstraints = false
    speedLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true

    row.addArrangedSubview(minus01)
    row.addArrangedSubview(minus005)
    row.addArrangedSubview(speedLabel)
    row.addArrangedSubview(plus005)
    row.addArrangedSubview(plus01)
  }

  private func makeSpeedButton(title: String, delta: Double) -> UIButton {
    var config = UIButton.Configuration.tinted()
    config.title = title
    config.baseBackgroundColor = .systemGray
    config.baseForegroundColor = .label
    config.cornerStyle = .medium
    config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
    let button = UIButton(configuration: config)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addAction(UIAction { [weak self] _ in
      self?.handleSpeedDelta(delta)
    }, for: .touchUpInside)
    return button
  }

  private func handleSpeedDelta(_ delta: Double) {
    let newSpeed = max(0.25, min(2.0, (playbackSpeed * 100 + delta * 100).rounded() / 100))
    guard newSpeed != playbackSpeed else { return }
    playbackSpeed = newSpeed
    updateSpeedLabels()
    onPlaybackSpeedChanged?(newSpeed)
  }

  private func updateSpeedLabels() {
    let text = String(format: "%.2fx", playbackSpeed)
    frontSpeedLabel.text = text
    backSpeedLabel.text = text
  }

  private func setUpFront() {
    frontContainer.translatesAutoresizingMaskIntoConstraints = false

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

    Self.styleAction(frontToggleButton, title: "Toggle Thumbnail", hotkey: "T", backgroundColor: .systemGray)
    frontToggleButton.addTarget(self, action: #selector(handleToggleTap), for: .touchUpInside)

    Self.styleAction(frontPlayButton, title: "Play", hotkey: "Space", backgroundColor: .systemBlue)
    frontPlayButton.addTarget(self, action: #selector(handlePlayTap), for: .touchUpInside)

    Self.styleAction(frontRevealBackButton, title: "Reveal Back", hotkey: "Return", backgroundColor: .systemIndigo)
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

    backInflectionAnnotationsLabel.font = .preferredFont(forTextStyle: .caption1)
    backInflectionAnnotationsLabel.textColor = .tertiaryLabel
    backInflectionAnnotationsLabel.numberOfLines = 0
    backInflectionAnnotationsLabel.isHidden = true
    backInflectionAnnotationsLabel.translatesAutoresizingMaskIntoConstraints = false

    backTranslationLabel.font = .preferredFont(forTextStyle: .title3)
    backTranslationLabel.textColor = .secondaryLabel
    backTranslationLabel.numberOfLines = 0
    backTranslationLabel.translatesAutoresizingMaskIntoConstraints = false

    Self.styleAction(backPlayButton, title: "Play", hotkey: "Space", backgroundColor: .systemBlue)
    backPlayButton.addTarget(self, action: #selector(handlePlayTap), for: .touchUpInside)

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
    addSubview(clipProgressBar)
    addSubview(frontContainer)
    addSubview(backContainer)

    // Front: [Toggle | Play] row, speed row, optional transcript, Reveal Back full-width at bottom
    let frontTopRow = UIStackView(arrangedSubviews: [frontToggleButton, frontPlayButton])
    frontTopRow.axis = .horizontal
    frontTopRow.spacing = 16
    frontTopRow.translatesAutoresizingMaskIntoConstraints = false

    frontContainer.addSubview(frontTopRow)
    frontContainer.addSubview(frontSpeedRow)
    frontContainer.addSubview(frontTranscriptRevealContainer)
    frontContainer.addSubview(frontRevealBackButton)

    // Back: Play under video, speed row, streak, transcript + translation, Fail|Pass 50/50 at bottom
    let backGradeRow = UIStackView(arrangedSubviews: [backFailButton, backPassButton])
    backGradeRow.axis = .horizontal
    backGradeRow.spacing = 16
    backGradeRow.distribution = .fillEqually
    backGradeRow.translatesAutoresizingMaskIntoConstraints = false

    backContainer.addSubview(backPlayButton)
    backContainer.addSubview(backSpeedRow)
    backContainer.addSubview(backStreakLabel)
    backContainer.addSubview(backTranscriptView)
    backContainer.addSubview(backInflectionAnnotationsLabel)
    backContainer.addSubview(backTranslationLabel)
    backContainer.addSubview(backGradeRow)

    NSLayoutConstraint.activate([
      positionLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
      positionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      positionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

      videoStageView.topAnchor.constraint(equalTo: positionLabel.bottomAnchor, constant: 16),
      videoStageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
      videoStageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

      clipProgressBar.topAnchor.constraint(equalTo: videoStageView.bottomAnchor, constant: 6),
      clipProgressBar.leadingAnchor.constraint(equalTo: videoStageView.leadingAnchor),
      clipProgressBar.trailingAnchor.constraint(equalTo: videoStageView.trailingAnchor),

      // -- Front --
      frontContainer.topAnchor.constraint(equalTo: clipProgressBar.bottomAnchor, constant: 12),
      frontContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
      frontContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
      frontContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),

      frontTopRow.topAnchor.constraint(equalTo: frontContainer.topAnchor),
      frontTopRow.leadingAnchor.constraint(equalTo: frontContainer.leadingAnchor),

      frontSpeedRow.topAnchor.constraint(equalTo: frontTopRow.bottomAnchor, constant: 12),
      frontSpeedRow.leadingAnchor.constraint(equalTo: frontContainer.leadingAnchor),

      frontTranscriptRevealContainer.topAnchor.constraint(equalTo: frontSpeedRow.bottomAnchor, constant: 16),
      frontTranscriptRevealContainer.leadingAnchor.constraint(equalTo: frontContainer.leadingAnchor),
      frontTranscriptRevealContainer.trailingAnchor.constraint(equalTo: frontContainer.trailingAnchor),

      frontRevealBackButton.leadingAnchor.constraint(equalTo: frontContainer.leadingAnchor),
      frontRevealBackButton.trailingAnchor.constraint(equalTo: frontContainer.trailingAnchor),
      frontRevealBackButton.bottomAnchor.constraint(equalTo: frontContainer.bottomAnchor),

      // -- Back --
      backContainer.topAnchor.constraint(equalTo: clipProgressBar.bottomAnchor, constant: 12),
      backContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
      backContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
      backContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),

      backPlayButton.topAnchor.constraint(equalTo: backContainer.topAnchor),
      backPlayButton.leadingAnchor.constraint(equalTo: backContainer.leadingAnchor),

      backSpeedRow.topAnchor.constraint(equalTo: backPlayButton.bottomAnchor, constant: 12),
      backSpeedRow.leadingAnchor.constraint(equalTo: backContainer.leadingAnchor),

      backStreakLabel.topAnchor.constraint(equalTo: backSpeedRow.bottomAnchor, constant: 4),
      backStreakLabel.leadingAnchor.constraint(equalTo: backContainer.leadingAnchor),

      backTranscriptView.topAnchor.constraint(equalTo: backStreakLabel.bottomAnchor, constant: 12),
      backTranscriptView.leadingAnchor.constraint(equalTo: backContainer.leadingAnchor),
      backTranscriptView.trailingAnchor.constraint(equalTo: backContainer.trailingAnchor),

      backInflectionAnnotationsLabel.topAnchor.constraint(equalTo: backTranscriptView.bottomAnchor, constant: 4),
      backInflectionAnnotationsLabel.leadingAnchor.constraint(equalTo: backContainer.leadingAnchor),
      backInflectionAnnotationsLabel.trailingAnchor.constraint(equalTo: backContainer.trailingAnchor),

      backTranslationLabel.topAnchor.constraint(equalTo: backInflectionAnnotationsLabel.bottomAnchor, constant: 12),
      backTranslationLabel.leadingAnchor.constraint(equalTo: backContainer.leadingAnchor),
      backTranslationLabel.trailingAnchor.constraint(equalTo: backContainer.trailingAnchor),

      backGradeRow.leadingAnchor.constraint(equalTo: backContainer.leadingAnchor),
      backGradeRow.trailingAnchor.constraint(equalTo: backContainer.trailingAnchor),
      backGradeRow.bottomAnchor.constraint(equalTo: backContainer.bottomAnchor),

      // -- Empty --
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

  func cycleFrontVideoVisibility() {
    guard !isShowingBack else { return }
    stopPlayback()
    frontVideoVisibility = frontVideoVisibility.next
    if frontVideoVisibility != .blackScreen, thumbnailImageView.image == nil,
       let thumbURL = currentThumbnailFileURL, let videoURL = currentVideoFileURL {
      loadOrGenerateThumbnail(
        thumbnailFileURL: thumbURL,
        videoFileURL: videoURL,
        atTime: currentClipStartTime
      )
    }
    applyVideoStageVisibility()
    onFrontVideoVisibilityChanged?(frontVideoVisibility)
  }

  func setCard(_ viewModel: SRSCardReviewModels.CardViewModel) {
    emptyLabel.isHidden = true
    positionLabel.text = viewModel.cardPositionLabel
    videoStageView.isHidden = false

    backTranscriptView.setTranscript(
      text: viewModel.transcriptText,
      labeledRanges: viewModel.transcriptLabeledRanges
    )
    backInflectionAnnotationsLabel.text = viewModel.inflectionAnnotationsText
    backInflectionAnnotationsLabel.isHidden = viewModel.inflectionAnnotationsText == nil
    backTranslationLabel.text = viewModel.englishTranslationText ?? "(no translation)"
    frontTranscriptLabel.text = viewModel.transcriptText

    stopPlayback()
    clipProgressBar.reset()

    let asset = AVURLAsset(url: viewModel.videoFileURL)
    let item = AVPlayerItem(asset: asset)
    let newPlayer = AVPlayer(playerItem: item)
    self.player = newPlayer
    self.currentClipStartTime = viewModel.clipStartTimeSeconds
    self.currentClipEndTime = viewModel.clipEndTimeSeconds
    self.playerView.attach(player: newPlayer)

    frontVideoVisibility = viewModel.frontVideoVisibility
    playbackSpeed = viewModel.playbackSpeed
    isShowingBack = false
    isFrontTranscriptRevealed = false
    isVideoPlaying = false
    playerView.isHidden = true
    updateSpeedLabels()
    backStreakLabel.text = "Consecutive correct at this speed: \(viewModel.consecutiveCorrectAtCurrentSpeed)"
    updateGradeButtonTitles(
      failInterval: viewModel.failIntervalSeconds,
      passInterval: viewModel.passIntervalSeconds
    )
    currentThumbnailFileURL = viewModel.thumbnailFileURL
    currentVideoFileURL = viewModel.videoFileURL
    thumbnailImageView.image = nil

    frontTranscriptRevealContainer.isHidden = !MSRSAppSettings.showFrontTranscript
    applyVideoStageVisibility()
    updateFrontTranscriptRevealView()
    showFront()
    if frontVideoVisibility != .blackScreen {
      loadOrGenerateThumbnail(
        thumbnailFileURL: viewModel.thumbnailFileURL,
        videoFileURL: viewModel.videoFileURL,
        atTime: viewModel.clipStartTimeSeconds
      )
    }
    playFromStart()
  }

  func revealBack() {
    isShowingBack = true
    frontContainer.isHidden = true
    backContainer.isHidden = false
    playFromStart()
  }

  func replay() {
    playFromStart()
  }

  func showEmptyState(message: String) {
    emptyLabel.text = message
    emptyLabel.isHidden = false
    videoStageView.isHidden = true
    frontContainer.isHidden = true
    backContainer.isHidden = true
    stopPlayback()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateBlurFrame()
  }

  // MARK: - Private layout

  private func showFront() {
    frontContainer.isHidden = false
    backContainer.isHidden = true
  }

  private func applyVideoStageVisibility() {
    if isShowingBack {
      playerView.isHidden = !isVideoPlaying
      blackMaskView.isHidden = true
      blurContainerView.isHidden = true
      return
    }

    playerView.isHidden = true

    switch frontVideoVisibility {
    case .blackScreen:
      blackMaskView.isHidden = false
      blurContainerView.isHidden = true
    case .blurredThumbnail:
      blackMaskView.isHidden = true
      blurContainerView.isHidden = false
    case .clearThumbnail:
      blackMaskView.isHidden = true
      blurContainerView.isHidden = true
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

  private func updateBlurFrame() {
    guard let imageSize = thumbnailImageView.image?.size,
          imageSize.width > 0, imageSize.height > 0 else {
      blurOverlayView.frame = blurContainerView.bounds
      return
    }
    let viewSize = thumbnailImageView.bounds.size
    guard viewSize.width > 0, viewSize.height > 0 else { return }
    let scaleX = viewSize.width / imageSize.width
    let scaleY = viewSize.height / imageSize.height
    let scale = min(scaleX, scaleY)
    let renderedWidth = imageSize.width * scale
    let renderedHeight = imageSize.height * scale
    let x = (viewSize.width - renderedWidth) / 2
    let y = (viewSize.height - renderedHeight) / 2
    blurOverlayView.frame = CGRect(x: x, y: y, width: renderedWidth, height: renderedHeight)
  }

  // MARK: - Playback

  private func playFromStart() {
    guard let player else { return }
    stopPlayback()
    isVideoPlaying = true
    applyVideoStageVisibility()
    let startCMTime = CMTime(seconds: currentClipStartTime, preferredTimescale: 600)
    player.seek(to: startCMTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, self.isVideoPlaying else { return }
        player.rate = Float(self.playbackSpeed)
        self.installEndObserver()
      }
    }
  }

  private func stopPlayback() {
    isVideoPlaying = false
    player?.pause()
    removeEndObserver()
  }

  private func installEndObserver() {
    removeEndObserver()
    let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
    endObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, self.isVideoPlaying, let player = self.player else { return }
        let currentSeconds = CMTimeGetSeconds(player.currentTime())
        let duration = self.currentClipEndTime - self.currentClipStartTime
        if duration > 0 {
          self.clipProgressBar.setProgress((currentSeconds - self.currentClipStartTime) / duration)
        }
        let endCMTime = CMTime(seconds: self.currentClipEndTime, preferredTimescale: 600)
        if CMTimeCompare(player.currentTime(), endCMTime) >= 0 {
          self.clipProgressBar.setProgress(1)
          player.pause()
          self.isVideoPlaying = false
          self.removeEndObserver()
          self.applyVideoStageVisibility()
        }
      }
    }
  }

  private func removeEndObserver() {
    if let observer = endObserver {
      player?.removeTimeObserver(observer)
      endObserver = nil
    }
  }

  // MARK: - Thumbnail

  private func loadOrGenerateThumbnail(
    thumbnailFileURL: URL,
    videoFileURL: URL,
    atTime time: TimeInterval
  ) {
    thumbnailTask?.cancel()
    thumbnailImageView.image = nil
    thumbnailTask = Task { [weak self] in
      if let cached = UIImage(contentsOfFile: thumbnailFileURL.path) {
        guard !Task.isCancelled else { return }
        await MainActor.run {
          self?.thumbnailImageView.image = cached
          self?.updateBlurFrame()
        }
        return
      }
      let asset = AVURLAsset(url: videoFileURL)
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 960, height: 540)
      generator.requestedTimeToleranceBefore = .zero
      generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
      let cmTime = CMTime(seconds: time, preferredTimescale: 600)
      do {
        let (cgImage, _) = try await generator.image(at: cmTime)
        guard !Task.isCancelled else { return }
        let image = UIImage(cgImage: cgImage)
        if let jpegData = image.jpegData(compressionQuality: 0.6) {
          try? jpegData.write(to: thumbnailFileURL, options: .atomic)
        }
        await MainActor.run {
          self?.thumbnailImageView.image = image
          self?.updateBlurFrame()
        }
      } catch {
        // Thumbnail generation failed — black background is the fallback.
      }
    }
  }

  // MARK: - Actions

  @objc private func handleToggleTap() {
    cycleFrontVideoVisibility()
  }

  @objc private func handlePlayTap() {
    onReplayTapped?()
  }

  @objc private func handleFrontTranscriptRevealTap() {
    isFrontTranscriptRevealed = true
    updateFrontTranscriptRevealView()
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

  private func updateGradeButtonTitles(
    failInterval: TimeInterval?,
    passInterval: TimeInterval?
  ) {
    let failTitle = failInterval.map { "Fail · \(Self.formatInterval($0))" } ?? "Fail"
    let passTitle = passInterval.map { "Pass · \(Self.formatInterval($0))" } ?? "Pass"
    backFailButton.configuration?.title = failTitle
    backPassButton.configuration?.title = passTitle
  }

  private static func formatInterval(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    if totalSeconds < 60 {
      return "\(max(1, totalSeconds))s"
    }
    let minutes = totalSeconds / 60
    if minutes < 60 {
      return "\(minutes)m"
    }
    let hours = minutes / 60
    if hours < 24 {
      return "\(hours)h"
    }
    let days = hours / 24
    if days < 31 {
      return "\(days)d"
    }
    let months = days / 30
    return "\(months)mo"
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
