**How to Run Frontend Tests and Collect Report Screenshots**

Use two kinds of evidence: automated-test output/screenshots and screenshots of manually executed flows in the running application. The latest recorded full automated run passed 12 tests. The 35 manual cases remain Not run until you perform them and record their outcomes.

**Single-line PowerShell commands**

The [frontend test runner](<E:/Flutter MAD/CSSE_Project/wildlife-conservation-mobile/tools/run-frontend-tests.ps1>) locates the existing Flutter SDK automatically, enables screenshot fonts and saves the console output under `.buildlog/test-evidence`. Open PowerShell in the mobile project:

```powershell
cd 'E:\Flutter MAD\CSSE_Project\wildlife-conservation-mobile'
```

Run all automated tests with one line:

```powershell
.\tools\run-frontend-tests.ps1 -CaseId ALL
```

Or run any individual case with one line:

```powershell
.\tools\run-frontend-tests.ps1 -CaseId AUTO-001 # Image-upload request
.\tools\run-frontend-tests.ps1 -CaseId AUTO-002 # Researcher report and PDF bytes
.\tools\run-frontend-tests.ps1 -CaseId AUTO-003 # Patrol assignment
.\tools\run-frontend-tests.ps1 -CaseId AUTO-004 # Missing route area regression
.\tools\run-frontend-tests.ps1 -CaseId AUTO-005 # Community dashboard permissions
.\tools\run-frontend-tests.ps1 -CaseId AUTO-006 # Manager dashboard automatic refresh
.\tools\run-frontend-tests.ps1 -CaseId AUTO-007 # Researcher dashboard permissions
.\tools\run-frontend-tests.ps1 -CaseId AUTO-008 # Liaison report acceptance and resolution
.\tools\run-frontend-tests.ps1 -CaseId AUTO-009 # Villager sighting submission
.\tools\run-frontend-tests.ps1 -CaseId AUTO-010 # Offline retry and account separation
.\tools\run-frontend-tests.ps1 -CaseId AUTO-011 # Analytics mapping
.\tools\run-frontend-tests.ps1 -CaseId AUTO-012 # Narrow layout and large text
```

For one-case screenshot evidence, run the chosen command, wait for `All tests passed!` or a failure, and use **Windows + Shift + S** to capture the test ID, description and result. The FE-001–FE-035 cases are manual application steps; these AUTO IDs identify the existing executable tests. The next section provides the equivalent direct SDK commands if you want to run without the wrapper.

**Run the automated tests**

Open a PowerShell terminal and paste:

```powershell
cd 'E:\Flutter MAD\CSSE_Project\wildlife-conservation-mobile'
$env:FLUTTER_ROOT = 'C:\Users\arosh\dev\flutter'

function Run-Flutter {
    & "$env:FLUTTER_ROOT\bin\cache\dart-sdk\bin\dart.exe" "--packages=$env:FLUTTER_ROOT\packages\flutter_tools\.dart_tool\package_config.json" "$env:FLUTTER_ROOT\bin\cache\flutter_tools.snapshot" @args
}

New-Item -ItemType Directory -Path '.buildlog' -Force | Out-Null
Run-Flutter test --reporter expanded --dart-define=REVIEW_SCREENSHOTS=true 2>&1 |
    Tee-Object -FilePath '.buildlog/frontend-report-tests.log'
```

`Run-Flutter` invokes the installed cached Flutter tool and avoids the broken local `flutter.bat` launcher. Keep this terminal open so the function remains available. These automated tests use mocked APIs and run independently of the backend.

At completion, look for `+12: All tests passed!`. Press **Windows + Shift + S** and capture the terminal showing test names and the final result. Save it as `AUTO-tests-passed.png`.

The tests also produce these PNGs with SDK fonts:

- [Community dashboard](<E:/Flutter MAD/CSSE_Project/wildlife-conservation-mobile/.buildlog/screenshots/community-dashboard.png>)
- [Park manager dashboard](<E:/Flutter MAD/CSSE_Project/wildlife-conservation-mobile/.buildlog/screenshots/manager-dashboard.png>)

These dashboard images contain synthetic test data. Caption them as automated widget-test screenshots. They do not establish live backend/device behavior.

The execution log is [frontend-report-tests.log](<E:/Flutter MAD/CSSE_Project/wildlife-conservation-mobile/.buildlog/frontend-report-tests.log>).

**Start the real application for manual tests**

In a second PowerShell terminal, start the backend using the existing local `.env` configuration:

```powershell
cd 'E:\Flutter MAD\CSSE_Project\wildlife-conservation-backend'
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
$env:CORS_ALLOWED_ORIGINS = 'http://localhost:5173'
.\mvnw.cmd spring-boot:run
```

Leave that terminal running. If your backend is already running on port 8080 with the correct configuration, use the existing process.

Return to the first terminal, where `Run-Flutter` was defined, and launch the frontend:

```powershell
Run-Flutter run -d chrome --web-hostname localhost --web-port 5173 --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

Keep both terminals running while performing manual tests. Use existing accounts, or public registration for a community member and Add staff for staff accounts. Choose the same park for the villager, manager and responding officer. Initial manager-account setup is described in [the backend demo guide](<E:/Flutter MAD/CSSE_Project/wildlife-conservation-backend/docs/case-study-demo.md>).

For mobile-style browser screenshots, open Chrome developer tools with **F12**, enable the device toolbar with **Ctrl + Shift + M**, choose a phone viewport such as 390 × 844, then refresh. This verifies the browser at that viewport; hardware GPS/camera and native saving should also be tested in the Android app.

**Capture a small, useful set of manual evidence**

Follow the matching test case in [frontend-test-cases.md](<E:/Flutter MAD/CSSE_Project/wildlife-conservation-mobile/docs/frontend-test-cases.md>). At the observed result, press **Windows + Shift + S**, select the application region and save the image with its test ID. If the Snipping Tool opens a preview, save using **Ctrl + S**. Keep screenshots at consistent dimensions and use the screenshot files directly in the report.

| Case | What to do and capture | Suggested filename |
| --- | --- | --- |
| FE-004 | Submit registration with a five-character password; capture the visible validation message. | `FE-004-password-validation.png` |
| FE-012 | Submit a wildlife sighting as a community member; open it from My reports and capture its Submitted status. | `FE-012-sighting-submitted.png` |
| FE-015 | Log in as manager, refresh the same park and capture the matching report in Incoming community reports. | `FE-015-manager-inbox.png` |
| FE-016 | As liaison/ranger, accept the same report and capture Responding status. | `FE-016-report-accepted.png` |
| FE-017 | Record action/outcome and resolve; capture Resolved status and the recorded outcome. | `FE-017-report-resolved.png` |
| FE-020 | Assign a route as manager; open My patrols as the selected ranger and capture the assigned patrol. | `FE-020-assigned-patrol.png` |
| FE-024 | After logging in/loading parks, disconnect and submit a valid report; capture Pending sync. Reconnect/sync and capture the delivered report separately. | `FE-024-pending-sync.png`, `FE-024-delivered.png` |
| FE-028 | Generate a report, download its PDF and capture the opened PDF with readable report content. | `FE-028-generated-pdf.png` |
| FE-031 | Upload/review an image for a configured camera trap; capture the saved final review. | `FE-031-camera-review.png` |

For the quickest connected-flow demonstration, perform FE-012 → FE-015 → FE-016 → FE-017 on the same report. Record the report ID, park and timestamps so the screenshots can be matched. Use two community accounts for ownership testing. Native permission and offline tests are easiest to capture on a phone or emulator using its screenshot control.

**Insert evidence into the report**

Insert the saved image, then add a caption with the test ID, action and observed result. For example, after observing a successful manager-inbox test:

> Figure X — FE-015: After refresh, the park manager dashboard displays the community member's submitted wildlife-sighting report for the same park.

Record the result in your execution table:

| Test ID | Expected result | Actual result | Status | Evidence |
| --- | --- | --- | --- | --- |
| FE-015 | Submitted community report appears in the manager's park inbox. | Enter what you observed after executing the test. | Pass / Fail | `FE-015-manager-inbox.png` |

Use Pass only when the observed result matches the expectation. Keep browser and Android evidence labeled by platform, and include the execution date. Crop passwords/tokens and unrelated personal information out of screenshots.
