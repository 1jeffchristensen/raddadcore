#!/usr/bin/env pwsh
# Builds and pushes TensorZero Docker images per RELEASE_GUIDE.md.
# Usage: ./docker_build.ps1 -Version 2025.01.0 [-Target gateway,ui,evaluations]
param(
    [Parameter(Mandatory)]
    [string]$Version,

    [string[]]$Target = @("gateway", "ui", "evaluations"),

    # Pass --load instead of --push (local build, single platform only)
    [switch]$LocalOnly
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

$env:DOCKER_BUILDKIT = "1"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# ── Ensure buildx builder exists and is active ───────────────────────────────
$builderName = "container-builder"
$existing = docker buildx ls --format "{{.Name}}" 2>$null | Where-Object { $_ -eq $builderName }
if ($existing) {
    Step "Using existing buildx builder '$builderName'"
    docker buildx use $builderName
    if ($LASTEXITCODE -ne 0) { Fail "Failed to activate builder '$builderName'" }
} else {
    Step "Creating buildx builder '$builderName'"
    docker buildx create --name $builderName --driver docker-container --use --bootstrap
    if ($LASTEXITCODE -ne 0) { Fail "buildx create failed" }
}
Ok "Builder ready"

# ── Image definitions ────────────────────────────────────────────────────────
$images = @{
    gateway     = "crates/gateway/Dockerfile"
    ui          = "ui/Dockerfile"
    evaluations = "crates/evaluations/Dockerfile"
}

# ── Build each requested target ──────────────────────────────────────────────
foreach ($t in $Target) {
    if (-not $images.ContainsKey($t)) { Fail "Unknown target '$t'. Valid: gateway, ui, evaluations" }

    $dockerfile = $images[$t]
    $repo       = "tensorzero/$t"

    Step "Building $repo ($Version)"

    $buildArgs = @(
        "buildx", "build",
        "-t", "${repo}:latest",
        "-t", "${repo}:${Version}",
        "-f", $dockerfile,
        "--attest", "type=provenance,mode=max",
        "--attest", "type=sbom"
    )

    if ($LocalOnly) {
        $buildArgs += "--load"
    } else {
        $buildArgs += "--platform", "linux/amd64,linux/arm64"
        $buildArgs += "--push"
    }

    $buildArgs += "."

    Push-Location $Root
    try {
        docker @buildArgs
        if ($LASTEXITCODE -ne 0) { Fail "$t build failed" }
    } finally {
        Pop-Location
    }

    Ok "${repo}:latest and ${repo}:$Version built"
}

Write-Host "`nDone." -ForegroundColor Green
