import AVFoundation

@MainActor
public enum ReviewSoundPlayer {

  public enum Sound: String {
    case showCard = "show-card"
    case failCard = "fail-card"
    case passCard = "success-card"
  }

  private static var players: [Sound: AVAudioPlayer] = [:]

  public static func play(_ sound: Sound) {
    if let cached = players[sound] {
      cached.currentTime = 0
      cached.play()
      return
    }
    guard let url = Bundle.module.url(forResource: sound.rawValue, withExtension: "mp3") else {
      assertionFailure("Missing sound file: \(sound.rawValue).mp3")
      return
    }
    guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
    player.volume = 0.2
    player.prepareToPlay()
    player.play()
    players[sound] = player
  }
}
