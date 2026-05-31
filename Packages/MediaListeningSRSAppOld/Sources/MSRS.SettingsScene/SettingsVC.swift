import UIKit
import MSRS_Shared

public final class SettingsVC: UIViewController {

  private let tableView = UITableView(frame: .zero, style: .insetGrouped)
  private var retentionSlider: UISlider?
  private var retentionValueLabel: UILabel?

  public init() {
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    title = "Settings"
    view.backgroundColor = .systemGroupedBackground
    tableView.dataSource = self
    tableView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }

  @objc private func confirmationToggleChanged(_ sender: UISwitch) {
    MSRSAppSettings.requireSkipOrMakeCardConfirmation = sender.isOn
  }

  @objc private func retentionSliderChanged(_ sender: UISlider) {
    let rounded = (Double(sender.value) * 100).rounded() / 100
    MSRSAppSettings.desiredRetention = rounded
    retentionValueLabel?.text = formatRetention(rounded)
  }

  private func formatRetention(_ value: Double) -> String {
    "\(Int(value * 100))%"
  }
}

extension SettingsVC: UITableViewDataSource {

  public func numberOfSections(in tableView: UITableView) -> Int { 2 }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

  public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
    case 0: return "Processing Queue"
    case 1: return "SRS Scheduling"
    default: return nil
    }
  }

  public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    switch section {
    case 0:
      return "When enabled, a confirmation popup appears before skipping or making a card."
    case 1:
      return "Lower retention = longer intervals between reviews (more aggressive). Higher retention = shorter intervals (more conservative). Default is 90%. Takes effect on the next review of each card."
    default:
      return nil
    }
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {
    case 0:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.textLabel?.text = "Require Confirmation"
      cell.selectionStyle = .none
      let toggle = UISwitch()
      toggle.isOn = MSRSAppSettings.requireSkipOrMakeCardConfirmation
      toggle.addTarget(self, action: #selector(confirmationToggleChanged(_:)), for: .valueChanged)
      cell.accessoryView = toggle
      return cell

    case 1:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = ""

      let currentRetention = MSRSAppSettings.desiredRetention

      let label = UILabel()
      label.text = "Desired Retention"
      label.font = .preferredFont(forTextStyle: .body)
      label.setContentHuggingPriority(.required, for: .horizontal)

      let valueLabel = UILabel()
      valueLabel.text = formatRetention(currentRetention)
      valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
      valueLabel.textAlignment = .right
      valueLabel.setContentHuggingPriority(.required, for: .horizontal)
      retentionValueLabel = valueLabel

      let slider = UISlider()
      slider.minimumValue = 0.70
      slider.maximumValue = 0.97
      slider.value = Float(currentRetention)
      slider.addTarget(self, action: #selector(retentionSliderChanged(_:)), for: .valueChanged)
      retentionSlider = slider

      let topRow = UIStackView(arrangedSubviews: [label, valueLabel])
      topRow.axis = .horizontal
      topRow.spacing = 8

      let stack = UIStackView(arrangedSubviews: [topRow, slider])
      stack.axis = .vertical
      stack.spacing = 8
      stack.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
        stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
        stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
      ])
      return cell

    default:
      return UITableViewCell()
    }
  }
}
