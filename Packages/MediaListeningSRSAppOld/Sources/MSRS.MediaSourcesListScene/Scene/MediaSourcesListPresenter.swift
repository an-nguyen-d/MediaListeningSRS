import UIKit
import MSRS_SharedModels

@MainActor
protocol MediaSourcesListDisplayer: AnyObject {
  func displayRows(_ rows: [MediaSourcesListModels.Row])
  func displayError(_ message: String)
  func displayNavigateToImportPicker()
  func displayNavigateToReviewAll()
  func displayNavigateToProcessingQueue(mediaSourceID: MediaSourceModel.ID)
}

@MainActor
final class MediaSourcesListPresenter {

  weak var displayer: MediaSourcesListDisplayer!

  func presentRows(_ rows: [MediaSourcesListModels.Row]) {
    displayer?.displayRows(rows)
  }

  func presentError(_ message: String) {
    displayer?.displayError(message)
  }

  func presentNavigateToImportPicker() {
    displayer?.displayNavigateToImportPicker()
  }

  func presentNavigateToReviewAll() {
    displayer?.displayNavigateToReviewAll()
  }

  func presentNavigateToProcessingQueue(mediaSourceID: MediaSourceModel.ID) {
    displayer?.displayNavigateToProcessingQueue(mediaSourceID: mediaSourceID)
  }
}
