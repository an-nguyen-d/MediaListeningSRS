import UIKit
import AVFoundation
import MSRS_Shared

final class CandidateDetailView: UIView {

  var onEndIndexChanged: ((Int) -> Void)?
  var onStartTimeAdjusted: ((TimeInterval) -> Void)?
  var onEndTimeAdjusted: ((TimeInterval) -> Void)?
  var onTermTapped: ((Int64) -> Void)?
  var onSkipTapped: (() -> Void)?
  var onConfirmTapped: (() -> Void)?

  private static let videoHeightUserDefaultsKey = "MSRS.CandidateDetail.videoHeight"
  private static let minVideoHeight: CGFloat = 120
  private static let maxVideoHeight: CGFloat = 800
  private static let defaultVideoHeight: CGFloat = 320
  private static let loopGapSeconds: TimeInterval = 0.5

  private let scrollView = UIScrollView()
  private let stack = UIStackView()

  private let playerView = PlayerLayerView()
  private let clipProgressBar = ClipProgressBar()
  private var playerHeightConstraint: NSLayoutConstraint!
  private let dragHandleView = UIView()
  private let dragHandleBar = UIView()

  private let playPauseButton = UIButton.makeStyled(title: "Pause", hotkey: "Space", backgroundColor: .systemIndigo)

  private let speedDecreaseLargeButton = UIButton.makeStyled(title: "−0.1", backgroundColor: .systemGray)
  private let speedDecreaseSmallButton = UIButton.makeStyled(title: "−0.05", backgroundColor: .systemGray)
  private let speedRateLabel = UILabel()
  private let speedIncreaseSmallButton = UIButton.makeStyled(title: "+0.05", backgroundColor: .systemGray)
  private let speedIncreaseLargeButton = UIButton.makeStyled(title: "+0.1", backgroundColor: .systemGray)
  private let speedResetButton = UIButton.makeStyled(title: "Reset", backgroundColor: .systemGray2)

  private let rangeLabel = UILabel()
  private let transcriptView = HighlightableTranscriptView()
  private let translationLabel = UILabel()

  private let endIndexLabel = UILabel()
  private let endIndexStepper = UIStepper()

  private let startTimeLabel = UILabel()
  private let startTimeMinusLargeButton = UIButton.makeStyled(title: "−1.0", hotkey: "⌥⇧A", backgroundColor: .systemGray)
  private let startTimeMinusSmallButton = UIButton.makeStyled(title: "−0.3", hotkey: "⌥A", backgroundColor: .systemGray)
  private let startTimePlusSmallButton = UIButton.makeStyled(title: "+0.3", hotkey: "⌥D", backgroundColor: .systemGray)
  private let startTimePlusLargeButton = UIButton.makeStyled(title: "+1.0", hotkey: "⌥⇧D", backgroundColor: .systemGray)

  private let endTimeLabel = UILabel()
  private let endTimeMinusLargeButton = UIButton.makeStyled(title: "−1.0", hotkey: "⌘⇧A", backgroundColor: .systemGray)
  private let endTimeMinusSmallButton = UIButton.makeStyled(title: "−0.3", hotkey: "⌘A", backgroundColor: .systemGray)
  private let endTimePlusSmallButton = UIButton.makeStyled(title: "+0.3", hotkey: "⌘D", backgroundColor: .systemGray)
  private let endTimePlusLargeButton = UIButton.makeStyled(title: "+1.0", hotkey: "⌘⇧D", backgroundColor: .systemGray)

  private let skipButton = UIButton.makeStyled(title: "Skip", hotkey: "N", backgroundColor: .systemRed)
  private let confirmButton = UIButton.makeStyled(title: "Confirm & Make Card", hotkey: "Y", backgroundColor: .systemGreen)

  private let placeholderLabel = UILabel()

  private var player: AVPlayer?
  private var currentVideoFileURL: URL?
  private var currentClipStartTime: TimeInterval = 0
  private var currentClipEndTime: TimeInterval = 0
  private var endTimeObserver: Any?
  private var currentPlaybackRate: Float = 1.0
  private var isLoopActive: Bool = false
  private var pendingLoopRestartTask: Task<Void, Never>?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    setUpStack()
    setUpPlayerAndDrag()
    setUpControls()
    setUpConstraints()
    setUpPlaceholder()
    showPlaceholder("Select a candidate")
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    pendingLoopRestartTask?.cancel()
  }

  // MARK: - Setup

  private func setUpStack() {
    stack.axis = .vertical
    stack.spacing = 12
    stack.alignment = .fill
    addSubview(scrollView)
    scrollView.addSubview(stack)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    stack.translatesAutoresizingMaskIntoConstraints = false
  }

  private func setUpPlayerAndDrag() {
    playerView.translatesAutoresizingMaskIntoConstraints = false
    let savedHeight = UserDefaults.standard.object(forKey: Self.videoHeightUserDefaultsKey) as? CGFloat
      ?? Self.defaultVideoHeight
    let clampedHeight = max(Self.minVideoHeight, min(Self.maxVideoHeight, savedHeight))
    playerHeightConstraint = playerView.heightAnchor.constraint(equalToConstant: clampedHeight)
    playerHeightConstraint.isActive = true

    dragHandleView.translatesAutoresizingMaskIntoConstraints = false
    dragHandleView.backgroundColor = .clear
    dragHandleView.heightAnchor.constraint(equalToConstant: 24).isActive = true

    dragHandleBar.translatesAutoresizingMaskIntoConstraints = false
    dragHandleBar.backgroundColor = .tertiarySystemFill
    dragHandleBar.layer.cornerRadius = 3
    dragHandleView.addSubview(dragHandleBar)
    NSLayoutConstraint.activate([
      dragHandleBar.centerXAnchor.constraint(equalTo: dragHandleView.centerXAnchor),
      dragHandleBar.centerYAnchor.constraint(equalTo: dragHandleView.centerYAnchor),
      dragHandleBar.widthAnchor.constraint(equalToConstant: 48),
      dragHandleBar.heightAnchor.constraint(equalToConstant: 6),
    ])

    let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDragHandlePan(_:)))
    dragHandleView.addGestureRecognizer(pan)
  }

  private func setUpControls() {
    playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)

    speedDecreaseLargeButton.addTarget(self, action: #selector(speedDecreaseLargeTapped), for: .touchUpInside)
    speedDecreaseSmallButton.addTarget(self, action: #selector(speedDecreaseSmallTapped), for: .touchUpInside)
    speedRateLabel.font = .preferredFont(forTextStyle: .headline)
    speedRateLabel.textAlignment = .center
    speedIncreaseSmallButton.addTarget(self, action: #selector(speedIncreaseSmallTapped), for: .touchUpInside)
    speedIncreaseLargeButton.addTarget(self, action: #selector(speedIncreaseLargeTapped), for: .touchUpInside)
    speedResetButton.addTarget(self, action: #selector(speedResetTapped), for: .touchUpInside)
    updateSpeedRateLabel()

    rangeLabel.font = .preferredFont(forTextStyle: .headline)

    transcriptView.transcriptFont = .systemFont(ofSize: 80, weight: .regular)
    transcriptView.onTermTapped = { [weak self] termID in
      self?.onTermTapped?(termID)
    }

    translationLabel.font = .preferredFont(forTextStyle: .title3)
    translationLabel.textColor = .secondaryLabel
    translationLabel.numberOfLines = 0

    endIndexLabel.font = .preferredFont(forTextStyle: .subheadline)
    endIndexStepper.stepValue = 1
    endIndexStepper.addTarget(self, action: #selector(endIndexStepperChanged), for: .valueChanged)

    startTimeLabel.font = .preferredFont(forTextStyle: .subheadline)
    startTimeMinusLargeButton.addTarget(self, action: #selector(startTimeMinusLargeTapped), for: .touchUpInside)
    startTimeMinusSmallButton.addTarget(self, action: #selector(startTimeMinusSmallTapped), for: .touchUpInside)
    startTimePlusSmallButton.addTarget(self, action: #selector(startTimePlusSmallTapped), for: .touchUpInside)
    startTimePlusLargeButton.addTarget(self, action: #selector(startTimePlusLargeTapped), for: .touchUpInside)

    endTimeLabel.font = .preferredFont(forTextStyle: .subheadline)
    endTimeMinusLargeButton.addTarget(self, action: #selector(endTimeMinusLargeTapped), for: .touchUpInside)
    endTimeMinusSmallButton.addTarget(self, action: #selector(endTimeMinusSmallTapped), for: .touchUpInside)
    endTimePlusSmallButton.addTarget(self, action: #selector(endTimePlusSmallTapped), for: .touchUpInside)
    endTimePlusLargeButton.addTarget(self, action: #selector(endTimePlusLargeTapped), for: .touchUpInside)

    skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
    confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)

    let playPauseRow = UIStackView.leadingPinnedRow(children: [playPauseButton], spacing: 8)

    let speedRow = UIStackView.leadingPinnedRow(children: [
      speedDecreaseLargeButton, speedDecreaseSmallButton,
      speedRateLabel,
      speedIncreaseSmallButton, speedIncreaseLargeButton,
      speedResetButton,
    ], spacing: 8)

    let endIndexRow = UIStackView.leadingPinnedRow(children: [endIndexLabel, endIndexStepper], spacing: 12)

    let startTimeRow = UIStackView.leadingPinnedRow(children: [
      startTimeLabel,
      startTimeMinusLargeButton, startTimeMinusSmallButton,
      startTimePlusSmallButton, startTimePlusLargeButton,
    ], spacing: 8)

    let endTimeRow = UIStackView.leadingPinnedRow(children: [
      endTimeLabel,
      endTimeMinusLargeButton, endTimeMinusSmallButton,
      endTimePlusSmallButton, endTimePlusLargeButton,
    ], spacing: 8)

    let actionsRow = UIStackView.leadingPinnedRow(children: [skipButton, confirmButton], spacing: 16)

    stack.addArrangedSubview(playerView)
    stack.addArrangedSubview(clipProgressBar)
    stack.addArrangedSubview(dragHandleView)
    stack.addArrangedSubview(playPauseRow)
    stack.addArrangedSubview(speedRow)
    stack.addArrangedSubview(rangeLabel)
    stack.addArrangedSubview(transcriptView)
    stack.addArrangedSubview(translationLabel)
    stack.addArrangedSubview(endIndexRow)
    stack.addArrangedSubview(startTimeRow)
    stack.addArrangedSubview(endTimeRow)
    stack.addArrangedSubview(actionsRow)
  }

  private func setUpConstraints() {
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

      stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
      stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
      stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
      stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
    ])
  }

  private func setUpPlaceholder() {
    placeholderLabel.font = .preferredFont(forTextStyle: .title3)
    placeholderLabel.textColor = .secondaryLabel
    placeholderLabel.textAlignment = .center
    placeholderLabel.numberOfLines = 0
    placeholderLabel.isHidden = true
    addSubview(placeholderLabel)
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
      placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      placeholderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
      placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
    ])
  }

  // MARK: - Public API

  func boundingFrameForTermID(_ termID: Int64, in containerView: UIView) -> CGRect? {
    transcriptView.boundingFrameForTermID(termID, in: containerView)
  }

  func setSelectedTermID(_ termID: Int64?) {
    transcriptView.selectedTermID = termID
  }

  func showPlaceholder(_ message: String) {
    placeholderLabel.text = message
    placeholderLabel.isHidden = false
    scrollView.isHidden = true
    stopLoop()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil { stopLoop() }
  }

  func setVideoFile(url: URL) {
    if currentVideoFileURL == url, player != nil {
      return
    }
    stopLoop()
    currentVideoFileURL = url
    let asset = AVURLAsset(url: url)
    let item = AVPlayerItem(asset: asset)
    let newPlayer = AVPlayer(playerItem: item)
    self.player = newPlayer
    playerView.attach(player: newPlayer)
  }

  func setViewModel(_ viewModel: CandidateDetailModels.ViewModel) {
    placeholderLabel.isHidden = true
    scrollView.isHidden = false

    let rangeText: String
    if viewModel.subtitleIndexStart == viewModel.subtitleIndexEnd {
      rangeText = "Subtitle #\(viewModel.subtitleIndexStart)"
    } else {
      rangeText = "Subtitles #\(viewModel.subtitleIndexStart)–#\(viewModel.subtitleIndexEnd)"
    }
    rangeLabel.text = rangeText
    transcriptView.setTranscript(
      text: viewModel.subtitleText.isEmpty ? "(no subtitle text)" : viewModel.subtitleText,
      labeledRanges: viewModel.labeledRanges
    )
    translationLabel.text = viewModel.englishTranslationText ?? "(no translation)"

    endIndexLabel.text = "End index: \(viewModel.subtitleIndexEnd)"
    endIndexStepper.minimumValue = Double(viewModel.subtitleIndexStart)
    endIndexStepper.maximumValue = Double(viewModel.maxAvailableEndIndex)
    endIndexStepper.value = Double(viewModel.subtitleIndexEnd)

    startTimeLabel.text = String(format: "Start: %.2fs", viewModel.customStartTime)
    endTimeLabel.text = String(format: "End: %.2fs", viewModel.customEndTime)

    let isFirstSet = currentClipStartTime == 0 && currentClipEndTime == 0
    currentClipStartTime = viewModel.customStartTime
    currentClipEndTime = viewModel.customEndTime
    if isFirstSet {
      startLoop()
    }
  }

  // MARK: - Loop playback

  private func startLoop() {
    guard let player = self.player else { return }
    isLoopActive = true
    clipProgressBar.reset()
    Self.setStyledButtonTitle(playPauseButton, title: "Pause", hotkey: "Space")
    pendingLoopRestartTask?.cancel()
    pendingLoopRestartTask = nil
    let startCMTime = CMTime(seconds: currentClipStartTime, preferredTimescale: 600)
    player.seek(to: startCMTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self = self, self.isLoopActive else { return }
        player.rate = self.currentPlaybackRate
        self.installLoopObserver()
      }
    }
  }

  private func stopLoop() {
    isLoopActive = false
    Self.setStyledButtonTitle(playPauseButton, title: "Play", hotkey: "Space")
    pendingLoopRestartTask?.cancel()
    pendingLoopRestartTask = nil
    player?.pause()
    removeLoopObserver()
  }

  private func installLoopObserver() {
    removeLoopObserver()
    let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
    endTimeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self = self,
              self.isLoopActive,
              let player = self.player else { return }
        let currentSeconds = CMTimeGetSeconds(player.currentTime())
        let duration = self.currentClipEndTime - self.currentClipStartTime
        if duration > 0 {
          self.clipProgressBar.setProgress((currentSeconds - self.currentClipStartTime) / duration)
        }
        let endCMTime = CMTime(seconds: self.currentClipEndTime, preferredTimescale: 600)
        if CMTimeCompare(player.currentTime(), endCMTime) >= 0 {
          self.clipProgressBar.setProgress(1)
          self.scheduleLoopRestart()
        }
      }
    }
  }

  private func removeLoopObserver() {
    if let observer = endTimeObserver {
      player?.removeTimeObserver(observer)
      endTimeObserver = nil
    }
  }

  private func scheduleLoopRestart() {
    guard let player = self.player, isLoopActive else { return }
    player.pause()
    removeLoopObserver()
    pendingLoopRestartTask?.cancel()
    pendingLoopRestartTask = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(Self.loopGapSeconds * 1_000_000_000))
      guard let self = self, self.isLoopActive else { return }
      self.startLoop()
    }
  }

  // MARK: - Drag handle

  @objc private func handleDragHandlePan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: self)
    let proposed = playerHeightConstraint.constant + translation.y
    let clamped = max(Self.minVideoHeight, min(Self.maxVideoHeight, proposed))
    playerHeightConstraint.constant = clamped
    gesture.setTranslation(.zero, in: self)
    if gesture.state == .ended || gesture.state == .cancelled {
      UserDefaults.standard.set(clamped, forKey: Self.videoHeightUserDefaultsKey)
    }
  }

  // MARK: - Playback rate

  private func updateSpeedRateLabel() {
    speedRateLabel.text = String(format: "%.2fx", currentPlaybackRate)
  }

  private func adjustPlaybackRate(by delta: Float) {
    currentPlaybackRate = max(0.25, min(2.0, currentPlaybackRate + delta))
    updateSpeedRateLabel()
    if isLoopActive {
      player?.rate = currentPlaybackRate
    }
  }

  // MARK: - Actions

  @objc private func playPauseTapped() {
    toggleLoopActiveFromHost()
  }

  func toggleLoopActiveFromHost() {
    if isLoopActive {
      stopLoop()
    } else {
      startLoop()
    }
  }

  @objc private func speedDecreaseLargeTapped() { adjustPlaybackRate(by: -0.1) }
  @objc private func speedDecreaseSmallTapped() { adjustPlaybackRate(by: -0.05) }
  @objc private func speedIncreaseSmallTapped() { adjustPlaybackRate(by: 0.05) }
  @objc private func speedIncreaseLargeTapped() { adjustPlaybackRate(by: 0.1) }
  @objc private func speedResetTapped() {
    currentPlaybackRate = 1.0
    updateSpeedRateLabel()
    if isLoopActive { player?.rate = 1.0 }
  }

  @objc private func endIndexStepperChanged() {
    onEndIndexChanged?(Int(endIndexStepper.value))
  }

  @objc private func startTimeMinusLargeTapped() { adjustStartTime(delta: -1.0) }
  @objc private func startTimeMinusSmallTapped() { adjustStartTime(delta: -0.3) }
  @objc private func startTimePlusSmallTapped() { adjustStartTime(delta: 0.3) }
  @objc private func startTimePlusLargeTapped() { adjustStartTime(delta: 1.0) }

  @objc private func endTimeMinusLargeTapped() { adjustEndTime(delta: -1.0) }
  @objc private func endTimeMinusSmallTapped() { adjustEndTime(delta: -0.3) }
  @objc private func endTimePlusSmallTapped() { adjustEndTime(delta: 0.3) }
  @objc private func endTimePlusLargeTapped() { adjustEndTime(delta: 1.0) }

  func adjustStartTime(delta: TimeInterval) {
    onStartTimeAdjusted?(delta)
    seekToClipStart()
  }

  func adjustEndTime(delta: TimeInterval) {
    onEndTimeAdjusted?(delta)
    seekToNearClipEnd()
  }

  private func seekToClipStart() {
    guard let player = self.player else { return }
    let time = CMTime(seconds: currentClipStartTime, preferredTimescale: 600)
    player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
  }

  private func seekToNearClipEnd() {
    guard let player = self.player else { return }
    let seekTime = max(currentClipStartTime, currentClipEndTime - 1.0)
    let time = CMTime(seconds: seekTime, preferredTimescale: 600)
    player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
  }

  @objc private func skipButtonTapped() { onSkipTapped?() }
  @objc private func confirmButtonTapped() { onConfirmTapped?() }

  private static func setStyledButtonTitle(_ button: UIButton, title: String, hotkey: String?) {
    var config = button.configuration ?? UIButton.Configuration.filled()
    config.title = title
    config.subtitle = hotkey.map { "(\($0))" }
    button.configuration = config
  }
}

// MARK: - PlayerLayerView

private final class PlayerLayerView: UIView {

  override class var layerClass: AnyClass {
    AVPlayerLayer.self
  }

  private var playerLayer: AVPlayerLayer {
    layer as! AVPlayerLayer
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    playerLayer.videoGravity = .resizeAspect
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func attach(player: AVPlayer) {
    playerLayer.player = player
  }
}
