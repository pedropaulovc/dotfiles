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

try {
    $profilePath = Join-Path $repoDir ".chezmoitemplates/Microsoft.PowerShell_profile.ps1"
    $escapedSourcePath = $sourcePath.Replace("'", "''")
    $profileText = (Get-Content -LiteralPath $profilePath -Raw).Replace("'C:\src'", "'$escapedSourcePath'")
    . ([scriptblock]::Create($profileText))
    @(
        "omp-plugin-upgrade",
        "yct", "yc-t", "ycft", "ycot", "ycst",
        "yx-t", "yxst", "yxtt", "yxlt", "yxat",
        "yo-t", "yoft", "yoot", "yost", "yott", "yolt", "yoat",
        "pyo-t", "pyoft", "pyoot", "pyost", "pyott", "pyolt", "pyoat"
    ) | ForEach-Object {
        if (-not (Get-Command $_ -ErrorAction SilentlyContinue)) {
            throw "Temporary shortcut was not defined: $_"
        }
    }

    function omp {
        $call = $args -join " "
        Add-Content -LiteralPath $ompCallLog -Value $call
        if ($call -eq "plugin marketplace update" -and $env:FAIL_REFRESH -eq "1") {
            $global:LASTEXITCODE = 17
            return
        }
        $global:LASTEXITCODE = 0
    }
    New-Item -ItemType File -Path $ompCallLog -Force | Out-Null

    omp-plugin-upgrade
    $calls = @(Get-Content -LiteralPath $ompCallLog)
    if ($calls.Count -ne 2 -or $calls[0] -ne "plugin marketplace update" -or $calls[1] -ne "plugin upgrade") {
        throw "omp-plugin-upgrade did not refresh marketplaces before upgrading plugins."
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
        throw "omp-plugin-upgrade ran plugin upgrade after marketplace refresh failure."
    }
    $env:FAIL_REFRESH = $oldFailRefresh


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

}
