import UIKit

final class DailyCardBarChartView: UIView {

  struct DayData {
    let label: String
    let count: Int
  }

  private let columnsStack = UIStackView()
  private var barViews: [UIView] = []
  private var countLabels: [UILabel] = []
  private var dayLabels: [UILabel] = []
  private var barHeightConstraints: [NSLayoutConstraint] = []

  private static let barMaxHeight: CGFloat = 140
  private static let barCornerRadius: CGFloat = 4

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
    barViews.removeAll()
    countLabels.removeAll()
    dayLabels.removeAll()
    barHeightConstraints.removeAll()

    let maxCount = data.map(\.count).max() ?? 0

    for day in data {
      let column = UIStackView()
      column.axis = .vertical
      column.alignment = .center
      column.spacing = 4

      let countLabel = UILabel()
      countLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
      countLabel.textColor = .label
      countLabel.textAlignment = .center
      countLabel.text = "\(day.count)"
      countLabels.append(countLabel)

      let bar = UIView()
      bar.backgroundColor = day.count > 0 ? .systemBlue : .systemFill
      bar.layer.cornerRadius = Self.barCornerRadius
      bar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
      bar.translatesAutoresizingMaskIntoConstraints = false
      barViews.append(bar)

      let fraction: CGFloat
      if maxCount > 0 {
        fraction = CGFloat(day.count) / CGFloat(maxCount)
      } else {
        fraction = 0
      }
      let barHeight = max(4, Self.barMaxHeight * fraction)
      let heightConstraint = bar.heightAnchor.constraint(equalToConstant: barHeight)
      heightConstraint.isActive = true
      barHeightConstraints.append(heightConstraint)

      let dayLabel = UILabel()
      dayLabel.font = .systemFont(ofSize: 11, weight: .medium)
      dayLabel.textColor = .secondaryLabel
      dayLabel.textAlignment = .center
      dayLabel.text = day.label
      dayLabels.append(dayLabel)

      column.addArrangedSubview(countLabel)
      column.addArrangedSubview(bar)
      column.addArrangedSubview(dayLabel)

      bar.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true

      columnsStack.addArrangedSubview(column)
    }
  }
}
