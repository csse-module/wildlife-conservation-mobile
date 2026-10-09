**Frontend Test Cases — Wildlife Conservation Management System**

Application: Flutter mobile/web frontend. Admin corresponds to `PARK_MANAGER`.

**Test preparation**

- Run the Spring Boot backend and connect the application to its API.
- Prepare a park manager, ranger, liaison officer, researcher and two community-member accounts. Assign the interacting accounts to the same existing park. Use a second park and ranger to verify filtering.
- Configure at least one patrol route and camera trap in the selected park. Include a route whose `areaId` is missing or null for the patrol regression test.
- Use separate test accounts and records. Example test data: `frontend.tester@example.test`, password `Demo@123`, village `Boundary Village`, species `Elephant`, crop details `Paddy damaged near the park boundary`.
- For reporting, use a valid observation time that is not in the future. For analytics, use a period with known records, such as 1–9 October 2026.
- Use JPEG/PNG images. Community and incident forms apply a 2 MiB photo limit after image processing; camera-trap upload applies a separate 5 MiB limit.

**Manual frontend acceptance cases**

These are prepared test cases. They have not been executed as a complete manual/device test run. Initial execution status for every case below is **Not run**. Add Actual Result, Pass/Fail, Evidence and Execution Date after performing each case.

| ID | Feature / role | Test steps and input | Expected result |
| --- | --- | --- | --- |
| FE-001 | Community registration | Open Register. Enter a unique valid name/email, select an enabled park and enter matching passwords `Demo@123`. Submit, then log in. | Registration succeeds. The account opens the Community Dashboard and has community privileges. |
| FE-002 | Required registration fields | Leave required name, email or password fields blank and submit. Repeat for each field. | Relevant validation messages appear. No account is created. |
| FE-003 | Email validation | Enter `invalid-email` in the registration email field and complete other fields. Submit. | An invalid-email message appears and submission is blocked. |
| FE-004 | Password boundary | Register once with matching `Ab123` passwords (5 characters), then with `Ab1234` (6 characters), keeping all other data valid and the email unused. | Five characters are rejected. Six characters pass the minimum-length check and allow registration. |
| FE-005 | Password confirmation | Enter different password and confirmation values during registration. Submit. | A password-mismatch message appears. Registration is blocked. |
| FE-006 | Login and role routing | Log in with valid community, ranger, liaison and researcher accounts through normal login. Log in with a manager through Admin Login. | Each account reaches its appropriate dashboard and sees its permitted navigation actions. |
| FE-007 | Incorrect credentials | Enter a valid account email with an incorrect password. Select Login. | An authentication error appears and access to the dashboard is denied. |
| FE-008 | Admin Login restriction | Try Admin Login with a community-member account and its correct password. | The account is denied admin access and does not open the manager dashboard. |
| FE-009 | Staff creation | As manager, open Add staff. Enter an unused name/email, choose RANGER, select an assigned park and provide a temporary password. Save. | A success message appears. The new ranger can log in and is available for assignments in the selected park. |
| FE-010 | First staff login | Log in using the newly created staff account and temporary password. Change it to a valid matching new password, then log in again. | The password-change screen is required before continuing. After changing it, the user must log in again with the new password. |
| FE-011 | Community navigation | Log in as a community member and inspect dashboard actions. | Report sighting or crop damage, My reports and Pending sync are available. Add staff, Assign patrol and Analytics & reports are absent. |
| FE-012 | Wildlife sighting | Open Report sighting or crop damage. Choose Wildlife sighting, park and area. Enter village, species `Elephant`, description and a valid observation time. Submit online. | The report is submitted and appears in My reports with Submitted status and the entered details. Community photo/location are optional. |
| FE-013 | Crop-damage report | Choose Crop damage. Enter park, area, village, crop details, description and a valid observation time. Submit. | The crop-damage report is submitted and displays the entered crop details. |
| FE-014 | Required report fields | Leave a required report field blank, including species for a sighting or crop details for crop damage. Submit. Repeat for each relevant field. | The appropriate validation message appears and the incomplete report is not submitted. |
| FE-015 | Manager dashboard refresh | Keep the manager dashboard open for the same park. Submit a report from a community account. Wait up to 30 seconds, or refresh manually. | The report appears in Incoming community reports and its details can be opened. |
| FE-016 | Officer accepts report | As a ranger or liaison officer in the report's park, open a Submitted community report and select Accept report. | The report changes to Responding and identifies the accepting officer. |
| FE-017 | Officer resolves report | As the accepting officer, choose Record response and resolve. Enter Action taken and Outcome, then resolve. | Status changes to Resolved and the recorded action/outcome are displayed. |
| FE-018 | Community status and ownership | Resolve a report belonging to community member A. Refresh My reports as A, then log in as community member B and inspect My reports. | A sees the updated status and outcome. B does not see A's report. |
| FE-019 | Ranger incident evidence | As ranger, try submitting an otherwise valid incident without a photo, then without location. Finally attach a valid photo and enter valid GPS/manual coordinates. | Incomplete submissions are blocked with an appropriate message. The complete incident is accepted. |
| FE-020 | Patrol assignment | As manager, choose Assign patrol, select park, configured route, eligible ranger and duration. Assign. Log in as that ranger and refresh My patrols. | Assignment succeeds and the assigned patrol appears for the selected ranger. |
| FE-021 | Missing route area regression | Open Assign patrol for a park containing routes with missing, null and blank `areaId` values. Choose a route and ranger, then assign. | Routes display their names without a null label. Rangers remain visible. No null-to-String error occurs and assignment succeeds. |
| FE-022 | Ranger park filtering | Create or identify ranger A in park A and ranger B in park B. Select park A on Assign patrol. | Ranger A is selectable. Ranger B is excluded. If there are no eligible rangers, an explanatory empty-state message appears. |
| FE-023 | Patrol recording | As ranger, open an assigned patrol, grant location access, start the patrol, record a waypoint/observation, and end it with a connection available. | Patrol tracking runs, captured activity is retained and successful completion is reflected in the patrol view after refresh. |
| FE-024 | Offline submission and retry | Log in online and load parks. Disconnect the network, submit a valid field report and inspect Pending sync. Reconnect or select Sync. Repeat Sync after delivery. | The report stays queued while offline, then is delivered and removed from the queue. It retains its identifier and produces one server report. |
| FE-025 | Offline account separation | Queue a report under community account A while offline. Log out and log in as B. Inspect/sync pending reports. Return to A and restore connectivity. | A's queued report is not exposed or submitted as B. It can be delivered when A is active again. |
| FE-026 | Analytics filters | As manager or researcher, open Analytics & reports. Select an assigned park and a period with known incidents/community reports. Refresh. | Counts, trends and patrol coverage correspond to the selected park and dates. |
| FE-027 | Analytics date boundary | Select a period of 92 inclusive days, then attempt 93 inclusive days. | The 92-day period is accepted. The longer period is rejected with the date-range validation message. |
| FE-028 | Generate and export report | As manager/researcher, select park, valid dates and report type. Generate a report, open it and choose Download PDF. Save/open the file on the target platform. | The saved report opens with the selected period/type. A readable PDF is downloaded or saved through the platform's save flow. |
| FE-029 | Researcher navigation | Log in as researcher and inspect the dashboard. | Analytics & reports and Camera traps are available. Staff management, patrol assignment and the raw community inbox are absent. |
| FE-030 | Conflict-alert response | As manager, create a manual alert with valid park, area, animal, collar, risk and coordinates. As an officer in that park, open and accept it, request support, then record a response and resolve. | Alert details load, acceptance identifies the officer, the support request is recorded, and the resolved outcome is shown. No SMS/push delivery is assumed. |
| FE-031 | Camera image upload/review | As manager/researcher, open Camera traps, choose a configured trap and upload a valid image. Open it, enter species, possible-poacher flag and notes, then Save final review. Reopen it. | The image appears in the list. Its final review persists and is displayed without editable review fields. |
| FE-032 | GPS permission denial | Deny location permission or disable location services, then request GPS on the field-report form. Enter coordinates manually afterwards. | A GPS-unavailable message appears without a crash. Manual coordinate entry remains usable. |
| FE-033 | Responsive UI | Open login, role dashboard, report form and assignment screen at narrow phone widths and with enlarged system text. Scroll to all actions. | Text, fields and actions remain readable and reachable, with no clipping or layout exceptions. Record any screen-specific failures. |
| FE-034 | Server failure and recovery | Stop the backend or interrupt connectivity while loading a report/list. Restore the service and use the displayed Retry/Refresh action. | A useful error is shown and the application remains usable. Retry/Refresh loads the data after recovery. |
| FE-035 | Logout navigation | Log in, open a protected screen, log out, then press Back. Restart the app while still logged out. | The user remains logged out. Protected account screens cannot be accessed through navigation history. |

**Recorded automated frontend results**

The latest recorded full `flutter test` run, following the patrol null-field fix, passed **12 tests**: 11 operations tests and one narrow-layout widget test. These tests use mocked API responses and local test storage. They verify frontend behavior and request handling; device permissions, physical GPS/camera behavior and the native PDF save picker still require the manual cases above.

| ID | Automated scenario | Verified result | Status |
| --- | --- | --- | --- |
| AUTO-001 | Image upload request | PNG content type, park/category metadata and bearer token are sent. | Pass |
| AUTO-002 | Researcher report generation | The report screen generates a saved report and the repository retrieves PDF-format bytes. | Pass |
| AUTO-003 | Normal patrol assignment | A configured route and same-park ranger can be selected; the expected assignment payload is sent. | Pass |
| AUTO-004 | Missing route area | Missing/null/blank route areas do not prevent ranger selection or assignment. | Pass |
| AUTO-005 | Community dashboard actions | Community actions appear and manager-only actions are absent. | Pass |
| AUTO-006 | Manager report refresh | Newly returned community-report data appears after the automatic refresh interval. | Pass |
| AUTO-007 | Researcher dashboard actions | Analytics/camera actions appear; staff management is absent and no community inbox request is made. | Pass |
| AUTO-008 | Liaison response | Accepting changes the displayed status to Responding; resolving displays Resolved and the outcome. | Pass |
| AUTO-009 | Villager sighting submission | The required report fields, type, species and observation time are submitted. | Pass |
| AUTO-010 | Offline retries and account isolation | Pending reports retain their ID, do not submit under another account and leave the queue after successful delivery. | Pass |
| AUTO-011 | Analytics response mapping | Conflict counts, date filters, area data and coverage are mapped correctly. | Pass |
| AUTO-012 | Narrow layout and enlarged text | The report-status card renders at 320 × 640 with 2× text scaling, with the status visible and no layout exception. | Pass |

Evidence: [full automated execution log](<E:/Flutter MAD/CSSE_Project/wildlife-conservation-mobile/.buildlog/frontend-report-tests.log>) and [operations test source](<E:/Flutter MAD/CSSE_Project/wildlife-conservation-mobile/test/operations_test.dart>).

The narrow-width/large-text test is in [widget_test.dart](<E:/Flutter MAD/CSSE_Project/wildlife-conservation-mobile/test/widget_test.dart>). See [the execution and screenshot method](<E:/Flutter MAD/CSSE_Project/wildlife-conservation-mobile/docs/frontend-testing-method.md>) to reproduce the run and capture manual evidence.

**Execution record template**

| Test ID | Actual result | Pass / Fail / Not run | Evidence or screenshot | Execution date |
| --- | --- | --- | --- | --- |
| FE-001 | | Not run | | |

**Suggested report wording**

The frontend test plan contains 35 manual acceptance cases covering authentication, role-specific navigation, community reporting, staff onboarding, patrol management, offline synchronization, analytics, report export, alerts, camera-trap review and usability. The recorded full frontend test run passed 12 automated tests using mocked API responses and local test storage, including a regression test for patrol routes with missing area identifiers and a narrow-layout test with enlarged text. Manual device and end-to-end results are recorded separately after execution.
