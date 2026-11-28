# NetHack AI Edition: one-command debug APK build/install and fully automatic
# on-device, 3-question x 3-repeat offline inference benchmark. PowerShell 5.1.
# Does not uninstall, clear app data, change saves, or run game commands.
param([switch]$Install)
$ErrorActionPreference = 'Stop'
$Root = 'C:\Projects\NetHack-AI-Edition\Amphitere'
$Project = Join-Path $Root 'sys\android'
$Frontend = Join-Path $Project 'forkfront'
$Branch = 'feature/offline-ondevice-ai'
$Pkg = 'ca.b_ark.amphitere'
$Activity = "$Pkg/.OfflineBenchmarkActivity"
$SDK = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$ADB = Join-Path $SDK 'platform-tools\adb.exe'
$CMake = (Join-Path $SDK 'cmake\4.1.2').Replace('\','/')
$Java = 'C:\Users\Mick\.jdks\jbr-17.0.14'
$Apk = Join-Path $Project 'app\build\outputs\apk\debug\app-debug.apk'
$OutDir = 'C:\Projects\NetHack-AI-Edition\offline-companion-test'

function Verify($condition, $message) { if (-not $condition) { throw $message } }
function Git($folder, [string[]]$arguments) {
    & git.exe -C $folder @arguments
    Verify ($LASTEXITCODE -eq 0) ("Git failed: " + ($arguments -join ' '))
}
function SetCMakePath($folder) {
    $props = Join-Path $folder 'local.properties'
    Verify (Test-Path $props) ("Missing Android config: " + $props)
    if (-not (Test-Path "$props.benchmark-backup")) {
        Copy-Item $props "$props.benchmark-backup"
    }
    $lines = @(Get-Content $props | Where-Object { $_ -notmatch '^\s*cmake\.dir\s*=' })
    $lines += "cmake.dir=$CMake"
    Set-Content -LiteralPath $props -Value $lines
}

try {
    Verify $Install 'Run with -Install to explicitly approve the APK update and benchmark.'
    Verify (Test-Path $ADB) "ADB missing: $ADB"
    Verify (Test-Path (Join-Path $Java 'bin\java.exe')) 'Java 17 not found'
    Verify (Test-Path (Join-Path $SDK 'cmake\4.1.2\bin\cmake.exe')) 'Android SDK CMake 4.1.2 missing'
    Verify (Test-Path $Root) "Project not found: $Root"
    Verify (Test-Path $Frontend) "Frontend not found: $Frontend"
    Verify (Test-Path (Join-Path $Project 'gradlew.bat')) 'Gradle wrapper missing'

    $origin = (& git.exe -C $Root remote get-url origin).Trim()
    Verify ($origin -match 'github\.com[:/]starez74/Amphitere(\.git)?$') "Unexpected Git origin: $origin"
    $frontOrigin = (& git.exe -C $Frontend remote get-url origin).Trim()
    Verify ($frontOrigin -match 'github\.com[:/]starez74/ForkFront-Android-DS(\.git)?$') "Unexpected frontend origin: $frontOrigin"
    $localBranch = (& git.exe -C $Root branch --show-current).Trim()
    Verify ($localBranch -eq $Branch) "Switch the parent repository to $Branch first; currently $localBranch"

    Write-Host '=== FETCH APPROVED OFFLINE DEVELOPMENT FIXES ===' -ForegroundColor Cyan
    Git $Root @('fetch','origin',$Branch)
    Git $Root @('merge','--ff-only',"origin/$Branch")
    Git $Root @('submodule','update','--init','--','sys/android/forkfront')
    $parentSubmodule = (& git.exe -C $Root ls-tree HEAD sys/android/forkfront)
    $frontendSha = (& git.exe -C $Frontend rev-parse HEAD).Trim()
    Verify ($parentSubmodule -match [regex]::Escape($frontendSha)) 'Frontend submodule does not match parent commit'

    SetCMakePath $Project
    SetCMakePath $Frontend
    $env:JAVA_HOME = $Java
    $env:PATH = (Join-Path $SDK 'cmake\4.1.2\bin') + ';' + (Join-Path $Java 'bin') + ';C:\msys64\usr\bin;' + $env:PATH
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    if (Test-Path $Apk) {
        $backup = Join-Path $OutDir ('apk-before-benchmark-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.apk')
        Copy-Item -LiteralPath $Apk -Destination $backup
        Write-Host "Backed up previous APK: $backup"
    }
    Write-Host '=== BUILD DEBUG APK ===' -ForegroundColor Cyan
    Push-Location $Project
    try {
        & .\gradlew.bat :app:assembleDebug --console=plain
        Verify ($LASTEXITCODE -eq 0) 'APK build failed; nothing has been installed.'
    } finally { Pop-Location }
    Verify (Test-Path $Apk) 'APK not found after build'
    $jar = Join-Path $Java 'bin\jar.exe'
    $entries = @(& $jar tf $Apk)
    Verify ($entries -contains 'lib/arm64-v8a/libnethack.so') 'Game library absent: refusing installation'
    Verify ($entries -contains 'lib/arm64-v8a/libnethack_llama.so') 'Offline AI native library absent: refusing installation'
    # Java classes are stored inside classes.dex, not individually in an APK.

    Write-Host '=== VERIFY TABLET AND EXISTING APP ===' -ForegroundColor Cyan
    $devices = @(& $ADB devices | Where-Object { $_ -match '^\S+\s+device\s*$' })
    Verify ($devices.Count -eq 1) 'Expected exactly one authorized tablet; check adb devices'
    $serial = ($devices[0] -split '\s+')[0]
    $existing = @(& $ADB -s $serial shell pm path $Pkg)
    Verify ($existing -match 'package:') 'Existing NetHack app absent; refusing first-time install'
    Write-Host 'Please Save & Quit your current NetHack game before installation.'
    Write-Host '=== UPDATE EXISTING APP (NO DATA WIPE) ===' -ForegroundColor Cyan
    & $ADB -s $serial install -r $Apk
    Verify ($LASTEXITCODE -eq 0) 'ADB installation failed'
    & $ADB -s $serial shell run-as $Pkg test -f files/offline-ai/offline-companion.gguf
    Verify ($LASTEXITCODE -eq 0) 'Imported GGUF not found in app storage; benchmark cancelled'
    # This deletes only a prior benchmark report, never the model or saves.
    & $ADB -s $serial shell run-as $Pkg rm -f files/offline-benchmark.json
    Verify ($LASTEXITCODE -eq 0) 'Could not clear previous benchmark report'
    Write-Host '=== RUN 9 AUTOMATIC QUESTIONS ON TABLET ===' -ForegroundColor Cyan
    & $ADB -s $serial shell am start -n $Activity
    Verify ($LASTEXITCODE -eq 0) 'Could not start debug benchmark activity'
    $deadline = (Get-Date).AddMinutes(20)
    $report = $null
    $lastSamples = -1
    do {
        Start-Sleep -Seconds 2
        $raw = (& $ADB -s $serial exec-out run-as $Pkg cat files/offline-benchmark.json 2>$null) -join "`n"
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            try { $report = $raw | ConvertFrom-Json } catch { continue }
            if ($report.samples.Count -ne $lastSamples) {
                $lastSamples = $report.samples.Count
                Write-Host ("Completed {0}/9 answers..." -f $lastSamples)
            }
            if ($report.status -eq 'complete' -or $report.status -eq 'error') { break }
        }
    } while ((Get-Date) -lt $deadline)
    Verify ($null -ne $report) 'No report received; inspect the tablet screen or adb logcat'
    Verify ($report.status -eq 'complete') ("Benchmark stopped: " + $report.error)
    Verify ($report.samples.Count -eq 9) 'Incomplete report: expected nine samples'
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $jsonPath = Join-Path $OutDir "benchmark-$stamp.json"
    $csvPath = Join-Path $OutDir "benchmark-$stamp.csv"
    [System.IO.File]::WriteAllText($jsonPath, ($report | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
    $rows = @($report.samples | ForEach-Object {
        [pscustomobject]@{Question=$_.question_number;Repeat=$_.repeat;ElapsedMs=$_.elapsed_ms;Generated=$_.generated;QuestionText=$_.question;Answer=$_.answer;Error=$_.error}
    })
    $rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host '=== AUTOMATED RESULTS ===' -ForegroundColor Green
    $rows | Group-Object Question | ForEach-Object {
        $vals = @($_.Group | ForEach-Object { [double]$_.ElapsedMs })
        [pscustomobject]@{
            Question=$_.Name
            Runs=$vals.Count
            AverageSeconds=[math]::Round(($vals | Measure-Object -Average).Average / 1000,2)
            MinimumSeconds=[math]::Round(($vals | Measure-Object -Minimum).Minimum / 1000,2)
            MaximumSeconds=[math]::Round(($vals | Measure-Object -Maximum).Maximum / 1000,2)
        }
    } | Format-Table -AutoSize
    Write-Host "CSV: $csvPath"
    Write-Host "JSON: $jsonPath"
    Write-Host 'Review answers for factual correctness; benchmark records text but does not auto-grade correctness.'
} catch {
    Write-Host ("STOPPED: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
