# Pocket Companion

A gentle Tamagotchi-like companion for iPhone that lives on your home screen.

- **Hatch and raise it**: an egg hatches after 20 minutes, becomes a child after a day and an adult after three. The adult it turns into (Sprout, Bouncy, Gourmet, Sparkle or Cloud) depends on how you cared for it.
- **Gentle care**: hunger, happiness, energy and cleanliness drift down over real time. If you neglect it, it gets sad and grubby, but it never dies.
- **Living widget**: the home-screen widget shows a new scene every 15 minutes (bouncing, chasing a ball, watching a butterfly, napping...). The medium widget has **Feed / Play / Pet / Bath** buttons that work without opening the app.
- **Day and night**: it sleeps from 22:00 to 07:00 on your phone's clock, and naps during the day when it runs out of energy.
- **Treat Catch** mini-game in the app, plus gentle notifications (never at night).
- **Lock-screen widgets**: circular, rectangular and inline.

Everything is drawn in SwiftUI code, so there are no image assets except the app icon.

## Installing on your iPhone (no Mac needed)

Every push builds an unsigned `.ipa` on GitHub's macOS runners.

1. Download `PocketCompanion.ipa` from the [**latest** release](../../releases/tag/latest), or from the build artifacts of any [Actions run](../../actions).
2. Install it from a Windows or Mac computer with one of these:
   - **[AltStore](https://altstore.io)** (recommended). It rewrites App Groups correctly, so the app and the widget share the same companion. Its AltServer can also refresh the app over Wi-Fi.
   - **[Sideloadly](https://sideloadly.io)**. Sign in with your Apple ID and drop in the IPA. If the in-app Settings show "Widget sync unavailable", switch to AltStore.
3. On the iPhone: *Settings → General → VPN & Device Management*, then trust your Apple ID.
   You also need *Settings → Privacy & Security → Developer Mode* turned on (iOS 16+).
4. Add the widget: long-press the home screen, tap **+**, search **Companion**, and pick the medium size.

With a free Apple ID, sideloaded apps expire after **7 days**. Re-install (or let AltStore refresh) before then; your companion's data is kept.
A free account allows 3 sideloaded apps at once, and this app uses 2 App IDs (the app and its widget).

## Project layout

| Path | What |
| --- | --- |
| `Packages/PetCore` | Pure Swift game logic: stats, time simulation, evolution, widget forecasting, reminders. Unit-tested. |
| `Shared/` | SwiftUI drawing of the creature, App Intents for widget buttons, notifications. Compiled into both targets. |
| `App/` | The iOS app: home screen, Treat Catch mini-game, settings. |
| `Widget/` | WidgetKit extension: home-screen and lock-screen widgets. |
| `project.yml` | [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec; the `.xcodeproj` is generated, not committed. |

To tweak the balance (how fast it gets hungry, when it evolves...), edit `Rules` in
`Packages/PetCore/Sources/PetCore/Simulation.swift`.

If you ever get a Mac: `brew install xcodegen && xcodegen generate && open PocketCompanion.xcodeproj`.
