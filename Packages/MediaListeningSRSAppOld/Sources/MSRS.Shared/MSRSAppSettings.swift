import Foundation

public enum MSRSAppSettings {

  private static let requireConfirmationKey = "MSRS.Settings.requireSkipOrMakeCardConfirmation"
  public static let desiredRetentionKey = "MSRS.Settings.desiredRetention"
  public static let desiredRetentionDefault: Double = 0.9

  public static var requireSkipOrMakeCardConfirmation: Bool {
    get {
      if UserDefaults.standard.object(forKey: requireConfirmationKey) == nil {
        return true
      }
      return UserDefaults.standard.bool(forKey: requireConfirmationKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: requireConfirmationKey)
    }
  }

  public static var desiredRetention: Double {
    get {
      if UserDefaults.standard.object(forKey: desiredRetentionKey) == nil {
        return desiredRetentionDefault
      }
      return UserDefaults.standard.double(forKey: desiredRetentionKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: desiredRetentionKey)
    }
  }

  private static let minimumCardCoverageCountKey = "MSRS.Settings.minimumCardCoverageCount"
  public static let minimumCardCoverageCountDefault: Int = 50

  private static let showFrontTranscriptKey = "MSRS.Settings.showFrontTranscript"

  public static var showFrontTranscript: Bool {
    get {
      if UserDefaults.standard.object(forKey: showFrontTranscriptKey) == nil {
        return true
      }
      return UserDefaults.standard.bool(forKey: showFrontTranscriptKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: showFrontTranscriptKey)
    }
  }

  public static var minimumCardCoverageCount: Int {
    get {
      if UserDefaults.standard.object(forKey: minimumCardCoverageCountKey) == nil {
        return minimumCardCoverageCountDefault
      }
      let value = UserDefaults.standard.integer(forKey: minimumCardCoverageCountKey)
      return max(1, value)
    }
    set {
      UserDefaults.standard.set(max(1, newValue), forKey: minimumCardCoverageCountKey)
    }
  }

  private static let studySessionInactivityTimeoutKey = "MSRS.Settings.studySessionInactivityTimeout"
  public static let studySessionInactivityTimeoutDefault: Int = 300

  public static var studySessionInactivityTimeout: Int {
    get {
      if UserDefaults.standard.object(forKey: studySessionInactivityTimeoutKey) == nil {
        return studySessionInactivityTimeoutDefault
      }
      let value = UserDefaults.standard.integer(forKey: studySessionInactivityTimeoutKey)
      return max(30, value)
    }
    set {
      UserDefaults.standard.set(max(30, newValue), forKey: studySessionInactivityTimeoutKey)
    }
  }

  // MARK: - Video Auto-Loop

  private static let autoLoopVideoKey = "MSRS.Settings.autoLoopVideo"

  public static var autoLoopVideo: Bool {
    get { UserDefaults.standard.bool(forKey: autoLoopVideoKey) }
    set { UserDefaults.standard.set(newValue, forKey: autoLoopVideoKey) }
  }

  // MARK: - LLM Grading

  private static let llmGradingPromptKey = "MSRS.Settings.llmGradingPrompt"
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

  public static var llmGradingPrompt: String {
    get { UserDefaults.standard.string(forKey: llmGradingPromptKey) ?? llmGradingPromptDefault }
    set { UserDefaults.standard.set(newValue, forKey: llmGradingPromptKey) }
  }
}
