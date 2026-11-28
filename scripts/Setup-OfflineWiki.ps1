# One-command developer preview: update/build APK, install offline wiki index,
# run same repeatable on-device benchmark and save full answers for review.
param([switch]$Install)
$ErrorActionPreference = 'Stop'
$Root = 'C:\Projects\NetHack-AI-Edition\Amphitere'
$Pkg = 'ca.b_ark.amphitere'
$ADB = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$Out = 'C:\Projects\NetHack-AI-Edition\offline-companion-test'
try {
    if (-not $Install) { throw 'Run with -Install to approve debug APK update and wiki download.' }
    if (-not (Test-Path $ADB)) { throw 'ADB not found' }
    Write-Host 'PHASE 1/3: update and build debug APK, capture original small-note baseline' -ForegroundColor Cyan
    $benchmark = Join-Path $Root 'scripts\Benchmark-OfflineCompanion.ps1'
    if (-not (Test-Path $benchmark)) {
      throw "Benchmark runner missing: $benchmark"
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $benchmark -Install
    if ($LASTEXITCODE -ne 0) { throw 'Debug APK build / baseline failed; not installing wiki index' }
    Write-Host 'PHASE 2/3: download/index Wiki and install to tablet private storage' -ForegroundColor Cyan
    $installWiki = Join-Path $Root 'scripts\Install-OfflineWiki.ps1'
    if (-not (Test-Path $installWiki)) { throw "Missing installer: $installWiki" }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installWiki -Install
    if ($LASTEXITCODE -ne 0) { throw 'Wiki index install failed; no wiki-backed benchmark run' }
    $devices = @(& $ADB devices | Where-Object { $_ -match '^\S+\s+device\s*$' })
    if ($devices.Count -ne 1) { throw 'Expected one authorized tablet' }
    $serial = ($devices[0] -split '\s+')[0]
    Write-Host 'PHASE 3/3: rerun all 9 questions with offline wiki indexing' -ForegroundColor Cyan
    & $ADB -s $serial shell run-as $Pkg rm -f files/offline-benchmark.json
    if ($LASTEXITCODE -ne 0) { throw 'Could not clear previous benchmark report' }
    & $ADB -s $serial shell am start -n "$Pkg/.OfflineBenchmarkActivity"
    if ($LASTEXITCODE -ne 0) { throw 'Could not launch benchmark activity' }
    $end = (Get-Date).AddMinutes(20)
    $report = $null
    $previous = -1
    do {
        Start-Sleep -Seconds 2
        $raw = (& $ADB -s $serial exec-out run-as $Pkg cat files/offline-benchmark.json 2>$null) -join "`n"
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            try { $report = $raw | ConvertFrom-Json } catch { continue }
            if ($report.samples.Count -ne $previous) {
                $previous = $report.samples.Count
                Write-Host ("Wiki benchmark {0}/9 complete" -f $previous)
            }
            if ($report.status -in @('complete','error')) { break }
        }
    } while ((Get-Date) -lt $end)
    if ($null -eq $report -or $report.status -ne 'complete') {
        throw ("Benchmark did not complete: " + $report.error)
    }
    if ($report.samples.Count -ne 9) { throw 'Benchmark returned fewer than nine answers' }
    New-Item -ItemType Directory -Force -Path $Out | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $json = Join-Path $Out "wiki-benchmark-$stamp.json"
    $csv = Join-Path $Out "wiki-benchmark-$stamp.csv"
    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $json -Encoding UTF8
    $rows = @($report.samples | ForEach-Object {
        [pscustomobject]@{Question=$_.question_number;Repeat=$_.repeat;
          Seconds=[math]::Round($_.elapsed_ms / 1000,2);Generated=$_.generated;
          Answer=$_.answer;Error=$_.error}
    })
    $rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $csv
    $rows | Group-Object Question | ForEach-Object {
        [pscustomobject]@{Question=$_.Name;
          AverageSeconds=[math]::Round(($_.Group | Measure-Object Seconds -Average).Average,2);
          MinSeconds=[math]::Round(($_.Group | Measure-Object Seconds -Minimum).Minimum,2);
          MaxSeconds=[math]::Round(($_.Group | Measure-Object Seconds -Maximum).Maximum,2)}
    } | Format-Table -AutoSize
    Write-Host "Wiki report: $json" -ForegroundColor Green
    Write-Host "Wiki CSV: $csv"
    Write-Host 'Review generated answers for correctness. Wiki pages mix versions, variants, and markup.'
} catch {
    Write-Host ("STOPPED: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
