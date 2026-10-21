# Flutter Warehouse TDD Evidence

## RED → GREEN

- Warehouse access test first failed because deleting a posted receipt returned the posted-status error before checking the caller's warehouse permission. The service now checks access first; the focused test passes with the permission error.
- Responsive widget tests exposed horizontal overflow in narrow warehouse filters. Dropdowns now expand within their available width; compact and desktop inventory/report tests pass.
- Receipt and master-data widget tests exposed text controllers being disposed while their dialogs were still closing. Line-item dialogs now own their controllers, and master-data forms collect values through `Form.onSaved`; both create-and-save flows pass.

## Verification

- `flutter test --coverage`: all 24 tests passed.
- Line coverage: 2,021 / 2,443 executable lines = **82.73%**.
- `flutter analyze`: no issues found.
- `dart format --set-exit-if-changed lib test`: 26 files checked, no changes required.
- `flutter build web --release`: passed; output created in `build/web`.
- Web and Android display names match the app title, `Warehouse Management Demo`.

## Platform build limits

- `flutter build apk --debug`: blocked because the configured Android SDK has no NDK installation. Gradle requested NDK `28.2.13676358`; Android CLI returned `Package ndk not found` and did not install it.
- `flutter build windows --debug`: blocked because Flutter cannot find a suitable Visual Studio C++ toolchain. `flutter doctor` reports that the Desktop development with C++ workload is missing.
- Android and Windows device/runtime UAT was not performed.
