import UIKit

public struct HighlightableTranscriptLabeledRange: Equatable, Sendable {
  public let range: NSRange
  public let termID: Int64
  public let isFullyKnown: Bool
  public let inflectionKey: String

  public init(range: NSRange, termID: Int64, isFullyKnown: Bool = false, inflectionKey: String = "") {
    self.range = range
    self.termID = termID
    self.isFullyKnown = isFullyKnown
    self.inflectionKey = inflectionKey
  }
}

/// Non-editable, non-scrolling text view that draws per-labeled-range rounded-rect overlays
/// (one overlay per line fragment a range spans) so word boundaries are visually distinct.
/// Tap a highlighted character → onTermTapped fires with the term ID stored on that range.
public final class HighlightableTranscriptView: UITextView {

  public static let termIDAttributeKey = NSAttributedString.Key("MSRS.HighlightableTranscriptView.termID")

  public var onTermTapped: ((Int64) -> Void)?
  public var onCharacterTapped: ((Int) -> Void)?

  public var transcriptFont: UIFont = .preferredFont(forTextStyle: .title3) {
    didSet { renderCurrent() }
  }

  public var transcriptTextColor: UIColor = .label {
    didSet { renderCurrent() }
  }

  public var highlightColor: UIColor = .systemOrange
  public var knownHighlightColor: UIColor = .systemGreen
  public var selectedHighlightColor: UIColor = .systemBlue
  public var underlineThickness: CGFloat = 2
  public var underlineOffset: CGFloat = 2

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

  public func boundingFrameForCharacterRange(_ range: NSRange, in containerView: UIView) -> CGRect? {
    return boundingFrameForRange(range, in: containerView)
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
        .foregroundColor: transcriptTextColor,
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

        let color: UIColor
        let thickness: CGFloat
        if isSelected {
          color = self.selectedHighlightColor
          thickness = self.underlineThickness + 1
        } else if labeled.isFullyKnown {
          color = self.knownHighlightColor
          thickness = self.underlineThickness
        } else {
          color = self.highlightColor
          thickness = self.underlineThickness
        }

        let inset: CGFloat = 2
        let lineY = adjustedRect.maxY + self.underlineOffset
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: adjustedRect.minX + inset, y: lineY))
        linePath.addLine(to: CGPoint(x: adjustedRect.maxX - inset, y: lineY))

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = linePath.cgPath
        shapeLayer.strokeColor = color.cgColor
        shapeLayer.lineWidth = thickness
        shapeLayer.fillColor = nil
        shapeLayer.lineCap = .round

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
    } else {
      onCharacterTapped?(charIndex)
    }
  }
}

extension HighlightableTranscriptLabeledRange {

  public static func buildInflectionAnnotationsText(
    transcriptText: String,
    labeledRanges: [HighlightableTranscriptLabeledRange]
  ) -> String? {
    var annotations: [String] = []
    let nsText = transcriptText as NSString
    var seen = Set<Int64>()
    for labeled in labeledRanges {
      guard !labeled.inflectionKey.isEmpty else { continue }
      guard !seen.contains(labeled.termID) else { continue }
      seen.insert(labeled.termID)
      let safeRange = NSRange(
        location: max(0, labeled.range.location),
        length: min(labeled.range.length, nsText.length - max(0, labeled.range.location))
      )
      guard safeRange.length > 0 else { continue }
      let surfaceText = nsText.substring(with: safeRange)
      let readableKey = labeled.inflectionKey.replacingOccurrences(of: ".", with: " → ")
      annotations.append("\(surfaceText) [\(readableKey)]")
    }
    return annotations.isEmpty ? nil : annotations.joined(separator: "  ·  ")
  }
}
