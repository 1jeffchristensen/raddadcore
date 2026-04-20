#!/usr/bin/env pwsh
# Build script for TensorZero / raddadcore
param(
    [switch]$SkipRust,
    [switch]$SkipNode,
    [switch]$SkipUI,
    [switch]$Release
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# ── Rust ────────────────────────────────────────────────────────────────────
if (-not $SkipRust) {
    Step "Building Rust workspace"
    $cargoArgs = @("build", "--workspace")
    if ($Release) { $cargoArgs += "--release" }

    Push-Location "$Root/crates"
    try   { cargo @cargoArgs; if ($LASTEXITCODE -ne 0) { Fail "cargo build failed" } }
    finally { Pop-Location }
    Ok "Rust build complete"
}

# ── Node / pnpm install ──────────────────────────────────────────────────────
if (-not $SkipNode) {
    Step "Installing Node dependencies"
    Push-Location $Root
    try   { pnpm install; if ($LASTEXITCODE -ne 0) { Fail "pnpm install failed" } }
    finally { Pop-Location }
    Ok "pnpm install complete"

    Step "Building tensorzero-node bindings"
    Push-Location $Root
    try {
        pnpm build-bindings
        if ($LASTEXITCODE -ne 0) { Fail "build-bindings failed" }
        pnpm --filter=@tensorzero/tensorzero-node build
        if ($LASTEXITCODE -ne 0) { Fail "tensorzero-node build failed" }
    } finally { Pop-Location }
    Ok "Node bindings built"
}

# ── UI ───────────────────────────────────────────────────────────────────────
if (-not $SkipUI) {
    Step "Building UI"
    Push-Location $Root
    try   { pnpm --filter=tensorzero-ui build; if ($LASTEXITCODE -ne 0) { Fail "UI build failed" } }
    finally { Pop-Location }
    Ok "UI built"
}

Write-Host "`nBuild complete." -ForegroundColor Green
