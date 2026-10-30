import Foundation

struct VoiceSettings: Equatable {
    var pitch: Float = 0        // cents, -2400...2400
    var rate: Float = 1         // 0.5...2
    var reverb: Float = 0       // 0...100
    var echo: Float = 0         // 0...100
    var distortion: Float = 0   // 0...100
    var megaphone: Bool = false
    var volume: Float = 1       // 0...1
}

enum VoicePreset: String, CaseIterable, Identifiable {
    case normal = "Обычный"
    case megaphone = "Рупор"
    case chipmunk = "Бурундук"
    case monster = "Монстр"
    case robot = "Робот"
    case echo = "Эхо"
    case hall = "Зал"
    case slowmo = "Замедление"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .normal: "person.wave.2"
        case .megaphone: "megaphone.fill"
        case .chipmunk: "hare.fill"
        case .monster: "flame.fill"
        case .robot: "cpu"
        case .echo: "dot.radiowaves.left.and.right"
        case .hall: "building.columns.fill"
        case .slowmo: "tortoise.fill"
        }
    }

    var settings: VoiceSettings {
        switch self {
        case .normal: VoiceSettings()
        case .megaphone: VoiceSettings(distortion: 35, megaphone: true)
        case .chipmunk: VoiceSettings(pitch: 1000, rate: 1.15)
        case .monster: VoiceSettings(pitch: -900, rate: 0.9, reverb: 25, distortion: 15)
        case .robot: VoiceSettings(pitch: -200, echo: 30, distortion: 60)
        case .echo: VoiceSettings(echo: 55)
        case .hall: VoiceSettings(reverb: 70)
        case .slowmo: VoiceSettings(pitch: -400, rate: 0.6)
        }
    }
}
