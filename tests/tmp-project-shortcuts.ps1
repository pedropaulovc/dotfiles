$ErrorActionPreference = "Stop"

$repoDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("tmp-project-test-" + [System.Guid]::NewGuid().ToString("N"))
$sourcePath = Join-Path $tempDir "src"
$callLog = Join-Path $tempDir "call-log"
New-Item -ItemType Directory -Path (Join-Path $sourcePath "tmp-stale") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sourcePath "tmp-fresh") -Force | Out-Null
[System.IO.Directory]::SetLastWriteTimeUtc((Join-Path $sourcePath "tmp-stale"), [DateTime]::UtcNow.AddDays(-8))

$ompCallLog = Join-Path $tempDir "omp-call-log"
$oldFailRefresh = $env:FAIL_REFRESH
$oldFailUpgrade = $env:FAIL_UPGRADE

try {
    $profilePath = Join-Path $repoDir ".chezmoitemplates/Microsoft.PowerShell_profile.ps1"
    $escapedSourcePath = $sourcePath.Replace("'", "''")
    $profileText = (Get-Content -LiteralPath $profilePath -Raw).Replace("'C:\src'", "'$escapedSourcePath'")
    . ([scriptblock]::Create($profileText))
    @(
        "omp-plugin-upgrade",
        "yof", "yoo", "yog", "yos", "yot", "yol", "yoa",
        "yoc", "yofc", "yooc", "yogc", "yosc", "yotc", "yolc", "yoac",
        "pyof", "pyoo", "pyog", "pyos", "pyot", "pyol", "pyoa",
        "pyoc", "pyofc", "pyooc", "pyogc", "pyosc", "pyotc", "pyolc", "pyoac",
        "yct", "yc-t", "ycft", "ycot", "ycst",
        "yx-t", "yxst", "yxtt", "yxlt", "yxat",
        "yo-t", "yoft", "yoot", "yogt", "yost", "yott", "yolt", "yoat",
        "pyo-t", "pyoft", "pyoot", "pyogt", "pyost", "pyott", "pyolt", "pyoat"
    ) | ForEach-Object {
        if (-not (Get-Command $_ -ErrorAction SilentlyContinue)) {
            throw "Temporary shortcut was not defined: $_"
        }
    }
    $dogfoodCallLog = Join-Path $tempDir "dogfood-call-log"
    $dogfoodScript = Join-Path $tempDir "fake-omp-dogfood.ps1"
    @'
$args -join " " | Set-Content -LiteralPath $env:PYO_TEST_CALL_LOG
$MyInvocation.MyCommand.Path | Add-Content -LiteralPath $env:PYO_TEST_CALL_LOG
'@ | Set-Content -LiteralPath $dogfoodScript

    $oldPyoBinary = $pyoBinary
    $oldPyoCallLog = $env:PYO_TEST_CALL_LOG
    try {
        $pyoBinary = $dogfoodScript
        $env:PYO_TEST_CALL_LOG = $dogfoodCallLog
        Invoke-PinnedYoloOmp update --check
        $dogfoodCalls = @(Get-Content -LiteralPath $dogfoodCallLog)
        if ($dogfoodCalls.Count -ne 2 -or $dogfoodCalls[0] -ne "--auto-approve update --check") {
            throw "pyo update did not forward the update command to the dogfood binary."
        }
        if ((Resolve-Path $dogfoodCalls[1]).Path -ne (Resolve-Path $dogfoodScript).Path) {
            throw "pyo update invoked a temporary copy instead of the installed dogfood binary."
        }
    }
    finally {
        $pyoBinary = $oldPyoBinary
        if ($null -eq $oldPyoCallLog) {
            Remove-Item Env:PYO_TEST_CALL_LOG -ErrorAction SilentlyContinue
        }
        else {
            $env:PYO_TEST_CALL_LOG = $oldPyoCallLog
        }
    }


    function omp {
        $call = $args -join " "
        Add-Content -LiteralPath $ompCallLog -Value $call
        switch ($call) {
            "plugin marketplace update" {
                if ($env:FAIL_REFRESH -eq "1") {
                    $global:LASTEXITCODE = 17
                    return
                }
            }
            "plugin list --json" {
                @'
{
  "npm": [],
  "marketplace": [
    {
      "id": "watch-pr@agent-plugins",
      "scope": "user",
      "entries": [
        {
          "scope": "user",
          "version": "2.0.2"
        }
      ]
    },
    {
      "id": "watch-pr@agent-plugins",
      "scope": "project",
      "entries": [
        {
          "scope": "project",
          "version": "2.0.2"
        }
      ]
    },
    {
      "id": "worktree-reset@agent-plugins",
      "scope": "project",
      "entries": [
        {
          "scope": "project",
          "version": "2.2.0"
        }
      ]
    }
  ]
}
'@
            }
            "plugin upgrade watch-pr@agent-plugins --scope user" {
                if ($env:FAIL_UPGRADE -eq "1") {
                    $global:LASTEXITCODE = 19
                    return
                }
            }
            "plugin upgrade watch-pr@agent-plugins --scope project" {
            }
            "plugin upgrade worktree-reset@agent-plugins --scope project" {
            }
        }
        $global:LASTEXITCODE = 0
    }
    New-Item -ItemType File -Path $ompCallLog -Force | Out-Null
    Clear-Content -LiteralPath $ompCallLog
    yog --probe
    $calls = @(Get-Content -LiteralPath $ompCallLog)
    if ($calls.Count -ne 1 -or $calls[0] -ne "--auto-approve --model openrouter/z-ai/glm-5.3-flash --smol openrouter/z-ai/glm-5.3 --slow anthropic/claude-opus-5:medium --plan anthropic/claude-fable-5-1:xhigh --probe") {
        throw "yog did not select the GLM 5.3 Flash model and Claude role models."
    }
    Clear-Content -LiteralPath $ompCallLog
    yof --probe
    $calls = @(Get-Content -LiteralPath $ompCallLog)
    if ($calls.Count -ne 1 -or $calls[0] -ne "--auto-approve --model anthropic/claude-fable-5-1:medium --thinking medium --smol openrouter/z-ai/glm-5.3 --slow anthropic/claude-opus-5:medium --plan anthropic/claude-fable-5-1:xhigh --probe") {
        throw "yof did not select the Claude Fable medium model."
    }
    Clear-Content -LiteralPath $ompCallLog
    yoo --probe
    $calls = @(Get-Content -LiteralPath $ompCallLog)
    if ($calls.Count -ne 1 -or $calls[0] -ne "--auto-approve --model anthropic/claude-opus-5:medium --thinking medium --smol openrouter/z-ai/glm-5.3 --slow anthropic/claude-opus-5:medium --plan anthropic/claude-fable-5-1:xhigh --probe") {
        throw "yoo did not select the Claude Opus medium model."
    }
    Clear-Content -LiteralPath $ompCallLog
    yos --probe
    $calls = @(Get-Content -LiteralPath $ompCallLog)
    if ($calls.Count -ne 1 -or $calls[0] -ne "--auto-approve --model openai-codex/gpt-5.6-sol:medium --thinking medium --smol openai-codex/gpt-5.6-luna:max --slow openai-codex/gpt-5.6-sol:medium --plan anthropic/claude-fable-5-1:xhigh --probe") {
        throw "yos did not select the medium-effort Codex role models."
    }
    Clear-Content -LiteralPath $ompCallLog
    yot --probe
    $calls = @(Get-Content -LiteralPath $ompCallLog)
    if ($calls.Count -ne 1 -or $calls[0] -ne "--auto-approve --model openai-codex/gpt-5.6-terra:medium --thinking medium --smol openai-codex/gpt-5.6-luna:max --slow openai-codex/gpt-5.6-sol:medium --plan anthropic/claude-fable-5-1:xhigh --probe") {
        throw "yot did not select the medium-effort Terra role models."
    }
    Clear-Content -LiteralPath $ompCallLog
    omp-plugin-upgrade
    $calls = @(Get-Content -LiteralPath $ompCallLog)
    $expectedCalls = @(
        "plugin marketplace update",
        "plugin list --json",
        "plugin upgrade watch-pr@agent-plugins --scope user",
        "plugin upgrade watch-pr@agent-plugins --scope project",
        "plugin upgrade worktree-reset@agent-plugins --scope project"
    )
    if ($null -ne (Compare-Object -ReferenceObject $expectedCalls -DifferenceObject $calls)) {
        throw "omp-plugin-upgrade did not target every installed plugin scope."
    }
    Clear-Content -LiteralPath $ompCallLog

    $env:FAIL_REFRESH = "1"
    $refreshFailed = $false
    try {
        omp-plugin-upgrade
    }
    catch {
        $refreshFailed = $true
    }
    if (-not $refreshFailed) {
        throw "omp-plugin-upgrade continued after marketplace refresh failure."
    }
    $calls = @(Get-Content -LiteralPath $ompCallLog)
    if ($calls.Count -ne 1 -or $calls[0] -ne "plugin marketplace update") {
        throw "omp-plugin-upgrade ran plugin listing after marketplace refresh failure."
    }
    $env:FAIL_REFRESH = $oldFailRefresh

    Clear-Content -LiteralPath $ompCallLog
    $env:FAIL_UPGRADE = "1"
    $upgradeFailed = $false
    try {
        omp-plugin-upgrade
    }
    catch {
        $upgradeFailed = $true
    }
    if (-not $upgradeFailed) {
        throw "omp-plugin-upgrade hid a scoped plugin upgrade failure."
    }
    $calls = @(Get-Content -LiteralPath $ompCallLog)
    $expectedFailedCalls = @(
        "plugin marketplace update",
        "plugin list --json",
        "plugin upgrade watch-pr@agent-plugins --scope user"
    )
    if ($null -ne (Compare-Object -ReferenceObject $expectedFailedCalls -DifferenceObject $calls)) {
        throw "omp-plugin-upgrade continued after a scoped plugin upgrade failure."
    }
    $env:FAIL_UPGRADE = $oldFailUpgrade


    $pwshPath = (Get-Process -Id $PID).Path

    function Invoke-TestPyol {
        (Get-Location).Path | Set-Content -LiteralPath $callLog
        ($args -join " ") | Add-Content -LiteralPath $callLog
        if ($args -contains "--fail") {
            & $pwshPath -NoLogo -NoProfile -NonInteractive -Command "exit 17"
        }
    }
    Set-Alias -Name pyol -Value Invoke-TestPyol -Force

    $missingNameFailed = $false
    try {
        pyolt
    }
    catch {
        $missingNameFailed = $true
    }
    if (-not $missingNameFailed) {
        throw "pyolt accepted a missing project name."
    }

    $traversalFailed = $false
    try {
        pyolt "..\escape"
    }
    catch {
        $traversalFailed = $true
    }
    if (-not $traversalFailed) {
        throw "pyolt accepted a path traversal project name."
    }

    $namedParameterFailed = $false
    try {
        pyolt -Command evil myproj
    }
    catch {
        $namedParameterFailed = $true
    }
    if (-not $namedParameterFailed) {
        throw "pyolt allowed a user argument to bind the internal command parameter."
    }

    pyolt myproj --flag value
    $calls = @(Get-Content -LiteralPath $callLog)
    if ($calls.Count -ne 2 -or $calls[0] -ne (Join-Path $sourcePath "tmp-myproj") -or $calls[1] -ne "--flag value") {
        throw "pyolt did not run in the temporary project or forward arguments."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $sourcePath "tmp-myproj") -PathType Container)) {
        throw "pyolt did not create the temporary project."
    }
    if (Test-Path -LiteralPath (Join-Path $sourcePath "tmp-stale")) {
        throw "pyolt did not remove the stale temporary project."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $sourcePath "tmp-fresh") -PathType Container)) {
        throw "pyolt removed a fresh temporary project."
    }
    $failingStalePath = Join-Path $sourcePath "tmp-failing-stale"
    New-Item -ItemType Directory -Path $failingStalePath -Force | Out-Null
    [System.IO.Directory]::SetLastWriteTimeUtc($failingStalePath, [DateTime]::UtcNow.AddDays(-8))
    $failureExitCode = $null
    try {
        pyolt failing --fail
    }
    catch {
        $failureExitCode = $LASTEXITCODE
    }

    if ($failureExitCode -ne 17) {
        throw "pyolt did not preserve the wrapped command exit code."
    }
    if (Test-Path -LiteralPath $failingStalePath) {
        throw "pyolt did not clean up after a failed wrapped command."
    }

    if (Get-Command pyolct -ErrorAction SilentlyContinue) {
        throw "A continue temporary shortcut was unexpectedly defined."
    }

    "Temporary PowerShell shortcut created the project, forwarded arguments, and removed stale projects."
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    $env:FAIL_REFRESH = $oldFailRefresh
    if ($null -eq $oldFailUpgrade) {
        Remove-Item Env:FAIL_UPGRADE -ErrorAction SilentlyContinue
    }
    else {
        $env:FAIL_UPGRADE = $oldFailUpgrade
    }

}
