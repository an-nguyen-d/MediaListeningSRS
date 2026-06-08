import UIKit
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_SharedModels

public final class StudyStatsVC: UIViewController {

  public typealias Dependencies = HasMediaListeningSRSDatabaseClient

  private let dbClient: MediaListeningSRSDatabaseClient
  private let tableView = UITableView(frame: .zero, style: .insetGrouped)

  private var liveStateCounts: MediaListeningSRSDatabaseClient.SRSCard.FetchCardStateCounts.Response?
  private var todayDuration: TimeInterval = 0
  private var todayCards: Int = 0
  private var todaySessions: Int = 0
  private var last7DaysData: [DailyCardBarChartView.DayData] = []
  private var last7DaysTimeData: [DailyTimeBarChartView.DayData] = []
  private var recentSessions: [StudySessionModel] = []
  private var recentReviewEvents: [MediaListeningSRSDatabaseClient.SRSCard.RecentReviewEvent] = []
  private var latestSnapshot: DailyAggregateSnapshotModel?
  private var recentSnapshots: [DailyAggregateSnapshotModel] = []

  private let barChartView = DailyCardBarChartView()
  private let timeBarChartView = DailyTimeBarChartView()

  public init(dependencies: Dependencies) {
    self.dbClient = dependencies.mediaListeningSRSDatabaseClient
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    title = "Study Stats"
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

    loadData()
  }

  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    loadData()
  }

  private func loadData() {
    let calendar = Calendar.current
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

    let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday)!
    let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: startOfToday)!

    let snapshotDateFormatter = Self.snapshotDateFormatter
    let dayOfWeekFormatter = Self.dayOfWeekFormatter

    Task { [dbClient] in
      do {
        let todayResponse = try await dbClient.studySession.fetchInDateRange(
          .init(startDate: startOfToday, endDate: endOfToday)
        )
        let recentResponse = try await dbClient.studySession.fetchInDateRange(
          .init(startDate: thirtyDaysAgo, endDate: endOfToday)
        )

        let todayDateString = snapshotDateFormatter.string(from: now)
        let thirtyDaysAgoString = snapshotDateFormatter.string(from: thirtyDaysAgo)
        let snapshotsResponse = try await dbClient.dailySnapshot.fetchAggregatesInDateRange(
          .init(startDate: thirtyDaysAgoString, endDate: todayDateString)
        )

        let recentModels = recentResponse.models
        var dailyCounts: [Date: Int] = [:]
        for session in recentModels {
          let dayStart = calendar.startOfDay(for: session.startedAt)
          dailyCounts[dayStart, default: 0] += session.cardsReviewed
        }
        var chartData: [DailyCardBarChartView.DayData] = []
        var dailySessionDurations: [Date: [TimeInterval]] = [:]
        for session in recentModels {
          let dayStart = calendar.startOfDay(for: session.startedAt)
          let duration = session.endedAt.timeIntervalSince(session.startedAt)
          dailySessionDurations[dayStart, default: []].append(duration)
        }
        var timeChartData: [DailyTimeBarChartView.DayData] = []
        for offset in 0..<7 {
          let day = calendar.date(byAdding: .day, value: offset, to: sevenDaysAgo)!
          let label = dayOfWeekFormatter.string(from: day)
          let count = dailyCounts[day] ?? 0
          chartData.append(.init(label: label, count: count))
          let sessions = (dailySessionDurations[day] ?? [])
            .map { DailyTimeBarChartView.SessionSegment(duration: $0) }
          timeChartData.append(.init(label: label, sessions: sessions))
        }

        let recentReviewsResponse = try await dbClient.srsCard.fetchRecentReviewEvents(
          .init(limit: 10)
        )

        let liveCountsResponse = try await dbClient.srsCard.fetchCardStateCounts(
          .init(asOf: now)
        )

        await MainActor.run {
          self.liveStateCounts = liveCountsResponse
          self.todayDuration = todayResponse.models.reduce(0) {
            $0 + $1.endedAt.timeIntervalSince($1.startedAt)
          }
          self.todayCards = todayResponse.models.reduce(0) { $0 + $1.cardsReviewed }
          self.todaySessions = todayResponse.models.count

          self.last7DaysData = chartData
          self.barChartView.setData(chartData)

          self.last7DaysTimeData = timeChartData
          self.timeBarChartView.setData(timeChartData)

          self.recentSessions = Array(recentModels.reversed().prefix(10))
          self.recentReviewEvents = recentReviewsResponse.events

          let snapshots = snapshotsResponse.models
          self.latestSnapshot = snapshots.last
          self.recentSnapshots = Array(snapshots.reversed())

          self.tableView.reloadData()
        }
      } catch {
        // Best-effort display
      }
    }
  }

  private func formatDuration(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hours > 0 {
      return String(format: "%dh %02dm", hours, minutes)
    } else if minutes > 0 {
      return String(format: "%dm %02ds", minutes, secs)
    } else {
      return "\(secs)s"
    }
  }

  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()

  private static let timeOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .none
    f.timeStyle = .short
    return f
  }()

  private static let snapshotDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()

  private static let dayOfWeekFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE"
    return f
  }()

  private static let relativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .short
    return f
  }()
}

extension StudyStatsVC: UITableViewDataSource {

  public func numberOfSections(in tableView: UITableView) -> Int { 8 }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0: return liveStateCounts != nil ? 7 : 1
    case 1: return 3
    case 2: return 1
    case 3: return 1
    case 4: return max(recentSessions.count, 1)
    case 5: return max(recentReviewEvents.count, 1)
    case 6: return latestSnapshot != nil ? 5 : 1
    case 7: return max(recentSnapshots.count, 1)
    default: return 0
    }
  }

  public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
    case 0: return "Deck Overview (Live)"
    case 1: return "Today"
    case 2: return "Cards Reviewed (Last 7 Days)"
    case 3: return "Time Studied (Last 7 Days)"
    case 4: return "Recent Sessions"
    case 5: return "Recent Reviews"
    case 6: return "Deck Snapshot (Latest)"
    case 7: return "Snapshot History (30 days)"
    default: return nil
    }
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {
    case 0:
      guard let counts = liveStateCounts else {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "Loading..."
        cell.textLabel?.textColor = .secondaryLabel
        cell.selectionStyle = .none
        return cell
      }
      let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
      cell.selectionStyle = .none
      switch indexPath.row {
      case 0:
        cell.textLabel?.text = "Total Cards"
        cell.detailTextLabel?.text = "\(counts.totalCards)"
      case 1:
        cell.textLabel?.text = "New"
        cell.detailTextLabel?.text = "\(counts.newCount)"
        cell.detailTextLabel?.textColor = .systemBlue
      case 2:
        cell.textLabel?.text = "Learning"
        cell.detailTextLabel?.text = "\(counts.learningCount)"
        cell.detailTextLabel?.textColor = .systemOrange
      case 3:
        cell.textLabel?.text = "Review"
        cell.detailTextLabel?.text = "\(counts.reviewCount)"
        cell.detailTextLabel?.textColor = .systemGreen
      case 4:
        cell.textLabel?.text = "Relearning"
        cell.detailTextLabel?.text = "\(counts.relearningCount)"
        cell.detailTextLabel?.textColor = .systemRed
      case 5:
        cell.textLabel?.text = "Suspended"
        cell.detailTextLabel?.text = "\(counts.suspendedCount)"
        cell.detailTextLabel?.textColor = .secondaryLabel
      case 6:
        cell.textLabel?.text = "Due Now"
        cell.detailTextLabel?.text = "\(counts.dueNowCount)"
        cell.detailTextLabel?.textColor = .systemPurple
      default:
        break
      }
      return cell

    case 1:
      let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
      cell.selectionStyle = .none
      switch indexPath.row {
      case 0:
        cell.textLabel?.text = "Study Time"
        cell.detailTextLabel?.text = formatDuration(todayDuration)
      case 1:
        cell.textLabel?.text = "Cards Reviewed"
        cell.detailTextLabel?.text = "\(todayCards)"
      case 2:
        cell.textLabel?.text = "Sessions"
        cell.detailTextLabel?.text = "\(todaySessions)"
      default:
        break
      }
      return cell

    case 2:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      barChartView.removeFromSuperview()
      barChartView.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(barChartView)
      NSLayoutConstraint.activate([
        barChartView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
        barChartView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 8),
        barChartView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -8),
        barChartView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
        barChartView.heightAnchor.constraint(equalToConstant: 200),
      ])
      return cell

    case 3:
      let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
      cell.selectionStyle = .none
      timeBarChartView.removeFromSuperview()
      timeBarChartView.translatesAutoresizingMaskIntoConstraints = false
      cell.contentView.addSubview(timeBarChartView)
      NSLayoutConstraint.activate([
        timeBarChartView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
        timeBarChartView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 8),
        timeBarChartView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -8),
        timeBarChartView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
        timeBarChartView.heightAnchor.constraint(equalToConstant: 200),
      ])
      return cell

    case 4:
      if recentSessions.isEmpty {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "No study sessions yet"
        cell.textLabel?.textColor = .secondaryLabel
        cell.selectionStyle = .none
        return cell
      }

      let session = recentSessions[indexPath.row]
      let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
      cell.selectionStyle = .none

      let duration = session.endedAt.timeIntervalSince(session.startedAt)
      let startStr = Self.dateFormatter.string(from: session.startedAt)
      let endStr = Self.timeOnlyFormatter.string(from: session.endedAt)
      let relativeStr = Self.relativeFormatter.localizedString(for: session.startedAt, relativeTo: Date())
      cell.textLabel?.text = "\(startStr) – \(endStr) (\(relativeStr))"
      cell.detailTextLabel?.text = "\(formatDuration(duration))  ·  \(session.cardsReviewed) cards"
      cell.detailTextLabel?.textColor = .secondaryLabel
      return cell

    case 5:
      if recentReviewEvents.isEmpty {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "No reviews yet"
        cell.textLabel?.textColor = .secondaryLabel
        cell.selectionStyle = .none
        return cell
      }
      let event = recentReviewEvents[indexPath.row]
      let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
      cell.selectionStyle = .none
      let grade = event.ratingRawValue <= 2 ? "Fail" : "Pass"
      let gradeColor: UIColor = event.ratingRawValue <= 2 ? .systemRed : .systemGreen
      let relativeStr = Self.relativeFormatter.localizedString(for: event.occurredAt, relativeTo: Date())
      let transcript = event.cachedTranscriptText.isEmpty ? "(no transcript)" : event.cachedTranscriptText
      cell.textLabel?.text = transcript
      cell.textLabel?.numberOfLines = 2
      var detail = "\(grade) · \(relativeStr)"
      if let listens = event.listenCount {
        detail += " · \(listens) listen\(listens == 1 ? "" : "s")"
      }
      cell.detailTextLabel?.text = detail
      cell.detailTextLabel?.textColor = gradeColor
      return cell

    case 6:
      guard let snapshot = latestSnapshot else {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "No snapshots yet"
        cell.textLabel?.textColor = .secondaryLabel
        cell.selectionStyle = .none
        return cell
      }
      let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
      cell.selectionStyle = .none
      switch indexPath.row {
      case 0:
        cell.textLabel?.text = "Total Cards"
        cell.detailTextLabel?.text = "\(snapshot.totalActiveCards)"
      case 1:
        cell.textLabel?.text = "By State"
        cell.detailTextLabel?.text = "\(snapshot.newCardCount) new · \(snapshot.learningCardCount) learn · \(snapshot.reviewCardCount) review · \(snapshot.relearningCardCount) relearn"
        cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
        cell.detailTextLabel?.minimumScaleFactor = 0.7
      case 2:
        cell.textLabel?.text = "Terms Covered"
        cell.detailTextLabel?.text = "\(snapshot.totalUniqueTermsCovered)"
      case 3:
        cell.textLabel?.text = "Fully Known Terms"
        cell.detailTextLabel?.text = "\(snapshot.totalFullyKnownTerms)"
      case 4:
        cell.textLabel?.text = "Snapshot Date"
        cell.detailTextLabel?.text = snapshot.snapshotDate
      default:
        break
      }
      return cell

    case 7:
      if recentSnapshots.isEmpty {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "No snapshots yet"
        cell.textLabel?.textColor = .secondaryLabel
        cell.selectionStyle = .none
        return cell
      }
      let snapshot = recentSnapshots[indexPath.row]
      let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
      cell.selectionStyle = .none
      cell.textLabel?.text = "\(snapshot.snapshotDate)  —  \(snapshot.totalActiveCards) cards"
      cell.detailTextLabel?.text = "\(snapshot.totalUniqueTermsCovered) terms · \(snapshot.totalFullyKnownTerms) known · \(snapshot.newCardCount)N/\(snapshot.learningCardCount)L/\(snapshot.reviewCardCount)R/\(snapshot.relearningCardCount)RL"
      cell.detailTextLabel?.textColor = .secondaryLabel
      return cell

    default:
      return UITableViewCell()
    }
  }
}
