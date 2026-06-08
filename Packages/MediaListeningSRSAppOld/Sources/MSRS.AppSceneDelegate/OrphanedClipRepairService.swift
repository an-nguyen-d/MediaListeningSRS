import Foundation
import JML_JMLDatabaseClient
import MSRS_ClipExportService
import MSRS_ClipStorageClient
import MSRS_MediaListeningSRSDatabaseClient
import MSRS_SharedModels

#if targetEnvironment(macCatalyst)
enum OrphanedClipRepairService {

  static func repairIfNeeded(
    mediaListeningSRSDatabaseClient: MediaListeningSRSDatabaseClient,
    jmlDatabaseClient: JMLDatabaseClient,
    clipExportService: ClipExportService,
    clipStorageClient: ClipStorageClient,
    exportedClipsDirectoryURL: URL
  ) async {
    let orphanedCards: [SRSCardModel]
    do {
      let response = try await mediaListeningSRSDatabaseClient.srsCard.fetchCardsWithEmptyClipPath(.init())
      orphanedCards = response.cards
    } catch {
      print("[OrphanedClipRepair] Failed to fetch orphaned cards: \(error)")
      return
    }

    guard !orphanedCards.isEmpty else { return }

    print("[OrphanedClipRepair] Found \(orphanedCards.count) cards with empty clip paths — repairing")

    let cardsBySource = Dictionary(grouping: orphanedCards) { $0.mediaSourceID }

    for (mediaSourceID, cards) in cardsBySource {
      let videoURL: URL
      do {
        let sourceResponse = try await mediaListeningSRSDatabaseClient.mediaSource.fetch(.init(id: mediaSourceID))
        videoURL = try await resolveVideoURL(
          for: sourceResponse.model.jmlMediaReference,
          jmlDatabaseClient: jmlDatabaseClient
        )
      } catch {
        print("[OrphanedClipRepair] Failed to resolve video for source \(mediaSourceID.rawValue): \(error)")
        continue
      }

      for card in cards {
        let outputFileURL = exportedClipsDirectoryURL
          .appendingPathComponent("\(mediaSourceID.rawValue)", isDirectory: true)
          .appendingPathComponent("\(UUID().uuidString).mp4", isDirectory: false)

        let cardID = card.id
        await ClipExportManager.shared.enqueue(
          request: .init(
            sourceVideoFileURL: videoURL,
            startTimeSeconds: card.clipStartTimeSeconds,
            endTimeSeconds: card.clipEndTimeSeconds,
            outputFileURL: outputFileURL
          ),
          exportClip: clipExportService.exportClip,
          onComplete: { [clipStorageClient, exportedClipsDirectoryURL] exportedFileURL in
            let relativePath = exportedFileURL.path.replacingOccurrences(
              of: exportedClipsDirectoryURL.path,
              with: ""
            ).trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            do {
              _ = try await mediaListeningSRSDatabaseClient.srsCard.updateClipPath(.init(
                cardID: cardID,
                clipRelativeFilePath: relativePath
              ))
              print("[OrphanedClipRepair] Repaired card \(cardID.rawValue)")
            } catch {
              print("[OrphanedClipRepair] DB update failed for card \(cardID.rawValue): \(error)")
              return
            }

            let remotePath = "clips/\(relativePath)"
            do {
              _ = try await clipStorageClient.upload(.init(
                localFileURL: exportedFileURL,
                remotePath: remotePath
              ))
            } catch {
              print("[OrphanedClipRepair] Upload failed for \(remotePath): \(error)")
            }

            let thumbnailURL = exportedFileURL.deletingPathExtension().appendingPathExtension("jpg")
            if FileManager.default.fileExists(atPath: thumbnailURL.path) {
              let thumbRemotePath = "clips/\(relativePath.replacingOccurrences(of: ".mp4", with: ".jpg"))"
              do {
                _ = try await clipStorageClient.upload(.init(
                  localFileURL: thumbnailURL,
                  remotePath: thumbRemotePath
                ))
              } catch {
                print("[OrphanedClipRepair] Thumbnail upload failed: \(error)")
              }
            }
          }
        )
      }
    }

    await ClipExportManager.shared.waitUntilDrained()
    print("[OrphanedClipRepair] Repair complete — \(orphanedCards.count) cards processed")
  }

  private static func resolveVideoURL(
    for reference: MediaSourceModel.JMLMediaReference,
    jmlDatabaseClient: JMLDatabaseClient
  ) async throws -> URL {
    switch reference {
    case .movie(let movieID):
      guard let movie = try await jmlDatabaseClient.movie.fetch(.init(id: movieID)),
            let videoURL = movie.japaneseVideoLocalURL else {
        throw NSError(
          domain: "OrphanedClipRepair",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Movie video URL missing"]
        )
      }
      return videoURL
    case .episode(let episodeID):
      guard let episode = try await jmlDatabaseClient.tvShowEpisode.fetch(.init(id: episodeID)),
            let videoURL = episode.japaneseVideoLocalURL else {
        throw NSError(
          domain: "OrphanedClipRepair",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Episode video URL missing"]
        )
      }
      return videoURL
    }
  }
}
#endif
