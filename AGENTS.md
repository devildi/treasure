# Repository Guidelines

## Project Structure & Module Organization
- `lib/` contains application logic: `core/` handles infrastructure (networking, pagination, state), `components/` exposes reusable widgets, `pages/` defines screens, and root utilities (`dao.dart`, `store.dart`, `tools.dart`, `toy_model.dart`) support data flow.
- `assets/` stores declared media (splash art, sample video); update `pubspec.yaml` when adding files.
- `test/` mirrors the feature layout with focused `*_test.dart` specs and generated Mockito stubs such as `swiper_item_test.mocks.dart`.
- Platform folders (`android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/`) hold native configs—modify only for platform-specific tasks.

## Build, Test, and Development Commands
- `flutter pub get` resolves dependencies.
- `flutter analyze` enforces the lint set from `analysis_options.yaml`.
- `flutter test --coverage` runs unit and widget suites while refreshing the `coverage/` report.
- `flutter run -d <device>` launches a debug build; `flutter run -d chrome` is the fastest sanity check for web.
- `dart run build_runner build --delete-conflicting-outputs` regenerates Mockito mocks after API changes.

## Coding Style & Naming Conventions
- Respect `package:flutter_lints`: two-space indentation, trailing commas on multiline literals, null-safe patterns, and early `return` for guard clauses.
- Use UpperCamelCase for types/widgets, lowerCamelCase for members, and snake_case for file names (e.g., `toy_model.dart`).
- Format before committing with `dart format lib test`; prefer `const` constructors and remove unused imports to keep analyzer noise low.

## Testing Guidelines
- Rely on `flutter_test` for widget/unit coverage and `mockito` for collaborator fakes; mirror `lib/` structure to keep intent obvious.
- Cover success, failure, and loading states for pagination, storage, and network flows; add golden tests when UI output is deterministic.
- When mocks change, rerun the build_runner command above and commit regenerated files to avoid CI drift.

## Commit & Pull Request Guidelines
- Follow local history: either use emoji-prefixed imperatives (`🎨 Polish masonry layout`) or the dated counter format (`25-09-17:3`).
- Keep commits focused, run `flutter analyze` and `flutter test` beforehand, and avoid unchecked reformatting.
- PRs need a clear summary, linked issue/task IDs, verification notes (commands executed), and screenshots or screen recordings for UI tweaks. Flag platform/config updates for targeted review.

## Asset & Configuration Tips
- Declare every new asset in `pubspec.yaml` and keep binaries optimized to prevent bloat; clean `build/` after large asset changes.
- Update `flutter_native_splash.yaml` alongside splash art changes and rerun `dart run flutter_native_splash:create` to regenerate native splash assets.
