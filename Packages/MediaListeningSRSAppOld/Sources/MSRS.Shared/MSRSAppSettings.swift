import Foundation

public enum MSRSAppSettings {

  public static let desiredRetentionDefault: Double = 0.9
  public static let minimumCardCoverageCountDefault: Int = 50
  public static let studySessionInactivityTimeoutDefault: Int = 300
  public static let syncIntervalSecondsDefault: Int = 60
  public static let llmGradingPromptDefault: String = """
    You are a Japanese listening comprehension grader for a spaced repetition system. The learner \
    listened to Japanese audio and typed what they understood in English. Assess whether they \
    understood what was said.

    Grading rules:
    - Specific details (times, numbers, dates, names, amounts) must be correct. Missing or wrong \
    = major deduction.
    - For expressions with multiple valid meanings (よろしく, すみません, お疲れ様, etc.), accept \
    any reasonable interpretation. Err on the side of passing.
    - The learner does NOT need a perfect translation. They need to show they understood the meaning.
    - Natural English is fine. "Come at 7" and "Please come at 7 o'clock" are equally valid.

    Score 1-100:
    90-100: Fully understood, all details correct.
    70-89: Core meaning captured, minor nuances missed.
    50-69: Partial understanding, missed key details.
    30-49: Weak, missed the main point or got critical details wrong.
    1-29: Did not understand.

    Input mode: typed
    The learner typed their response manually. Evaluate their English at face value.

    Note on input modes: when input mode is "voice_transcription", the learner spoke their answer \
    aloud and it was converted to text by speech-to-text software. In that mode, be lenient with \
    homophones (their/there, to/too/two), minor word substitutions that sound similar, missing \
    punctuation, run-on sentences, and filler words — these are artifacts of transcription, not \
    comprehension errors. Focus only on whether the learner understood the Japanese. In "typed" \
    mode (like now), evaluate the text as written.

    Respond with ONLY a JSON object, no markdown, no preamble:
    {"score": N, "reasoning": "..."}
    """

  nonisolated(unsafe) private static var cached = AppSettingsModel(
    desiredRetention: desiredRetentionDefault,
    showFrontTranscript: true,
    minimumCardCoverageCount: minimumCardCoverageCountDefault,
    studySessionInactivityTimeout: studySessionInactivityTimeoutDefault,
    requireSkipOrMakeCardConfirmation: true,
    autoLoopVideo: false,
    llmGradingPrompt: "",
    syncIntervalSeconds: syncIntervalSecondsDefault,
    candidatePlayDelay: candidatePlayDelayDefault
  )

  public static func loadFromModel(_ model: AppSettingsModel) {
    cached = model
  }

  public static func currentModel() -> AppSettingsModel {
    cached
  }

  public static var requireSkipOrMakeCardConfirmation: Bool {
    get { cached.requireSkipOrMakeCardConfirmation }
    set { cached.requireSkipOrMakeCardConfirmation = newValue }
  }

  public static var desiredRetention: Double {
    get { cached.desiredRetention }
    set { cached.desiredRetention = newValue }
  }

  public static var showFrontTranscript: Bool {
    get { cached.showFrontTranscript }
    set { cached.showFrontTranscript = newValue }
  }

  public static var minimumCardCoverageCount: Int {
    get { max(1, cached.minimumCardCoverageCount) }
    set { cached.minimumCardCoverageCount = max(1, newValue) }
  }

  public static var studySessionInactivityTimeout: Int {
    get { max(30, cached.studySessionInactivityTimeout) }
    set { cached.studySessionInactivityTimeout = max(30, newValue) }
  }

  private static let autoLoopVideoKey = "MSRS.autoLoopVideo"
  private static let condensedReviewModeKey = "MSRS.condensedReviewMode"
  private static let srsButtonHeightKey = "MSRS.srsButtonHeight"
  private static let autoPassEnabledKey = "MSRS.autoPassEnabled"
  private static let autoPassDelayKey = "MSRS.autoPassDelay"
  private static let autoFlipEnabledKey = "MSRS.autoFlipEnabled"
  private static let autoFlipDelayKey = "MSRS.autoFlipDelay"
  private static let numpadHotkeysEnabledKey = "MSRS.numpadHotkeysEnabled"
  private static let reviewFeedbackEffectsEnabledKey = "MSRS.reviewFeedbackEffectsEnabled"

  public static let srsButtonHeightMin: CGFloat = 30
  public static let srsButtonHeightMax: CGFloat = 240
  public static let srsButtonHeightDefault: CGFloat = 60

  public static var autoLoopVideo: Bool {
    get { UserDefaults.standard.bool(forKey: autoLoopVideoKey) }
    set { UserDefaults.standard.set(newValue, forKey: autoLoopVideoKey) }
  }

  public static var condensedReviewMode: Bool {
    get { UserDefaults.standard.bool(forKey: condensedReviewModeKey) }
    set { UserDefaults.standard.set(newValue, forKey: condensedReviewModeKey) }
  }

  public static var srsButtonHeight: CGFloat {
    get {
      let val = UserDefaults.standard.double(forKey: srsButtonHeightKey)
      guard val > 0 else { return srsButtonHeightDefault }
      return CGFloat(max(Double(srsButtonHeightMin), min(Double(srsButtonHeightMax), val)))
    }
    set {
      let clamped = max(srsButtonHeightMin, min(srsButtonHeightMax, newValue))
      UserDefaults.standard.set(Double(clamped), forKey: srsButtonHeightKey)
    }
  }

  public static let autoPassDelayMin: Double = 0.2
  public static let autoPassDelayMax: Double = 10
  public static let autoPassDelayDefault: Double = 5

  public static var autoPassEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: autoPassEnabledKey) }
    set { UserDefaults.standard.set(newValue, forKey: autoPassEnabledKey) }
  }

  public static var autoFlipEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: autoFlipEnabledKey) }
    set { UserDefaults.standard.set(newValue, forKey: autoFlipEnabledKey) }
  }

  public static var numpadHotkeysEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: numpadHotkeysEnabledKey) }
    set { UserDefaults.standard.set(newValue, forKey: numpadHotkeysEnabledKey) }
  }

  public static var reviewFeedbackEffectsEnabled: Bool {
    get {
      if UserDefaults.standard.object(forKey: reviewFeedbackEffectsEnabledKey) == nil { return true }
      return UserDefaults.standard.bool(forKey: reviewFeedbackEffectsEnabledKey)
    }
    set { UserDefaults.standard.set(newValue, forKey: reviewFeedbackEffectsEnabledKey) }
  }

  public static let autoFlipDelayMin: Double = 0.2
  public static let autoFlipDelayMax: Double = 10
  public static let autoFlipDelayDefault: Double = 5

  public static var autoFlipDelay: Double {
    get {
      let val = UserDefaults.standard.double(forKey: autoFlipDelayKey)
      guard val > 0 else { return autoFlipDelayDefault }
      return max(autoFlipDelayMin, min(autoFlipDelayMax, val))
    }
    set {
      let clamped = max(autoFlipDelayMin, min(autoFlipDelayMax, newValue))
      UserDefaults.standard.set(clamped, forKey: autoFlipDelayKey)
    }
  }

  public static var autoPassDelay: Double {
    get {
      let val = UserDefaults.standard.double(forKey: autoPassDelayKey)
      guard val > 0 else { return autoPassDelayDefault }
      return max(autoPassDelayMin, min(autoPassDelayMax, val))
    }
    set {
      let clamped = max(autoPassDelayMin, min(autoPassDelayMax, newValue))
      UserDefaults.standard.set(clamped, forKey: autoPassDelayKey)
    }
  }

  public static var llmGradingPrompt: String {
    get {
      cached.llmGradingPrompt.isEmpty ? llmGradingPromptDefault : cached.llmGradingPrompt
    }
    set { cached.llmGradingPrompt = newValue }
  }

  public static var syncIntervalSeconds: Int {
    get { max(10, cached.syncIntervalSeconds) }
    set { cached.syncIntervalSeconds = max(10, newValue) }
  }

  private static let clipPrefetchCountKey = "MSRS.clipPrefetchCount"
  public static let clipPrefetchCountDefault: Int = 2
  public static let clipPrefetchCountMin: Int = 0
  public static let clipPrefetchCountMax: Int = 10

  public static var clipPrefetchCount: Int {
    get {
      let val = UserDefaults.standard.integer(forKey: clipPrefetchCountKey)
      guard val > 0 else { return clipPrefetchCountDefault }
      return max(clipPrefetchCountMin, min(clipPrefetchCountMax, val))
    }
    set {
      let clamped = max(clipPrefetchCountMin, min(clipPrefetchCountMax, newValue))
      UserDefaults.standard.set(clamped, forKey: clipPrefetchCountKey)
    }
  }

  private static let reviewTranscriptFontSizeKey = "MSRS.reviewTranscriptFontSize"
  private static let reviewTranslationFontSizeKey = "MSRS.reviewTranslationFontSize"

  public static let reviewTranscriptFontSizeMin: CGFloat = 14
  public static let reviewTranscriptFontSizeMax: CGFloat = 72
  #if targetEnvironment(macCatalyst)
  public static let reviewTranscriptFontSizeDefault: CGFloat = 56
  #else
  public static let reviewTranscriptFontSizeDefault: CGFloat = 28
  #endif

  public static let reviewTranslationFontSizeMin: CGFloat = 10
  public static let reviewTranslationFontSizeMax: CGFloat = 48
  public static let reviewTranslationFontSizeDefault: CGFloat = 20

  public static var reviewTranscriptFontSize: CGFloat {
    get {
      let val = UserDefaults.standard.double(forKey: reviewTranscriptFontSizeKey)
      guard val > 0 else { return reviewTranscriptFontSizeDefault }
      return CGFloat(max(Double(reviewTranscriptFontSizeMin), min(Double(reviewTranscriptFontSizeMax), val)))
    }
    set {
      let clamped = max(reviewTranscriptFontSizeMin, min(reviewTranscriptFontSizeMax, newValue))
      UserDefaults.standard.set(Double(clamped), forKey: reviewTranscriptFontSizeKey)
    }
  }

  public static var reviewTranslationFontSize: CGFloat {
    get {
      let val = UserDefaults.standard.double(forKey: reviewTranslationFontSizeKey)
      guard val > 0 else { return reviewTranslationFontSizeDefault }
      return CGFloat(max(Double(reviewTranslationFontSizeMin), min(Double(reviewTranslationFontSizeMax), val)))
    }
    set {
      let clamped = max(reviewTranslationFontSizeMin, min(reviewTranslationFontSizeMax, newValue))
      UserDefaults.standard.set(Double(clamped), forKey: reviewTranslationFontSizeKey)
    }
  }

  private static let videoEndSoundVolumeKey = "MSRS.videoEndSoundVolume"
  public static let videoEndSoundVolumeMin: Double = 0
  public static let videoEndSoundVolumeMax: Double = 1.0
  public static let videoEndSoundVolumeDefault: Double = 0.2

  public static var videoEndSoundVolume: Double {
    get {
      if UserDefaults.standard.object(forKey: videoEndSoundVolumeKey) == nil { return videoEndSoundVolumeDefault }
      let val = UserDefaults.standard.double(forKey: videoEndSoundVolumeKey)
      return max(videoEndSoundVolumeMin, min(videoEndSoundVolumeMax, val))
    }
    set {
      let clamped = max(videoEndSoundVolumeMin, min(videoEndSoundVolumeMax, newValue))
      UserDefaults.standard.set(clamped, forKey: videoEndSoundVolumeKey)
    }
  }

  private static let loopGapDelayKey = "MSRS.loopGapDelay"
  public static let loopGapDelayMin: Double = 0
  public static let loopGapDelayMax: Double = 2.0
  public static let loopGapDelayDefault: Double = 0.5

  public static var loopGapDelay: Double {
    get {
      if UserDefaults.standard.object(forKey: loopGapDelayKey) == nil { return loopGapDelayDefault }
      let val = UserDefaults.standard.double(forKey: loopGapDelayKey)
      return max(loopGapDelayMin, min(loopGapDelayMax, val))
    }
    set {
      let clamped = max(loopGapDelayMin, min(loopGapDelayMax, newValue))
      UserDefaults.standard.set(clamped, forKey: loopGapDelayKey)
    }
  }

  public static let candidatePlayDelayDefault: Double = 0
  public static let candidatePlayDelayMin: Double = 0
  public static let candidatePlayDelayMax: Double = 1

  public static var candidatePlayDelay: Double {
    get { max(candidatePlayDelayMin, min(candidatePlayDelayMax, cached.candidatePlayDelay)) }
    set { cached.candidatePlayDelay = max(candidatePlayDelayMin, min(candidatePlayDelayMax, newValue)) }
  }
}
