# One-command Qwen3 migration. Keeps existing saves and wiki; does not
# uninstall/clear app data. Installs model, then rebuilds and runs diagnostics.
param([switch]$Install)
$ErrorActionPreference = 'Stop'
$Root = 'C:\Projects\NetHack-AI-Edition\Amphitere'
$Branch = 'feature/offline-ondevice-ai'
function Check([bool]$ok,[string]$message) { if (-not $ok) { throw $message } }
try {
    Check $Install 'Pass -Install to approve replacing the obsolete GGUF with Qwen3.'
    Check (Test-Path (Join-Path $Root '.git')) 'Project root missing'
    $currentBranch = (& git.exe -C $Root branch --show-current).Trim()
    Check ($currentBranch -eq $Branch) "Expected $Branch, got $currentBranch"
    Write-Host '=== FETCH QWEN3 DEVELOPMENT UPDATES ===' -ForegroundColor Cyan
    & git.exe -C $Root fetch origin $Branch
    Check ($LASTEXITCODE -eq 0) 'Git fetch failed'
    & git.exe -C $Root merge --ff-only "origin/$Branch"
    Check ($LASTEXITCODE -eq 0) 'Git pull failed; no data modified'
    $installer = Join-Path $Root 'scripts\Install-Qwen3-Offline.ps1'
    $bench = Join-Path $Root 'scripts\Benchmark-OfflineCompanion.ps1'
    Check (Test-Path $installer) 'Qwen3 installer not found after Git update'
    Check (Test-Path $bench) 'Benchmark script not found after Git update'
    Write-Host '=== REPLACE OBSOLETE GGUF WITH QWEN3 ===' -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -Install
    Check ($LASTEXITCODE -eq 0) 'Qwen3 install failed; benchmark not started'
    Write-Host '=== BUILD QWEN3 APP AND BENCHMARK ===' -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bench -Install
    Check ($LASTEXITCODE -eq 0) 'APK build or model benchmark failed'
    Write-Host 'Qwen3 migration test completed. Review JSON for factual accuracy.' -ForegroundColor Green
} catch {
    Write-Host ("STOPPED: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
