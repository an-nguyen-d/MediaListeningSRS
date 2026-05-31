import Foundation
import IYO_DictionaryClient
import IYO_DictionaryModels
import IYO_DictionaryUIKit
import IYO_JapaneseModels
import IYO_JapaneseTextClient

/// Maps a single `DictionaryLookupResult` (what we get from `DictionaryClient.lookupByID`)
/// into iYomi's `DictionaryLookupViewModel` so we can show the full rich popup
/// (spellings, all senses with parts-of-speech tags, frequency rank, pitch accents).
///
/// We don't have furigana/deinflection info for a single-term lookup-by-ID, so those
/// fields are passed empty — iYomi's popup handles their absence gracefully.
public enum IYomiDictionaryViewModelBridge {

  public static func makeLookupViewModel(
    from result: DictionaryLookupResult
  ) -> DictionaryLookupViewModel {
    let primarySpelling = result.spellings.first?.spelling ?? ""

    let spellings = result.spellings.map { spelling in
      DictionaryLookupViewModel.SpellingViewModel(
        id: spelling.id,
        spelling: spelling.spelling,
        isCommon: spelling.isCommonSpelling,
        appliesToKanji: spelling.appliesToKanji,
        spellingRank: spelling.spellingRank
      )
    }

    let senses = result.senses.map { sense in
      DictionaryLookupViewModel.SenseViewModel(
        meaning: sense.meaning,
        partsOfSpeechTags: sense.partsOfSpeechTags
      )
    }

    let resultVM = DictionaryLookupViewModel.ResultViewModel(
      surfaceText: primarySpelling,
      deinflectedText: primarySpelling,
      furiganaComponents: [] as [JapaneseTextClient.ParseFurigana.Response.FuriganaComponent],
      furiganaText: nil,
      spellings: spellings,
      senses: senses,
      highlightRange: nil,
      inflections: [] as [InflectionType],
      dictionaryID: Int(result.termID.rawValue),
      frequencyRank: result.frequencyRank,
      matchedTextLength: primarySpelling.utf16.count
    )

    return DictionaryLookupViewModel(results: [resultVM])
  }
}
