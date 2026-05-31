import UIKit
import MSRS_SharedModels

@MainActor
protocol ProcessingQueueDisplayer: AnyObject {
  func displayRows(_ rows: [ProcessingQueueModels.Row])
  func displayError(_ message: String)
  func displayNavigateToCandidateDetail(
    candidateID: MediaSourceCardCandidateModel.ID,
    mediaSourceID: MediaSourceModel.ID
  )
}

@MainActor
final class ProcessingQueuePresenter {

  weak var displayer: ProcessingQueueDisplayer!

  func presentRows(_ rows: [ProcessingQueueModels.Row]) {
    displayer?.displayRows(rows)
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
