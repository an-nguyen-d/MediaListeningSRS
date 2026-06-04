import UIKit

final class DailyTimeBarChartView: UIView {

  struct SessionSegment {
    let duration: TimeInterval
  }

  struct DayData {
    let label: String
    let sessions: [SessionSegment]
    var totalDuration: TimeInterval { sessions.reduce(0) { $0 + $1.duration } }
  }

  private let columnsStack = UIStackView()

  private static let barMaxHeight: CGFloat = 140
  private static let barCornerRadius: CGFloat = 4
  private static let segmentSpacing: CGFloat = 1

  private static let segmentColors: [UIColor] = [
    .systemGreen,
    UIColor.systemGreen.withAlphaComponent(0.6),
    .systemTeal,
    UIColor.systemTeal.withAlphaComponent(0.6),
  ]

  override init(frame: CGRect) {
    super.init(frame: frame)
    columnsStack.axis = .horizontal
    columnsStack.distribution = .fillEqually
    columnsStack.alignment = .bottom
    columnsStack.spacing = 8
    columnsStack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(columnsStack)
    NSLayoutConstraint.activate([
      columnsStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      columnsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
      columnsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
      columnsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  func setData(_ data: [DayData]) {
    columnsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

    let maxTotal = data.map(\.totalDuration).max() ?? 0

    for day in data {
      let column = UIStackView()
      column.axis = .vertical
      column.alignment = .center
      column.spacing = 4

      let timeLabel = UILabel()
      timeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
      timeLabel.textColor = .label
      timeLabel.textAlignment = .center
      timeLabel.text = Self.formatDuration(day.totalDuration)
      timeLabel.adjustsFontSizeToFitWidth = true
      timeLabel.minimumScaleFactor = 0.7

      let barContainer = UIView()
      barContainer.translatesAutoresizingMaskIntoConstraints = false
      barContainer.clipsToBounds = true
      barContainer.layer.cornerRadius = Self.barCornerRadius
      barContainer.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

      let totalFraction: CGFloat = maxTotal > 0
        ? CGFloat(day.totalDuration / maxTotal)
        : 0
      let totalBarHeight = max(4, Self.barMaxHeight * totalFraction)
      barContainer.heightAnchor.constraint(equalToConstant: totalBarHeight).isActive = true

      if day.sessions.isEmpty || day.totalDuration == 0 {
        barContainer.backgroundColor = .systemFill
      } else {
        let spacingTotal = CGFloat(max(0, day.sessions.count - 1)) * Self.segmentSpacing
        let availableHeight = totalBarHeight - spacingTotal

        var currentBottomAnchor = barContainer.bottomAnchor
        for (i, session) in day.sessions.enumerated() {
          let segmentView = UIView()
          segmentView.translatesAutoresizingMaskIntoConstraints = false
          segmentView.backgroundColor = Self.segmentColors[i % Self.segmentColors.count]
          barContainer.addSubview(segmentView)

          let segmentHeight = CGFloat(session.duration / day.totalDuration) * availableHeight

          NSLayoutConstraint.activate([
            segmentView.leadingAnchor.constraint(equalTo: barContainer.leadingAnchor),
            segmentView.trailingAnchor.constraint(equalTo: barContainer.trailingAnchor),
            segmentView.bottomAnchor.constraint(
              equalTo: currentBottomAnchor,
              constant: i == 0 ? 0 : -Self.segmentSpacing
            ),
            segmentView.heightAnchor.constraint(equalToConstant: max(2, segmentHeight)),
          ])

          currentBottomAnchor = segmentView.topAnchor
        }
      }

      let dayLabel = UILabel()
      dayLabel.font = .systemFont(ofSize: 11, weight: .medium)
      dayLabel.textColor = .secondaryLabel
      dayLabel.textAlignment = .center
      dayLabel.text = day.label

      column.addArrangedSubview(timeLabel)
      column.addArrangedSubview(barContainer)
      column.addArrangedSubview(dayLabel)

      barContainer.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true

      columnsStack.addArrangedSubview(column)
    }
  }

  private static func formatDuration(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    if hours > 0 {
      return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    } else if minutes > 0 {
      return "\(minutes)m"
    } else if totalSeconds > 0 {
      return "\(totalSeconds)s"
    } else {
      return "—"
    }
  }
}
