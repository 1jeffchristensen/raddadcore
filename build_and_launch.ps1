$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

# Build first
& "$Root/build.ps1" @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Launch gateway (background) and UI dev server (foreground)
Write-Host "`n==> Launching gateway" -ForegroundColor Cyan
$gateway = Start-Process -FilePath "cargo" `
    -ArgumentList "run", "--bin", "gateway", "--", "--config-file", "tensorzero-core/tests/e2e/config/tensorzero.*.toml" `
    -WorkingDirectory "$Root/crates" `
    -PassThru -NoNewWindow

Write-Host "    Gateway PID $($gateway.Id)" -ForegroundColor Green

Write-Host "==> Launching UI (pnpm ui:dev)" -ForegroundColor Cyan
try {
    Push-Location $Root
    pnpm ui:dev
} finally {
    Write-Host "`nStopping gateway (PID $($gateway.Id))..." -ForegroundColor Yellow
    Stop-Process -Id $gateway.Id -ErrorAction SilentlyContinue
    Pop-Location
}
