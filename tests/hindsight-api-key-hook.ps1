$ErrorActionPreference = "Stop"

$repoDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("hindsight-api-key-test-" + [System.Guid]::NewGuid().ToString("N"))
$binDir = Join-Path $tempDir "bin"
$agentDir = Join-Path $tempDir "omp-agent"
$hookPath = Join-Path $tempDir "hindsight-api-key-hook.ps1"
$callLog = Join-Path $tempDir "az-calls"
New-Item -ItemType Directory -Path $binDir, $agentDir -Force | Out-Null
New-Item -ItemType File -Path $callLog -Force | Out-Null

$fakeAz = @'
$ErrorActionPreference = "Stop"

Add-Content -LiteralPath $env:AZ_LOG -Value ($args -join " ")
if ($env:AZ_FAIL -eq "1") {
    exit 42
}
[Console]::Write($env:AZ_TOKEN)
'@
$fakeAz | Set-Content -LiteralPath (Join-Path $binDir "fake-az.ps1") -Encoding utf8

if ($IsWindows) {
    $azWrapper = @'
@echo off
pwsh.exe -NoLogo -NoProfile -File "%~dp0fake-az.ps1" %*
set "exitcode=%ERRORLEVEL%"
exit /b %exitcode%
'@
    $azWrapper | Set-Content -LiteralPath (Join-Path $binDir "az.cmd") -Encoding ascii
}
else {
    $azWrapper = @'
#!/bin/sh
set -eu

printf '%s\n' "$*" >>"$AZ_LOG"
if [ "${AZ_FAIL-0}" = 1 ]; then
  exit 42
fi
printf '%s' "${AZ_TOKEN-}"
'@
    $azWrapper | Set-Content -LiteralPath (Join-Path $binDir "az") -Encoding utf8
    & chmod +x (Join-Path $binDir "az")
    if ($LASTEXITCODE -ne 0) {
        throw "Could not make the fake Azure CLI executable."
    }
}

$pathVariable = if ($IsWindows) { "Path" } else { "PATH" }
$oldPath = [System.Environment]::GetEnvironmentVariable($pathVariable)
$oldAzLog = $env:AZ_LOG
$oldAzToken = $env:AZ_TOKEN
$oldAzFail = $env:AZ_FAIL
$oldAgentDir = $env:PI_CODING_AGENT_DIR
$pathSeparator = [System.IO.Path]::PathSeparator
$pwshCommand = if ($IsWindows) { "pwsh.exe" } else { "pwsh" }
try {
    [System.Environment]::SetEnvironmentVariable(
        $pathVariable,
        $binDir + $pathSeparator + $oldPath,
        "Process"
    )
    $env:AZ_LOG = $callLog
    $env:AZ_TOKEN = "fresh-test-token"
    Remove-Item Env:AZ_FAIL -ErrorAction SilentlyContinue
    $env:PI_CODING_AGENT_DIR = $agentDir
    $resolvedAz = (Get-Command az).Path
    if ($resolvedAz -ne (Join-Path $binDir "az")) {
        throw "Unexpected Azure CLI resolution: $resolvedAz"
    }

    Push-Location $repoDir
    try {
        & chezmoi execute-template `
            --file run_onchange_after_hindsight-api-key.ps1.tmpl `
            --override-data '{"platform":"windows"}' `
            --output $hookPath
        $renderSucceeded = $?
        $renderExitCode = $LASTEXITCODE
        if (-not $renderSucceeded -or $renderExitCode -ne 0) {
            throw "chezmoi failed to render the Windows Hindsight hook."
        }
    }
    finally {
        Pop-Location
    }

    @(
        "OTHER_SETTING=keep"
        "HINDSIGHT_API_TOKEN=stale-token"
        "export HINDSIGHT_API_TOKEN=older-token"
    ) | Set-Content -LiteralPath (Join-Path $agentDir ".env") -Encoding utf8

    & $pwshCommand -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $hookPath
    $hookSucceeded = $?
    $hookExitCode = $LASTEXITCODE
    if (-not $hookSucceeded -or $hookExitCode -ne 0) {
        throw "The rendered Windows Hindsight hook failed."
    }

    $envPath = Join-Path $agentDir ".env"
    $lines = @(Get-Content -LiteralPath $envPath)
    $tokenLines = @($lines | Where-Object { $_ -match '^HINDSIGHT_API_TOKEN=' })
    if ($tokenLines.Count -ne 1 -or $tokenLines[0] -ne "HINDSIGHT_API_TOKEN=fresh-test-token") {
        throw "The Windows hook did not write exactly one fresh Hindsight token."
    }
    if (-not ($lines -contains "OTHER_SETTING=keep")) {
        throw "The Windows hook did not preserve unrelated dotenv settings."
    }
    if ($lines | Where-Object { $_ -match '^export\s+HINDSIGHT_API_TOKEN=' }) {
        throw "The Windows hook left an old exported Hindsight token behind."
    }

    $firstHash = (Get-FileHash -LiteralPath $envPath -Algorithm SHA256).Hash
    & $pwshCommand -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $hookPath
    $hookSucceeded = $?
    $hookExitCode = $LASTEXITCODE
    if (-not $hookSucceeded -or $hookExitCode -ne 0) {
        throw "The repeated Windows Hindsight hook failed."
    }
    $secondHash = (Get-FileHash -LiteralPath $envPath -Algorithm SHA256).Hash
    if ($firstHash -ne $secondHash) {
        throw "Repeated Windows hook execution changed identical dotenv content."
    }

    $env:AZ_TOKEN = ""
    & $pwshCommand -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $hookPath *> (Join-Path $tempDir "empty-token-output")
    $hookSucceeded = $?
    $hookExitCode = $LASTEXITCODE
    if ($hookSucceeded -and $hookExitCode -eq 0) {
        throw "The Windows hook succeeded with an empty Azure token."
    }
    $thirdHash = (Get-FileHash -LiteralPath $envPath -Algorithm SHA256).Hash
    if ($secondHash -ne $thirdHash) {
        throw "An empty Azure token changed the existing dotenv file."
    }

    $env:AZ_TOKEN = "fresh-test-token"
    $env:AZ_FAIL = "1"
    & $pwshCommand -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $hookPath *> (Join-Path $tempDir "command-failure-output")
    $hookSucceeded = $?
    $hookExitCode = $LASTEXITCODE
    if ($hookSucceeded -and $hookExitCode -eq 0) {
        throw "The Windows hook succeeded when Azure CLI failed."
    }
    $fourthHash = (Get-FileHash -LiteralPath $envPath -Algorithm SHA256).Hash
    if ($secondHash -ne $fourthHash) {
        throw "An Azure CLI failure changed the existing dotenv file."
    }

    $expectedCall = "webapp config appsettings list --resource-group rg-hindsight-wu2 --name app-hindsight-wu2 --query [?name=='HINDSIGHT_API_TENANT_API_KEY'].value | [0] --output tsv"
    $calls = @(Get-Content -LiteralPath $callLog)
    if ($calls.Count -ne 4) {
        throw "Expected four Azure CLI calls, got $($calls.Count)."
    }
    if ($calls | Where-Object { $_ -ne $expectedCall }) {
        throw "At least one Azure CLI call used unexpected arguments."
    }

    "Windows Hindsight hook fetched, preserved, and failure-guarded correctly."
}
finally {
    [System.Environment]::SetEnvironmentVariable($pathVariable, $oldPath, "Process")
    if ($null -eq $oldAzLog) {
        Remove-Item Env:AZ_LOG -ErrorAction SilentlyContinue
    }
    else {
        $env:AZ_LOG = $oldAzLog
    }
    if ($null -eq $oldAzToken) {
        Remove-Item Env:AZ_TOKEN -ErrorAction SilentlyContinue
    }
    else {
        $env:AZ_TOKEN = $oldAzToken
    }
    if ($null -eq $oldAzFail) {
        Remove-Item Env:AZ_FAIL -ErrorAction SilentlyContinue
    }
    else {
        $env:AZ_FAIL = $oldAzFail
    }
    if ($null -eq $oldAgentDir) {
        Remove-Item Env:PI_CODING_AGENT_DIR -ErrorAction SilentlyContinue
    }
    else {
        $env:PI_CODING_AGENT_DIR = $oldAgentDir
    }
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
