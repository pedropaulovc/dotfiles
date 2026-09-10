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
if ($args.Count -ge 3 -and $args[0] -eq "plugin" -and $args[1] -eq "install") {
    Add-Content -LiteralPath $env:CALL_LOG -Value ("install " + $args[2])
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
        if ($ExpectedOutcome -eq "failure" -and $hookOutput -notmatch "Marketplace agent-plugins is registered with a different source\.") {
            throw "Different marketplace source produced the wrong error: $hookOutput"
        }

        $calls = @(Get-Content -LiteralPath $callLog)
        $adds = @($calls | Where-Object { $_ -like "add *" })
        $installs = @($calls | Where-Object { $_ -like "install *" })
        $summary = "$($adds.Count):$($installs.Count)"
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
        "0:7"
    Invoke-HookCase `
        shorthand `
        "Configured Marketplaces:`n`n  agent-plugins  pedropaulovc/agent-plugins" `
        success `
        "0:7"
    Invoke-HookCase `
        missing `
        "Configured Marketplaces:" `
        success `
        "1:7"
    Invoke-HookCase `
        wrong-source `
        "Configured Marketplaces:`n`n  agent-plugins  https://github.com/another-owner/agent-plugins" `
        failure `
        "0:0"

    "PowerShell OMP marketplace matching accepts URL and shorthand output, adds missing sources, and rejects mismatches."
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
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
