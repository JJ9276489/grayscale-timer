# Grayscale Timer

Grayscale Timer is a local-first iPhone app that tracks verified grayscale time using iOS accessibility state as the source of truth. It records uninterrupted grayscale runs, computes streaks and history, persists everything locally with SwiftData, and exposes a minimal WidgetKit home screen widget.

## What it does

- Detects whether grayscale is currently enabled with the official UIKit accessibility API.
- Starts a verified run when grayscale turns on and ends it when grayscale turns off.
- Persists `RunRecord` and `DaySummary` locally.
- Computes best run, current streak, best streak, qualifying days, perfect days, and heatmap intensity data.
- Presents a monochrome SwiftUI UI optimized to still look intentional in grayscale.

## Official grayscale APIs used

- Current state: `UIAccessibility.isGrayscaleEnabled`
- Change notification: `UIAccessibility.grayscaleStatusDidChangeNotification`

The installed iPhone SDK in Xcode 26.2 exposes these as:

- `UIAccessibilityIsGrayscaleEnabled(void)` in `UIKit/UIAccessibility.h`
- `UIAccessibilityGrayscaleStatusDidChangeNotification` in `UIKit/UIAccessibility.h`

Swift bridges them to the names above.

## How tracking works

`GrayscaleTrackingManager` is the single place that touches the UIKit grayscale API.

- On launch it fetches any persisted active run and reconciles it against the current iOS grayscale state.
- While the app is running, it listens for `UIAccessibility.grayscaleStatusDidChangeNotification`.
- Every verified grayscale `ON` starts a run if one is not already active.
- Every verified grayscale `OFF` ends the run, updates `durationSecondsCached`, and rebuilds affected `DaySummary` rows.
- Runs that cross midnight remain one `RunRecord`, but `MetricsService` splits the contribution by local calendar day when it computes summaries.

## Caveats

- iOS gives the app a reliable current grayscale state and a change notification while the process is active. It does not give a local-first app a guaranteed historical event feed for grayscale changes while the app is suspended or terminated.
- Because of that, exact transition timestamps that happen while the process is not running cannot be reconstructed after the fact.
- The current implementation stores the last verified grayscale checkpoint while active and uses that to avoid inflating verified time when recovery finds grayscale `OFF`.
- If recovery finds grayscale still `ON` and there is already an active persisted run, the app continues that run to match the requested recovery behavior, but iOS still does not provide historical proof that the state stayed uninterrupted during the time the process was not active.
- The widget is intentionally coarse. It uses a shared local snapshot file inside the app-group container plus WidgetKit timeline refreshes. `Text(..., style: .timer)` can feel live, but WidgetKit still decides the actual update cadence.

## Project structure

```text
App/
Features/
Persistence/
Services/
Shared/
Widget/
project.yml
```

## Persistence

- `RunRecord`
  - `id`
  - `startTime`
  - `endTime`
  - `isActive`
  - `durationSecondsCached`
- `DaySummary`
  - `id`
  - `date`
  - `totalVerifiedSeconds`
  - `breakCount`
  - `longestRunSeconds`
  - `qualified`
  - `perfect`

The qualifying threshold lives in [`Shared/AppConfig.swift`](Shared/AppConfig.swift) as `qualifyingThresholdSeconds`.

## Run it

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if needed.
2. From the project root, generate the Xcode project:

   ```bash
   xcodegen generate
   ```

3. Open `GrayscaleTimer.xcodeproj` in Xcode.
4. Set your signing team and make sure the app group identifier in `project.yml` is valid for that team if you want the widget to share live data on device.
5. Build and run on an iPhone or simulator targeting iOS 17 or later.

## Widget note

The widget reads a local snapshot from the shared app-group container so it can show:

- current run duration when active
- `Grayscale Off` when inactive
- current streak

If you change bundle identifiers, update the app group string in `project.yml` and the constant in `Shared/AppConfig.swift` together.
