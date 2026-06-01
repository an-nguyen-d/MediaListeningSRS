import UIKit
import MSRS_SharedModels

@MainActor
protocol ProcessingQueueDisplayer: AnyObject {
  func displayTitle(_ title: String)
  func displayRows(_ rows: [ProcessingQueueModels.Row], totalCandidateCount: Int)
  func displayError(_ message: String)
  func displayNavigateToCandidateDetail(
    candidateID: MediaSourceCardCandidateModel.ID,
    mediaSourceID: MediaSourceModel.ID
  )
}

@MainActor
final class ProcessingQueuePresenter {

  weak var displayer: ProcessingQueueDisplayer!

  func presentTitle(_ title: String) {
    displayer?.displayTitle(title)
  }

  func presentRows(_ rows: [ProcessingQueueModels.Row], totalCandidateCount: Int) {
    displayer?.displayRows(rows, totalCandidateCount: totalCandidateCount)
  }

  func presentError(_ message: String) {
    displayer?.displayError(message)
  }

  func presentNavigateToCandidateDetail(
    candidateID: MediaSourceCardCandidateModel.ID,
    mediaSourceID: MediaSourceModel.ID
  ) {
    displayer?.displayNavigateToCandidateDetail(
      candidateID: candidateID,
      mediaSourceID: mediaSourceID
    )
  }
}
