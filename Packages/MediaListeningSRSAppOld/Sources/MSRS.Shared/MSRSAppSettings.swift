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
    syncIntervalSeconds: syncIntervalSecondsDefault
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

  public static var autoLoopVideo: Bool {
    get { cached.autoLoopVideo }
    set { cached.autoLoopVideo = newValue }
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
}
