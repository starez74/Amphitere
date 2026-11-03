# NetHack AI Edition - fixed tablet UI (build-only, safe test)
# Uses the existing Windows environment. Does not install or delete saves.
$ErrorActionPreference = 'Stop'
$Root = 'C:\Projects\NetHack-AI-Edition\Amphitere'
$Android = Join-Path $Root 'sys\android\forkfront'
$Project = Join-Path $Root 'sys\android'
$Branch = 'feature/fixed-tablet-ui'
$OutDir = 'C:\Projects\NetHack-AI-Edition\fixed-tablet-test'
$Java = 'C:\Users\Mick\.jdks\jbr-17.0.14'

function Check([bool]$ok, [string]$message) {
    if (-not $ok) { throw $message }
}

function RunGit([string]$dir, [string[]]$arguments) {
    & git.exe -C $dir @arguments
    Check ($LASTEXITCODE -eq 0) ("Git failed in " + $dir + ": " + ($arguments -join ' '))
}

try {
    Write-Host ''
    Write-Host '=== NETHACK FIXED TABLET BUILD ===' -ForegroundColor Cyan
    Check (Test-Path $Root) "Main project not found: $Root"
    Check (Test-Path $Android) "Android frontend not found: $Android"
    Check (Test-Path (Join-Path $Project 'gradlew.bat')) 'Android Gradle wrapper missing'

    $MainOrigin = (& git.exe -C $Root remote get-url origin).Trim()
    Check ($MainOrigin -match 'github\.com[:/]starez74/Amphitere(\.git)?$') "Unexpected main origin: $MainOrigin"
    $FrontOrigin = (& git.exe -C $Android remote get-url origin).Trim()
    Check ($FrontOrigin -match 'github\.com[:/]starez74/ForkFront-Android-DS(\.git)?$') "Unexpected frontend origin: $FrontOrigin"

    Write-Host '=== FETCH DEVELOPMENT BRANCHES (NO FORCE/PUSH) ===' -ForegroundColor Cyan
    RunGit $Root @('fetch', 'origin', $Branch)
    RunGit $Android @('fetch', 'origin', $Branch)

    Write-Host '=== SWITCH MAIN PROJECT ===' -ForegroundColor Cyan
    & git.exe -C $Root show-ref --verify --quiet "refs/heads/$Branch"
    if ($LASTEXITCODE -eq 0) {
        RunGit $Root @('switch', $Branch)
        RunGit $Root @('merge', '--ff-only', "origin/$Branch")
    } else {
        RunGit $Root @('switch', '-c', $Branch, '--track', "origin/$Branch")
    }

    Write-Host '=== SWITCH ANDROID FRONTEND ===' -ForegroundColor Cyan
    & git.exe -C $Android show-ref --verify --quiet "refs/heads/$Branch"
    if ($LASTEXITCODE -eq 0) {
        RunGit $Android @('switch', $Branch)
        RunGit $Android @('merge', '--ff-only', "origin/$Branch")
    } else {
        RunGit $Android @('switch', '-c', $Branch, '--track', "origin/$Branch")
    }

    $Linked = (& git.exe -C $Root ls-tree HEAD sys/android/forkfront | Select-Object -First 1)
    $FrontSha = (& git.exe -C $Android rev-parse HEAD).Trim()
    Check ($Linked -match [regex]::Escape($FrontSha)) "Submodule mismatch. Parent: $Linked; frontend: $FrontSha"
    Write-Host "Matched frontend commit: $FrontSha" -ForegroundColor Green

    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $Apk = Join-Path $Project 'app\build\outputs\apk\debug\app-debug.apk'
    if (Test-Path $Apk) {
        $Backup = Join-Path $OutDir ("apk-before-fixed-tablet-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.apk')
        Copy-Item -LiteralPath $Apk -Destination $Backup -ErrorAction Stop
        Write-Host "Previous APK backed up: $Backup" -ForegroundColor Green
    }
    Check (Test-Path (Join-Path $Java 'bin\java.exe')) "Java 17 not found at $Java"
    $env:JAVA_HOME = $Java
    $env:PATH = (Join-Path $Java 'bin') + ';C:\msys64\usr\bin;' + $env:PATH

    Write-Host '=== BUILD APK (NO INSTALLATION) ===' -ForegroundColor Cyan
    Push-Location $Project
    try {
        & .\gradlew.bat :app:assembleDebug --console=plain
        Check ($LASTEXITCODE -eq 0) 'Gradle build failed. See output above.'
    } finally {
        Pop-Location
    }
    Check (Test-Path $Apk) "Build returned success but APK not found: $Apk"
    $Info = Get-Item $Apk
    Write-Host ''
    Write-Host 'SUCCESS - APK BUILT, NOT INSTALLED' -ForegroundColor Green
    Write-Host "APK: $($Info.FullName)"
    Write-Host "Size: $([math]::Round($Info.Length / 1MB, 2)) MB"
    Write-Host 'Your tablet app and saved characters have not been touched.'
} catch {
    Write-Host ''
    Write-Host "STOPPED SAFELY: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
