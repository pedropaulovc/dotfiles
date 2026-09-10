$ErrorActionPreference = "Stop"

$repoDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("omp-plugins-test-" + [System.Guid]::NewGuid().ToString("N"))
$binDir = Join-Path $tempDir "bin"
$hookPath = Join-Path $tempDir "hook.ps1"
$callLog = Join-Path $tempDir "omp-calls"
New-Item -ItemType Directory -Path $binDir -Force | Out-Null
New-Item -ItemType File -Path $callLog -Force | Out-Null

$fakeOmp = @'
$ErrorActionPreference = "Stop"

if ($args.Count -ge 3 -and $args[0] -eq "plugin" -and $args[1] -eq "marketplace" -and $args[2] -eq "list") {
    [Console]::Write($env:MARKETPLACES)
    exit 0
}
if ($args.Count -ge 4 -and $args[0] -eq "plugin" -and $args[1] -eq "marketplace" -and $args[2] -eq "add") {
    Add-Content -LiteralPath $env:CALL_LOG -Value ("add " + $args[3])
    exit 0
}
if ($args.Count -ge 4 -and $args[0] -eq "plugin" -and $args[1] -eq "marketplace" -and $args[2] -eq "update") {
    Add-Content -LiteralPath $env:CALL_LOG -Value ("update " + $args[3])
    if ($args[3] -ne "agent-plugins" -or $env:FAIL_REFRESH -eq "1") {
        exit 1
    }
    New-Item -ItemType File -Path ($env:CALL_LOG + ".refreshed") -Force | Out-Null
    exit 0
}
if ($args.Count -ge 3 -and $args[0] -eq "plugin" -and $args[1] -eq "install") {
    Add-Content -LiteralPath $env:CALL_LOG -Value ("install " + $args[2])
    if (-not (Test-Path -LiteralPath ($env:CALL_LOG + ".refreshed"))) {
        exit 1
    }
    exit 0
}
throw "Unexpected omp invocation: $($args -join ' ')"
'@
$fakeOmp | Set-Content -LiteralPath (Join-Path $binDir "fake-omp.ps1") -Encoding utf8

if ($IsWindows) {
    $ompWrapper = @'
@echo off
pushd "%~dp0"
pwsh.exe -NoLogo -NoProfile -File "fake-omp.ps1" %*
set "exitcode=%ERRORLEVEL%"
popd
exit /b %exitcode%
'@
    $ompCommandPath = Join-Path $binDir "omp.cmd"
}
else {
    $ompWrapper = @'
#!/bin/sh
exec pwsh -NoLogo -NoProfile -File "$(dirname "$0")/fake-omp.ps1" "$@"
'@
    $ompCommandPath = Join-Path $binDir "omp"
}
$ompWrapper | Set-Content -LiteralPath $ompCommandPath -Encoding utf8
if (-not $IsWindows) {
    & chmod +x $ompCommandPath
    if ($LASTEXITCODE -ne 0) {
        throw "Could not make the fake OMP executable."
    }
}

$pathVariable = if ($IsWindows) { "Path" } else { "PATH" }
$powerShell = if ($IsWindows) { "pwsh.exe" } else { "pwsh" }
$oldPath = [System.Environment]::GetEnvironmentVariable($pathVariable)
$oldCallLog = $env:CALL_LOG
$oldMarketplaces = $env:MARKETPLACES
$oldFailRefresh = $env:FAIL_REFRESH
try {
    [System.Environment]::SetEnvironmentVariable(
        $pathVariable,
        $binDir + [System.IO.Path]::PathSeparator + $oldPath,
        "Process"
    )
    $env:CALL_LOG = $callLog

    Push-Location $repoDir
    try {
        & chezmoi execute-template `
            --file run_onchange_omp-plugins.ps1.tmpl `
            --override-data '{"platform":"windows"}' `
            --output $hookPath
        if ($LASTEXITCODE -ne 0) {
            throw "chezmoi failed to render the Windows OMP hook."
        }
    }
    finally {
        Pop-Location
    }

    function Invoke-HookCase {
        param(
            [string]$CaseName,
            [string]$Marketplaces,
            [string]$ExpectedOutcome,
            [string]$ExpectedSummary
        )

        $env:MARKETPLACES = $Marketplaces
        $env:FAIL_REFRESH = if ($CaseName -eq "refresh-failure") { "1" } else { "0" }
        Remove-Item -LiteralPath ($callLog + ".refreshed") -ErrorAction SilentlyContinue
        Clear-Content -LiteralPath $callLog
        $outputPath = Join-Path $tempDir ($CaseName + "-output")
        & $powerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $hookPath *> $outputPath
        $exitCode = $LASTEXITCODE
        $hookOutput = Get-Content -LiteralPath $outputPath -Raw

        if ($ExpectedOutcome -eq "success" -and $exitCode -ne 0) {
            throw "Expected $CaseName marketplace case to succeed: $hookOutput"
        }
        if ($ExpectedOutcome -eq "failure" -and $exitCode -eq 0) {
            throw "Expected $CaseName marketplace case to fail."
        }

        $calls = @(Get-Content -LiteralPath $callLog)
        $adds = @($calls | Where-Object { $_ -like "add *" })
        $updates = @($calls | Where-Object { $_ -like "update *" })
        $installs = @($calls | Where-Object { $_ -like "install *" })
        $summary = "$($adds.Count):$($updates.Count):$($installs.Count)"
        if ($summary -ne $ExpectedSummary) {
            throw "Unexpected $CaseName call summary: $summary"
        }
        if ($CaseName -eq "missing") {
            if ($adds.Count -ne 1 -or $adds[0] -ne "add pedropaulovc/agent-plugins") {
                throw "Missing marketplace case did not add the manifest source."
            }
        }
        if ($CaseName -eq "wrong-source" -and $calls.Count -ne 0) {
            throw "Different marketplace source triggered omp mutations."
        }
    }

    Invoke-HookCase `
        url `
        "Configured Marketplaces:`n`n  agent-plugins  https://github.com/pedropaulovc/agent-plugins" `
        success `
        "0:1:7"
    Invoke-HookCase `
        shorthand `
        "Configured Marketplaces:`n`n  agent-plugins  pedropaulovc/agent-plugins" `
        success `
        "0:1:7"
    Invoke-HookCase `
        missing `
        "Configured Marketplaces:" `
        success `
        "1:1:7"
    Invoke-HookCase `
        refresh-failure `
        "Configured Marketplaces:`n`n  agent-plugins  https://github.com/pedropaulovc/agent-plugins" `
        failure `
        "0:1:0"
    Invoke-HookCase `
        wrong-source `
        "Configured Marketplaces:`n`n  agent-plugins  https://github.com/another-owner/agent-plugins" `
        failure `
        "0:0:0"

    "PowerShell OMP hooks refresh stale metadata before installs, stop on refresh failure, accept URL and shorthand sources, add missing sources, and reject mismatches."
}
finally {
    [System.Environment]::SetEnvironmentVariable($pathVariable, $oldPath, "Process")
    if ($null -eq $oldCallLog) {
        Remove-Item Env:CALL_LOG -ErrorAction SilentlyContinue
    }
    else {
        $env:CALL_LOG = $oldCallLog
    }
    if ($null -eq $oldMarketplaces) {
        Remove-Item Env:MARKETPLACES -ErrorAction SilentlyContinue
    }
    else {
        $env:MARKETPLACES = $oldMarketplaces
    }
    if ($null -eq $oldFailRefresh) {
        Remove-Item Env:FAIL_REFRESH -ErrorAction SilentlyContinue
    }
    else {
        $env:FAIL_REFRESH = $oldFailRefresh
    }
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
