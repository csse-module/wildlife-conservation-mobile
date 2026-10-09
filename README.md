# WildGuard mobile

Flutter frontend for the wildlife conservation Spring Boot backend.

## Run

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Use the emulator address above for Android, localhost for a browser on the backend computer, or the computer's LAN IP for a physical phone. Include `/api/v1` with no trailing slash. The current default LAN address is `http://192.168.1.21:8080/api/v1`; override it at build/run time when the network changes. No frontend `.env` or Supabase setup is needed for the connected reporting features.

For browser development:

```powershell
flutter run -d chrome --web-hostname localhost --web-port 5173 --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

Set backend `CORS_ALLOWED_ORIGINS=http://localhost:5173` before starting it. A debug APK can be built with `flutter build apk --debug --dart-define=API_BASE_URL=http://YOUR_COMPUTER_IP:8080/api/v1`.

## Roles and screens

| Role | Connected features |
| --- | --- |
| Community member | Public registration, sighting/crop-damage reporting, own report status/outcome, pending synchronization |
| Park manager / Admin | Community inbox/dashboard, incidents, manual alerts, analytics/saved PDFs, camera review, staff/park setup and patrol assignment |
| Liaison officer | Community inbox, accept/resolve reports, alert acceptance/decline/support/response |
| Ranger | Existing patrol tracking, new incident form, community response, alerts, pending incident synchronization |
| Researcher | Analytics, report generation/details/PDF, camera image upload and manual review |

Public registration always creates a community member. Managers provision staff with assigned parks; temporary staff passwords must be changed before accessing operational screens. Managers use Admin Login. Staff and villagers use the normal login. Stored sessions are checked against `/auth/me`; a previously authenticated, unexpired session can show locally saved reports during a network outage.

## Structure

`lib/features/operations/domain` contains models, role capabilities and repository contracts. `data` contains API adapters/mapping and the persistent report outbox. `presentation` contains the role dashboard and feature screens, using shared widgets/theme. Dependencies are injected through Provider in `main.dart`. The backend remains the authority for roles, park scope and ownership.

Community/incident reports persist locally before delivery. Queue entries keep stable resource/attachment IDs, retry after connectivity returns, and remain separated by account. HTTP validation errors remain visible in Pending sync. The queue allows 20 reports and 4 MiB encoded data; the form limits photos to 2 MiB. Existing patrol local storage is separate; its mobile sync action is under My assigned patrols.

Protected photos use the backend media API. PDFs save through the Android document picker, browser download, desktop file picker, or the app's iOS Documents folder. iOS permission descriptions/file sharing are configured; an iOS build requires macOS.

## Verify and demonstrate

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter build web
```

The connected-flow tests cover role menus, manager refresh, liaison resolution, villager payloads, account-separated offline retries, researcher report generation/download, route assignment, and a narrow layout with large text. Screenshots use synthetic API responses. To render them with real SDK fonts for review, run `flutter test --dart-define=REVIEW_SCREENSHOTS=true` with `FLUTTER_ROOT` set to the SDK directory; images are written to ignored `.buildlog/screenshots`.

See [the backend demo guide](../wildlife-conservation-backend/docs/case-study-demo.md) for server setup, seeded role accounts, registration park configuration and the complete demonstration sequence. API contracts are in [implemented-openapi.json](../wildlife-conservation-backend/docs/implemented-openapi.json).

Live collar/camera ingestion, SMS gateways, automatic image recognition and push delivery are external integrations. This implementation provides manual alert/image workflows and the connected mobile reporting/report-generation flows.

## Local Flutter launcher workaround

The installed Windows `flutter.bat` launcher currently fails before invoking Flutter. `tools/flutter-local.ps1` uses the existing cached SDK tool without changing the global SDK. It reads `FLUTTER_ROOT` or the SDK path in `android/local.properties`.

```powershell
./tools/flutter-local.ps1 test
./tools/flutter-local.ps1 run -d chrome --web-hostname localhost --web-port 5173 --dart-define=API_BASE_URL=http://localhost:8080/api/v1
./tools/flutter-local.ps1 -AndroidDebug -ApiBaseUrl http://192.168.1.21:8080/api/v1
```

The Android option performs a debug build using cached dependencies and a temporary Gradle launcher under ignored `.dart_tool`. It also corrects a local `JAVA_HOME` ending in `bin` for that process. Standard Flutter commands remain appropriate on a working SDK installation.
