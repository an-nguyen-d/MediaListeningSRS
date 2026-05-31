import UIKit
import MSRS_SharedModels

@MainActor
protocol MediaSourceImportEpisodePickerDisplayer: AnyObject {
  func displayState(_ state: MediaSourceImportEpisodePickerModels.DisplayState)
  func displayImportError(_ message: String)
  func displayImportSucceeded(createdSourceID: MediaSourceModel.ID, candidateCount: Int)
}

@MainActor
final class MediaSourceImportEpisodePickerPresenter {

  weak var displayer: MediaSourceImportEpisodePickerDisplayer!

  func presentState(_ state: MediaSourceImportEpisodePickerModels.DisplayState) {
    displayer?.displayState(state)
  }

  func presentImportError(_ message: String) {
    displayer?.displayImportError(message)
  }

  func presentImportSucceeded(createdSourceID: MediaSourceModel.ID, candidateCount: Int) {
    displayer?.displayImportSucceeded(
      createdSourceID: createdSourceID,
      candidateCount: candidateCount
    )
  }
}
