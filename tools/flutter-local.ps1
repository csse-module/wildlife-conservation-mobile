param(
    [switch]$AndroidDebug,
    [string]$ApiBaseUrl
)

# Uses the installed tool snapshot when flutter.bat is broken. Does not edit the SDK.
$ErrorActionPreference = 'Stop'
$FlutterArguments = $args
$taskProject = Split-Path -Parent $PSScriptRoot
$taskSdk = $env:FLUTTER_ROOT
if (-not $taskSdk) {
    $taskSdkLine = Get-Content -LiteralPath (Join-Path $taskProject 'android/local.properties') |
        Where-Object { $_.StartsWith('flutter.sdk=') } | Select-Object -First 1
    if (-not $taskSdkLine) { throw 'Set FLUTTER_ROOT to your installed Flutter SDK directory.' }
    $taskSdk = $taskSdkLine.Substring('flutter.sdk='.Length).Replace('\\', '\')
}
$taskDart = Join-Path $taskSdk 'bin/cache/dart-sdk/bin/dart.exe'
$taskSnapshot = Join-Path $taskSdk 'bin/cache/flutter_tools.snapshot'
$taskPackages = Join-Path $taskSdk 'packages/flutter_tools/.dart_tool/package_config.json'
foreach ($taskFile in @($taskDart, $taskSnapshot, $taskPackages)) {
    if (-not (Test-Path -LiteralPath $taskFile)) { throw "The installed SDK cache is incomplete: $taskFile" }
}
$env:FLUTTER_ROOT = $taskSdk

Push-Location -LiteralPath $taskProject
try {
    if (-not $AndroidDebug) {
        if (-not $FlutterArguments) { $FlutterArguments = @('--version') }
        & $taskDart "--packages=$taskPackages" $taskSnapshot @FlutterArguments
        exit $LASTEXITCODE
    }

    # Keep Gradle's child Flutter invocation on the same cached launcher.
    $taskTools = Join-Path $taskProject '.dart_tool/flutter-local'
    New-Item -ItemType Directory -Path $taskTools -Force | Out-Null
    $taskLauncher = Join-Path $taskTools 'flutter-cached.bat'
    $taskBatch = '@echo off' + "`r`n" + '"' + $taskDart + '" "--packages=' + $taskPackages + '" "' + $taskSnapshot + '" %*' + "`r`n"
    [System.IO.File]::WriteAllText($taskLauncher, $taskBatch)
    $taskLauncherLiteral = $taskLauncher.Replace('\', '/').Replace("'", "\'")
    $taskInit = Join-Path $taskTools 'flutter-cached.init.gradle'
    $taskInitText = @"
gradle.beforeProject { project ->
    project.tasks.configureEach { task ->
        if (task.name.startsWith('compileFlutterBuild')) {
            task.doFirst { task.flutterExecutable = new File('$taskLauncherLiteral') }
        }
    }
}
"@
    [System.IO.File]::WriteAllText($taskInit, $taskInitText)

    if ($env:JAVA_HOME -and -not (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin/java.exe'))) {
        $taskJavaParent = Split-Path -Parent $env:JAVA_HOME
        if (Test-Path -LiteralPath (Join-Path $taskJavaParent 'bin/java.exe')) { $env:JAVA_HOME = $taskJavaParent }
        else { throw 'Set JAVA_HOME to a JDK directory, without the bin suffix.' }
    }
    & $taskDart "--packages=$taskPackages" $taskSnapshot pub get --offline
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $taskGradleArguments = @(':app:assembleDebug', '--init-script', $taskInit,
        '-Ptarget-platform=android-arm,android-arm64,android-x64', '-Ptarget=lib/main.dart',
        '-Ptrack-widget-creation=true', '-Ptree-shake-icons=false')
    if ($ApiBaseUrl) {
        $taskDefine = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("API_BASE_URL=$ApiBaseUrl"))
        $taskGradleArguments += "-Pdart-defines=$taskDefine"
    }
    Set-Location -LiteralPath (Join-Path $taskProject 'android')
    & './gradlew.bat' @taskGradleArguments
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
