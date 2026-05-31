import UIKit

public struct HighlightableTranscriptLabeledRange: Equatable, Sendable {
  public let range: NSRange
  public let termID: Int64
  /// True if the word is "known" per `KnownJapaneseTermService` — drives a different overlay color
  /// so the reader can spot what's already mastered vs. still being learned.
  public let isKnown: Bool

  public init(range: NSRange, termID: Int64, isKnown: Bool = false) {
    self.range = range
    self.termID = termID
    self.isKnown = isKnown
  }
}

/// Non-editable, non-scrolling text view that draws per-labeled-range rounded-rect overlays
/// (one overlay per line fragment a range spans) so word boundaries are visually distinct.
/// Tap a highlighted character → onTermTapped fires with the term ID stored on that range.
public final class HighlightableTranscriptView: UITextView {

  public static let termIDAttributeKey = NSAttributedString.Key("MSRS.HighlightableTranscriptView.termID")

  public var onTermTapped: ((Int64) -> Void)?

  public var transcriptFont: UIFont = .preferredFont(forTextStyle: .title3) {
    didSet { renderCurrent() }
  }

  public var highlightFillColor: UIColor = UIColor.systemYellow.withAlphaComponent(0.18)
  public var highlightBorderColor: UIColor = UIColor.systemOrange
  public var knownHighlightFillColor: UIColor = UIColor.systemGreen.withAlphaComponent(0.20)
  public var knownHighlightBorderColor: UIColor = UIColor.systemGreen
  public var selectedHighlightFillColor: UIColor = UIColor.systemBlue.withAlphaComponent(0.32)
  public var selectedHighlightBorderColor: UIColor = UIColor.systemBlue
  public var highlightBorderWidth: CGFloat = 1.5
  public var highlightCornerRadius: CGFloat = 6
  public var highlightInset: CGFloat = -2

  /// When non-nil, the matching range is drawn with the selected-highlight palette. Drives
  /// the "you tapped THIS word" visual feedback the dictionary popup is positioned against.
  public var selectedTermID: Int64? {
    didSet {
      if oldValue != selectedTermID { redrawHighlightOverlays() }
    }
  }

  private var currentText: String = ""
  private var currentLabeledRanges: [HighlightableTranscriptLabeledRange] = []
  private var highlightLayers: [CAShapeLayer] = []
  private var lastBoundsForOverlay: CGRect = .zero

  // Hold strong refs to the TextKit 1 stack we install at init.
  private let installedLayoutManager: NSLayoutManager
  private let installedTextContainer: NSTextContainer

  public init() {
    let textStorage = NSTextStorage()
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let container = NSTextContainer(size: .zero)
    container.widthTracksTextView = true
    layoutManager.addTextContainer(container)

    self.installedLayoutManager = layoutManager
    self.installedTextContainer = container

    super.init(frame: .zero, textContainer: container)

    isEditable = false
    isScrollEnabled = false
    isSelectable = false
    backgroundColor = .clear
    textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    self.textContainer.lineFragmentPadding = 0

    let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    addGestureRecognizer(tap)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    if bounds != lastBoundsForOverlay {
      lastBoundsForOverlay = bounds
      redrawHighlightOverlays()
    }
  }

  public func setTranscript(
    text: String,
    labeledRanges: [HighlightableTranscriptLabeledRange]
  ) {
    self.currentText = text
    self.currentLabeledRanges = labeledRanges
    renderCurrent()
  }

  /// Returns the union of the glyph rects covering `termID`'s range, converted into
  /// `containerView`'s coordinate space. Use this to position a popup relative to the
  /// actually-tapped word.
  public func boundingFrameForTermID(_ termID: Int64, in containerView: UIView) -> CGRect? {
    guard let labeled = currentLabeledRanges.first(where: { $0.termID == termID }) else { return nil }
    return boundingFrameForRange(labeled.range, in: containerView)
  }

  private func boundingFrameForRange(_ range: NSRange, in containerView: UIView) -> CGRect? {
    let attrLength = attributedText.length
    let safeRange = NSRange(
      location: max(0, range.location),
      length: min(range.length, attrLength - max(0, range.location))
    )
    guard safeRange.length > 0 else { return nil }

    installedLayoutManager.ensureLayout(for: installedTextContainer)
    let glyphRange = installedLayoutManager.glyphRange(forCharacterRange: safeRange, actualCharacterRange: nil)

    var unionRect: CGRect = .null
    installedLayoutManager.enumerateEnclosingRects(
      forGlyphRange: glyphRange,
      withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
      in: installedTextContainer
    ) { [weak self] rect, _ in
      guard let self = self else { return }
      let adjusted = rect.offsetBy(dx: self.textContainerInset.left, dy: self.textContainerInset.top)
      unionRect = unionRect.union(adjusted)
    }
    guard !unionRect.isNull else { return nil }
    return convert(unionRect, to: containerView)
  }

  private func renderCurrent() {
    let attributed = NSMutableAttributedString(
      string: currentText,
      attributes: [
        .font: transcriptFont,
        .foregroundColor: UIColor.label,
      ]
    )
    let totalLength = attributed.length
    for labeled in currentLabeledRanges {
      let safeRange = NSRange(
        location: max(0, labeled.range.location),
        length: min(labeled.range.length, totalLength - max(0, labeled.range.location))
      )
      guard safeRange.length > 0,
            safeRange.location + safeRange.length <= totalLength
      else { continue }
      attributed.addAttribute(
        Self.termIDAttributeKey,
        value: NSNumber(value: labeled.termID),
        range: safeRange
      )
    }
    self.attributedText = attributed
    setNeedsLayout()
    DispatchQueue.main.async { [weak self] in
      self?.redrawHighlightOverlays()
    }
  }

  private func redrawHighlightOverlays() {
    highlightLayers.forEach { $0.removeFromSuperlayer() }
    highlightLayers.removeAll()

    let attrLength = attributedText.length
    guard attrLength > 0 else { return }

    installedLayoutManager.ensureLayout(for: installedTextContainer)

    for labeled in currentLabeledRanges {
      let safeRange = NSRange(
        location: max(0, labeled.range.location),
        length: min(labeled.range.length, attrLength - max(0, labeled.range.location))
      )
      guard safeRange.length > 0 else { continue }

      let glyphRange = installedLayoutManager.glyphRange(forCharacterRange: safeRange, actualCharacterRange: nil)
      let isSelected = (selectedTermID == labeled.termID)

      installedLayoutManager.enumerateEnclosingRects(
        forGlyphRange: glyphRange,
        withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
        in: installedTextContainer
      ) { [weak self] rect, _ in
        guard let self = self else { return }
        let adjustedRect = rect
          .offsetBy(dx: self.textContainerInset.left, dy: self.textContainerInset.top)
          .insetBy(dx: self.highlightInset, dy: self.highlightInset)

        let shapeLayer = CAShapeLayer()
        let path = UIBezierPath(roundedRect: adjustedRect, cornerRadius: self.highlightCornerRadius)
        shapeLayer.path = path.cgPath
        if isSelected {
          shapeLayer.fillColor = self.selectedHighlightFillColor.cgColor
          shapeLayer.strokeColor = self.selectedHighlightBorderColor.cgColor
          shapeLayer.lineWidth = self.highlightBorderWidth + 1
        } else if labeled.isKnown {
          shapeLayer.fillColor = self.knownHighlightFillColor.cgColor
          shapeLayer.strokeColor = self.knownHighlightBorderColor.cgColor
          shapeLayer.lineWidth = self.highlightBorderWidth
        } else {
          shapeLayer.fillColor = self.highlightFillColor.cgColor
          shapeLayer.strokeColor = self.highlightBorderColor.cgColor
          shapeLayer.lineWidth = self.highlightBorderWidth
        }

        self.layer.insertSublayer(shapeLayer, at: 0)
        self.highlightLayers.append(shapeLayer)
      }
    }
  }

  @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
    let location = gesture.location(in: self)
    let pointInTextContainer = CGPoint(
      x: location.x - textContainerInset.left,
      y: location.y - textContainerInset.top
    )
    installedLayoutManager.ensureLayout(for: installedTextContainer)
    let glyphIndex = installedLayoutManager.glyphIndex(for: pointInTextContainer, in: installedTextContainer)
    let charIndex = installedLayoutManager.characterIndexForGlyph(at: glyphIndex)

    guard charIndex >= 0, charIndex < attributedText.length else { return }
    if let value = attributedText.attribute(
      Self.termIDAttributeKey,
      at: charIndex,
      effectiveRange: nil
    ) as? NSNumber {
      onTermTapped?(value.int64Value)
    }
  }
}
