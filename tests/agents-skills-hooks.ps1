$ErrorActionPreference = "Stop"

$repoDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("agents-skills-test-" + [System.Guid]::NewGuid().ToString("N"))
$binDir = Join-Path $tempDir "bin"
$hookPath = Join-Path $tempDir "hook.ps1"
$callLog = Join-Path $tempDir "npx-calls"
New-Item -ItemType Directory -Path $binDir -Force | Out-Null
New-Item -ItemType File -Path $callLog -Force | Out-Null

if ($IsWindows) {
    $gitWrapper = @'
@echo off
pushd "%~dp0"
pwsh.exe -NoLogo -NoProfile -File "fake-git.ps1" %*
set "exitcode=%ERRORLEVEL%"
popd
exit /b %exitcode%
'@
    $gitCommandPath = Join-Path $binDir "git.cmd"
}
else {
    $gitWrapper = @'
#!/bin/sh
exec pwsh -NoLogo -NoProfile -File "$(dirname "$0")/fake-git.ps1" "$@"
'@
    $gitCommandPath = Join-Path $binDir "git"
}
$gitWrapper | Set-Content -LiteralPath $gitCommandPath -Encoding utf8
if (-not $IsWindows) {
    & chmod +x $gitCommandPath
    if ($LASTEXITCODE -ne 0) {
        throw "Could not make the fake Git executable."
    }
}

$fakeGit = @'
$ErrorActionPreference = "Stop"

if ($args[0] -eq "clone") {
    $hasBlobFilter = $args -contains "--filter=blob:none" -or (
        $args -contains "--filter=blob" -and $args -contains "none"
    )
    if (
        $args -notcontains "--depth=1" -or
        -not $hasBlobFilter -or
        $args -notcontains "--no-checkout"
    ) {
        throw "Clone was not shallow and blob-filtered: $($args -join ' ')"
    }
    $source = $args | Where-Object { $_ -like "https://github.com/*" } | Select-Object -First 1
    $repoDir = $args[-1]
    $hashes = @{
        "https://github.com/microsoft/playwright-cli.git" = "fe74b7fb02fe5d0697d1e1359cb44e1f48d1fc54"
        "https://github.com/blader/humanizer.git" = "5a7260aab6ed0b28f1f464f1757f4704d3a7ab5c"
        "https://github.com/nutlope/hallmark.git" = "747c924c4767b4d5fa6f1c59985c87a21c918334"
        "https://github.com/vectorize-io/hindsight.git" = "38a67f1634dc12aa545d1cd0ac1e0f83c1c828d7"
    }
    if (-not $hashes.ContainsKey($source)) {
        throw "Unexpected clone source: $source"
    }
    New-Item -ItemType Directory -Path $repoDir -Force | Out-Null
    $hashes[$source] | Set-Content -LiteralPath (Join-Path $repoDir ".expected-hash")
    exit 0
}

if ($args[0] -eq "-C") {
    $repoDir = $args[1]
    switch ($args[2]) {
        "fetch" { exit 0 }
        "checkout" { exit 0 }
        "rev-parse" {
            Get-Content -LiteralPath (Join-Path $repoDir ".expected-hash")
            exit 0
        }
    }
}

throw "Unexpected git invocation: $($args -join ' ')"
'@
$fakeGit | Set-Content -LiteralPath (Join-Path $binDir "fake-git.ps1") -Encoding utf8

if ($IsWindows) {
    $npxWrapper = @'
@echo off
pushd "%~dp0"
pwsh.exe -NoLogo -NoProfile -File "fake-npx.ps1" %*
set "exitcode=%ERRORLEVEL%"
popd
exit /b %exitcode%
'@
    $npxCommandPath = Join-Path $binDir "npx.cmd"
}
else {
    $npxWrapper = @'
#!/bin/sh
exec pwsh -NoLogo -NoProfile -File "$(dirname "$0")/fake-npx.ps1" "$@"
'@
    $npxCommandPath = Join-Path $binDir "npx"
}
$npxWrapper | Set-Content -LiteralPath $npxCommandPath -Encoding utf8
if (-not $IsWindows) {
    & chmod +x $npxCommandPath
    if ($LASTEXITCODE -ne 0) {
        throw "Could not make the fake npx executable."
    }
}

$fakeNpx = @'
$ErrorActionPreference = "Stop"

if ($args.Count -lt 3 -or $args[0] -ne "--yes" -or $args[1] -ne "skills@1.5.23" -or $args[2] -ne "add") {
    throw "Unexpected npx invocation: $($args -join ' ')"
}

$agents = [System.Collections.Generic.List[string]]::new()
for ($index = 0; $index -lt $args.Count; $index++) {
    if ($args[$index] -ne "--agent") {
        continue
    }
    if ($index + 1 -ge $args.Count -or $args[$index + 1].StartsWith("--")) {
        throw "Missing --agent value"
    }
    $agents.Add($args[$index + 1])
    $index++
}

$lockedAgents = "amp antigravity antigravity-cli cline codex cursor deepagents gemini-cli github-copilot kimi-code-cli opencode warp zed claude-code"
$detectedAgents = "promptscript"
$actualAgents = if ($agents.Count -eq 0) { $detectedAgents } else { $agents -join " " }
if ($actualAgents -ne $lockedAgents) {
    throw "Agent target mismatch: expected $lockedAgents, got $actualAgents"
}
Add-Content -LiteralPath $env:CALL_LOG -Value $actualAgents
'@
$fakeNpx | Set-Content -LiteralPath (Join-Path $binDir "fake-npx.ps1") -Encoding utf8

$pathVariable = if ($IsWindows) { "Path" } else { "PATH" }
$powerShell = if ($IsWindows) { "pwsh.exe" } else { "pwsh" }
$oldPath = [System.Environment]::GetEnvironmentVariable($pathVariable)
$oldCallLog = $env:CALL_LOG
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
            --file run_onchange_agents-skills.ps1.tmpl `
            --override-data '{"platform":"windows"}' `
            --output $hookPath
        if ($LASTEXITCODE -ne 0) {
            throw "chezmoi failed to render the Windows hook."
        }
    }
    finally {
        Pop-Location
    }

    Push-Location $env:USERPROFILE
    try {
        $hookOutputPath = Join-Path $tempDir "hook-output"
        & $powerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $hookPath *> $hookOutputPath
        $hookSucceeded = $?
        $hookExitCode = $LASTEXITCODE
        $hookOutput = Get-Content -LiteralPath $hookOutputPath -Raw
        if (-not $hookSucceeded -or $hookExitCode -ne 0) {
            throw "The rendered Windows hook failed: $hookOutput"
        }
        if ($hookOutput -notmatch "git clone --depth=1 --filter=blob:none --no-checkout") {
            throw "Rendered PowerShell hook did not print the shallow clone command."
        }
    }
    finally {
        Pop-Location
    }

    $calls = @(Get-Content -LiteralPath $callLog)
    if ($calls.Count -ne 4) {
        throw "Expected four skill installs, got $($calls.Count). Hook output: $hookOutput"
    }
    $lockedAgents = "amp antigravity antigravity-cli cline codex cursor deepagents gemini-cli github-copilot kimi-code-cli opencode warp zed claude-code"
    if ($calls | Where-Object { $_ -ne $lockedAgents }) {
        throw "At least one Windows install used an unexpected agent list."
    }

    "Rendered PowerShell hook preserved locked agent targets across differing detection: $($calls.Count) installs."
}
finally {
    [System.Environment]::SetEnvironmentVariable($pathVariable, $oldPath, "Process")
    if ($null -eq $oldCallLog) {
        Remove-Item Env:CALL_LOG -ErrorAction SilentlyContinue
    }
    else {
        $env:CALL_LOG = $oldCallLog
    }
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
