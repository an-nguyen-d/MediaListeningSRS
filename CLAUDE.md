# Claude Development Guidelines for MediaListeningSRS

## Architecture Overview

iOS app with a modular Swift Package structure. The Xcode project is the bare-minimum host: it owns `AppDelegate.swift` and `SceneDelegate.swift` and does almost nothing else. All business logic lives in the local SPM at `Packages/MediaListeningSRSApp/`.

Three SPM products are linked into the app target:
- `MSRS.MediaListeningSRSApp` — umbrella library
- `MSRS.AppDependencies` — DI container constructed in `SceneDelegate.init()`
- `MSRS.AppSceneDelegate` — base class subclassed by the app's `SceneDelegate`

### Module Conventions

- Every package target name is prefixed: `MSRS.<TargetName>`. Swift imports use underscore: `import MSRS_<TargetName>`.
- `Shared` and `SharedModels` are the catch-alls for cross-module utilities and domain models.
- New service clients follow the `<Name>Client` (protocol/types) + `<Name>ClientLive` / `<Name>Client<Backend>` (impl) split.

## Package.swift Structure

When adding new targets:

1. Add the case to `PackageTarget`. Keep cases roughly alphabetical, with test targets after non-test targets.
2. Add the case body in the `target` switch using `createPackageTarget` or `createPackageTestTarget`.
3. Add test targets to the `testCases` static array — `run_tests_fast.sh` reads from it.

## Build Commands

```bash
# Build the main app
xcodebuild -scheme MediaListeningSRS -configuration Debug

# Build a single package target
./build_target.sh MSRS.SharedModels

# Run all unit tests (reads from Package.swift testCases)
./run_tests_fast.sh
```

**Important**: tests must run on iOS Simulator, not macOS. ElixirShared imports UIKit, which doesn't compile on macOS via `swift test`. Use `xcodebuild` with `-destination "platform=iOS Simulator,name=iPhone 16"`.

## Testing Strategy

- **TDD**: write the failing test first, then implement minimum code to pass.
- **High-ROI tests only**: skip trivial getters/setters; focus on logic with real failure modes.
- **No direct model construction in tests**: write `static func test(...)` extensions on Request/Response types with sensible defaults so tests only specify what they're testing.
- **Real DBs over mocks** for integration tests: prior incidents have shown mocks drift from production.

## Error Handling

- **Force unwrap (`!`)**: only when the value MUST exist or the app is in a corrupted state. Crashing beats propagating bad data.
- **`assertionFailure()`**: something went wrong but a fallback exists; crashes in debug, continues in release.
- **`debugFailure()`** (from ElixirShared): non-critical issues with reasonable fallbacks; raises a purple Xcode warning.
- **Never fail silently** — always pick one of the three when taking an unexpected path.

## Comment Philosophy

Default to no comments. Only write a comment when removing it would confuse a future reader: a hidden constraint, a non-obvious business rule, or a workaround for a specific bug. Don't restate what the code clearly says.

## Dependency Injection

All clients follow:
1. `Has<Feature>Client` protocol with a default `previewValue()`-returning extension
2. `<Feature>Client` struct: Request/Response endpoint types + `@Sendable` closures
3. `<Feature>Client+Test.swift` for `previewValue()` and `liveValue(...)`

`AppDependencies` composes these by conforming to all `Has<Feature>Client` protocols. Construct it once in `SceneDelegate.init()`.

## Concurrency

- All models crossing actor boundaries must conform to `Sendable`.
- Use `@Sendable` on closures inside Client structs.
- Strict concurrency is on (Swift 6.1).

## DatabaseClient Method Naming

- `fetch*` for reads
- `create*` for inserts
- `update*` for modifications
- `delete*` for removes
- Avoid ambiguous names like `getLast*`; use `fetchLatest*` for clarity.
