import SwiftUI
import PetCore

extension CareAction {
    var tint: Color {
        switch self {
        case .feed: return Color(red: 1, green: 0.62, blue: 0.35)
        case .play: return Color(red: 0.35, green: 0.7, blue: 1)
        case .pet: return Color(red: 1, green: 0.45, blue: 0.62)
        case .clean: return Color(red: 0.4, green: 0.82, blue: 0.75)
        }
    }

    /// The stat this action restores, for pairing bars with buttons.
    func value(in state: PetState) -> Double {
        switch self {
        case .feed: return state.fullness
        case .play, .pet: return state.happiness
        case .clean: return state.cleanliness
        }
    }
}

struct StatBar: View {
    var symbol: String
    var value: Double
    var tint: Color
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 3 : 6) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 9 : 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: compact ? 12 : 18)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.18))
                    Capsule().fill(value < 0.25 ? Color.red.opacity(0.8) : tint)
                        .frame(width: max(compact ? 4 : 6, geo.size.width * value))
                }
            }
            .frame(height: compact ? 5 : 9)
        }
    }
}

struct Stats: View {
    var state: PetState
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 4 : 8) {
            StatBar(symbol: "fork.knife", value: state.fullness, tint: CareAction.feed.tint, compact: compact)
            StatBar(symbol: "heart.fill", value: state.happiness, tint: CareAction.pet.tint, compact: compact)
            StatBar(symbol: "bolt.fill", value: state.energy, tint: Color(red: 0.95, green: 0.78, blue: 0.2), compact: compact)
            StatBar(symbol: "drop.fill", value: state.cleanliness, tint: CareAction.clean.tint, compact: compact)
        }
    }
}

/// Sky colours for the time of day.
enum Sky {
    static func colors(at date: Date, calendar: Calendar = .current) -> [Color] {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 6..<9: return [Color(red: 1, green: 0.8, blue: 0.7), Color(red: 0.75, green: 0.88, blue: 1)]
        case 9..<17: return [Color(red: 0.62, green: 0.84, blue: 1), Color(red: 0.86, green: 0.95, blue: 1)]
        case 17..<20: return [Color(red: 1, green: 0.66, blue: 0.55), Color(red: 0.98, green: 0.85, blue: 0.75)]
        case 20..<22: return [Color(red: 0.36, green: 0.36, blue: 0.62), Color(red: 0.62, green: 0.55, blue: 0.75)]
        default: return [Color(red: 0.1, green: 0.12, blue: 0.3), Color(red: 0.22, green: 0.24, blue: 0.45)]
        }
    }

    static func isDark(at date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 20 || hour < 6
    }

    static func gradient(at date: Date) -> LinearGradient {
        LinearGradient(colors: colors(at: date), startPoint: .top, endPoint: .bottom)
    }
}

/// Grass strip the companion stands on.
struct Ground: View {
    var dark: Bool

    var body: some View {
        Ellipse()
            .fill(dark ? Color(red: 0.2, green: 0.32, blue: 0.3) : Color(red: 0.6, green: 0.85, blue: 0.5))
            .scaleEffect(x: 1.6, y: 1, anchor: .top)
    }
}
