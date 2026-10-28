import PetCore
import SwiftUI
import WidgetKit

struct CompanionEntry: TimelineEntry {
    let date: Date
    let state: PetState
    let activity: Activity
}

struct CompanionProvider: TimelineProvider {
    /// 6 hours of 15-minute scenes. WidgetKit asks again when they run out.
    private let sceneCount = 24

    func placeholder(in context: Context) -> CompanionEntry {
        var sample = PetState(name: "Mochi", birthDate: Date().addingTimeInterval(-2 * 86400), hue: 0.95)
        sample.advance(to: Date())
        sample.fullness = 0.8; sample.happiness = 0.9; sample.energy = 0.8; sample.cleanliness = 0.9
        return CompanionEntry(date: Date(), state: sample, activity: .bouncing)
    }

    func getSnapshot(in context: Context, completion: @escaping (CompanionEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        completion(entry(for: PetStore.shared.current(), at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CompanionEntry>) -> Void) {
        let now = Date()
        var state = PetStore.shared.current(at: now)
        var entries = [entry(for: state, at: now)]

        // Later scenes start on slot boundaries so activities change on schedule.
        var date = Forecast.slotStart(for: now)
        for _ in 1..<sceneCount {
            date = date.addingTimeInterval(Forecast.slot)
            state.advance(to: date)
            entries.append(entry(for: state, at: date))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(for state: PetState, at date: Date) -> CompanionEntry {
        CompanionEntry(date: date, state: state, activity: Forecast.activity(for: state, at: date))
    }
}

struct CompanionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: CompanionEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        case .accessoryCircular: CircularView(entry: entry)
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryInline: InlineView(entry: entry)
        default: SmallView(entry: entry)
        }
    }
}

private func creature(_ entry: CompanionEntry) -> CreatureView {
    CreatureView(state: entry.state, activity: entry.activity, at: entry.date)
}

private struct SmallView: View {
    var entry: CompanionEntry

    var body: some View {
        let dark = Sky.isDark(at: entry.date)
        VStack(spacing: 0) {
            HStack {
                Text(entry.state.name).font(.system(.subheadline, design: .rounded).weight(.bold))
                Spacer()
                Text(entry.state.mood().emoji).font(.subheadline)
            }
            creature(entry)
                .id(entry.activity)
                .transition(.push(from: .bottom))
            Text(entry.activity.caption)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .opacity(0.8)
        }
        .padding(12)
        .foregroundStyle(dark ? .white : Color(white: 0.15))
        .containerBackground(for: .widget) { SkyBackground(date: entry.date) }
    }
}

private struct MediumView: View {
    var entry: CompanionEntry

    var body: some View {
        let dark = Sky.isDark(at: entry.date)
        let state = entry.state
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                creature(entry)
                    .id(entry.activity)
                    .transition(.push(from: .bottom))
                Text(entry.activity.caption)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(state.name).font(.system(.headline, design: .rounded).weight(.bold))
                    Spacer()
                    Text("\(state.mood().emoji) \(state.mood().label)").font(.caption2.weight(.semibold))
                }
                if state.stage == .egg {
                    Text("Hatching soon… tap Pet to keep it warm")
                        .font(.caption)
                        .opacity(0.8)
                    Spacer(minLength: 0)
                } else {
                    Stats(state: state, compact: true)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 6) {
                    ForEach(CareAction.allCases, id: \.self) { action in
                        CareButton(action: action, disabled: !canDo(action, state))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .foregroundStyle(dark ? .white : Color(white: 0.15))
        .containerBackground(for: .widget) { SkyBackground(date: entry.date) }
    }

    private func canDo(_ action: CareAction, _ state: PetState) -> Bool {
        if state.stage == .egg || state.isAsleep() { return action == .pet }
        return true
    }
}

/// Interactive button that runs the action without opening the app (iOS 17+).
private struct CareButton: View {
    var action: CareAction
    var disabled: Bool

    var body: some View {
        Group {
            switch action {
            case .feed: Button(intent: FeedIntent()) { label }
            case .play: Button(intent: PlayIntent()) { label }
            case .pet: Button(intent: PetIntent()) { label }
            case .clean: Button(intent: CleanIntent()) { label }
            }
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.45 : 1)
    }

    private var label: some View {
        Image(systemName: action.systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(action.tint.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityLabel(action.verb)
    }
}

private struct SkyBackground: View {
    var date: Date

    var body: some View {
        ZStack(alignment: .bottom) {
            Sky.gradient(at: date)
            Ground(dark: Sky.isDark(at: date))
                .frame(height: 34)
                .offset(y: 18)
        }
    }
}

// MARK: - Lock screen

private struct CircularView: View {
    var entry: CompanionEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            creature(entry).padding(2)
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct RectangularView: View {
    var entry: CompanionEntry

    var body: some View {
        let state = entry.state
        HStack(spacing: 6) {
            creature(entry).frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.name).font(.headline).widgetAccentable()
                Text("\(state.mood().emoji) \(state.mood().label)").font(.caption)
                Text(entry.activity.caption).font(.caption2).opacity(0.8)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct InlineView: View {
    var entry: CompanionEntry

    var body: some View {
        Text("\(entry.state.mood().emoji) \(entry.state.name) · \(entry.state.mood().label)")
            .containerBackground(for: .widget) { Color.clear }
    }
}

struct CompanionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Companion.widgetKind, provider: CompanionProvider()) { entry in
            CompanionWidgetView(entry: entry)
        }
        .configurationDisplayName("Companion")
        .description("Your little friend, living on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

@main
struct CompanionWidgetBundle: WidgetBundle {
    var body: some Widget {
        CompanionWidget()
    }
}
