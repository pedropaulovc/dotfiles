$ErrorActionPreference = "Stop"

$repoDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("tmp-project-test-" + [System.Guid]::NewGuid().ToString("N"))
$sourcePath = Join-Path $tempDir "src"
$callLog = Join-Path $tempDir "call-log"
New-Item -ItemType Directory -Path (Join-Path $sourcePath "tmp-stale") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sourcePath "tmp-fresh") -Force | Out-Null
[System.IO.Directory]::SetLastWriteTimeUtc((Join-Path $sourcePath "tmp-stale"), [DateTime]::UtcNow.AddDays(-8))

try {
    $profilePath = Join-Path $repoDir ".chezmoitemplates/Microsoft.PowerShell_profile.ps1"
    $profileText = (Get-Content -LiteralPath $profilePath -Raw).Replace("'C:\src'", "'$sourcePath'")
    . ([scriptblock]::Create($profileText))
    @(
        "yct", "yc-t", "ycft", "ycot", "ycst",
        "yx-t", "yxst", "yxtt", "yxlt",
        "yo-t", "yoft", "yoot", "yost", "yott", "yolt",
        "pyo-t", "pyoft", "pyoot", "pyost", "pyott", "pyolt"
    ) | ForEach-Object {
        if (-not (Get-Command $_ -ErrorAction SilentlyContinue)) {
            throw "Temporary shortcut was not defined: $_"
        }
    }

    function Invoke-TestPyol {
        (Get-Location).Path | Set-Content -LiteralPath $callLog
        ($args -join " ") | Add-Content -LiteralPath $callLog
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
    if (Get-Command pyolct -ErrorAction SilentlyContinue) {
        throw "A continue temporary shortcut was unexpectedly defined."
    }

    "Temporary PowerShell shortcut created the project, forwarded arguments, and removed stale projects."
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
