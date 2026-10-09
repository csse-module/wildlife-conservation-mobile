[CmdletBinding()]
param(
    [ValidateSet('ALL', 'AUTO-001', 'AUTO-002', 'AUTO-003', 'AUTO-004',
        'AUTO-005', 'AUTO-006', 'AUTO-007', 'AUTO-008', 'AUTO-009',
        'AUTO-010', 'AUTO-011', 'AUTO-012')]
    [string]$CaseId = 'ALL'
)

$ErrorActionPreference = 'Stop'
$taskProject = Split-Path -Parent $PSScriptRoot
$taskSdk = $env:FLUTTER_ROOT
if (-not $taskSdk) {
    $taskSdkLine = Get-Content -LiteralPath (Join-Path $taskProject 'android/local.properties') |
        Where-Object { $_.StartsWith('flutter.sdk=') } | Select-Object -First 1
    if (-not $taskSdkLine) { throw 'Set FLUTTER_ROOT to your Flutter SDK directory.' }
    $taskSdk = $taskSdkLine.Substring('flutter.sdk='.Length).Replace('\\', '\')
}

$taskDart = Join-Path $taskSdk 'bin/cache/dart-sdk/bin/dart.exe'
$taskSnapshot = Join-Path $taskSdk 'bin/cache/flutter_tools.snapshot'
$taskPackages = Join-Path $taskSdk 'packages/flutter_tools/.dart_tool/package_config.json'
foreach ($taskFile in @($taskDart, $taskSnapshot, $taskPackages)) {
    if (-not (Test-Path -LiteralPath $taskFile)) { throw "Flutter cache file is missing: $taskFile" }
}

$taskCases = @{
    'AUTO-001' = 'image upload sends the image MIME type and required media metadata'
    'AUTO-002' = 'researcher generates a saved report and downloads PDF bytes'
    'AUTO-003' = 'manager assigns a configured route to a ranger in the same park'
    'AUTO-004' = 'routes without an area still show rangers and can be assigned'
    'AUTO-005' = 'community sees reporting actions and no manager privileges'
    'AUTO-006' = 'manager dashboard displays new villager reports after automatic refresh'
    'AUTO-007' = 'researcher has analytics and camera access without community inbox calls'
    'AUTO-008' = 'liaison accepts community report and records outcome'
    'AUTO-009' = 'villager submits sighting with the required backend contract'
    'AUTO-010' = 'offline report retries keep its ID and cannot cross accounts'
    'AUTO-011' = 'analytics maps conflict types trends and coverage from API'
    'AUTO-012' = 'report status is accessible at narrow widths and large text'
}

$taskArguments = @("--packages=$taskPackages", $taskSnapshot, 'test')
if ($CaseId -ne 'ALL') {
    $taskTestFile = if ($CaseId -eq 'AUTO-012') { 'test/widget_test.dart' } else { 'test/operations_test.dart' }
    $taskArguments += @($taskTestFile, '--plain-name', $taskCases[$CaseId])
}
$taskArguments += @('--reporter', 'expanded', '--dart-define=REVIEW_SCREENSHOTS=true')
$taskEvidence = Join-Path $taskProject '.buildlog/test-evidence'
New-Item -ItemType Directory -Path $taskEvidence -Force | Out-Null
$taskLog = Join-Path $taskEvidence "$CaseId.log"
$env:FLUTTER_ROOT = $taskSdk

Write-Host "Running frontend test: $CaseId"
if ($CaseId -ne 'ALL') { Write-Host $taskCases[$CaseId] }
Push-Location -LiteralPath $taskProject
try {
    & $taskDart @taskArguments 2>&1 | Tee-Object -FilePath $taskLog
    $taskExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
Write-Host "Evidence log: $taskLog"
exit $taskExitCode
