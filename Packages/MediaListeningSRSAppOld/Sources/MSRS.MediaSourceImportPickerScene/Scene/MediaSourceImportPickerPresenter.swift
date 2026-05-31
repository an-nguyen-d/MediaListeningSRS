import UIKit
import JML_JMLSharedModels
import MSRS_SharedModels

@MainActor
protocol MediaSourceImportPickerDisplayer: AnyObject {
  func displayState(_ state: MediaSourceImportPickerModels.DisplayState)
  func displayImportError(_ message: String)
  func displayImportSucceeded(createdSourceID: MediaSourceModel.ID, candidateCount: Int)
  func displayNavigateToEpisodePicker(seriesID: TVShowSeriesModel.ID, seriesTitle: String)
}

@MainActor
final class MediaSourceImportPickerPresenter {

  weak var displayer: MediaSourceImportPickerDisplayer!

  func presentState(_ state: MediaSourceImportPickerModels.DisplayState) {
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

  func presentNavigateToEpisodePicker(seriesID: TVShowSeriesModel.ID, seriesTitle: String) {
    displayer?.displayNavigateToEpisodePicker(seriesID: seriesID, seriesTitle: seriesTitle)
  }
}
