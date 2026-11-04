$ErrorActionPreference = "Stop"

$repoDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("scrapfly-cli-test-" + [System.Guid]::NewGuid().ToString("N"))
$sourceDir = Join-Path $tempDir "source"
$templateDir = Join-Path $sourceDir ".chezmoitemplates"
$homeDir = Join-Path $tempDir "home"
$binDir = Join-Path $homeDir ".local/bin"
$hookPath = Join-Path $tempDir "hook.ps1"
$originalUserProfile = $env:USERPROFILE
$originalArchitecture = $env:PROCESSOR_ARCHITECTURE
$originalWowArchitecture = $env:PROCESSOR_ARCHITEW6432
try {
    New-Item -ItemType Directory -Path $templateDir, $binDir -Force | Out-Null
    Copy-Item (Join-Path $repoDir ".chezmoitemplates/scrapfly-cli.json") $templateDir
    Copy-Item (Join-Path $repoDir "run_onchange_after_scrapfly-cli.ps1.tmpl") $sourceDir
    $executable = Join-Path $binDir "scrapfly.exe"
    [System.IO.File]::WriteAllText($executable, "existing executable")
    $originalHash = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
    Push-Location $sourceDir
    try {
        & chezmoi --source $sourceDir execute-template `
            --file (Join-Path $sourceDir "run_onchange_after_scrapfly-cli.ps1.tmpl") `
            --override-data '{"platform":"windows"}' `
            --output $hookPath
        if ($LASTEXITCODE -ne 0) {
            throw "Could not render Scrapfly Windows hook."
        }
    }
    finally {
        Pop-Location
    }

    # Intercept only the network boundary; hashing and the hook remain real.
    function Invoke-WebRequest {
        param([string]$Uri, [string]$OutFile)
        [System.IO.File]::WriteAllText($OutFile, "corrupt release archive")
    }
    $env:USERPROFILE = $homeDir
    $env:PROCESSOR_ARCHITECTURE = "AMD64"
    $env:PROCESSOR_ARCHITEW6432 = $null
    $failure = $null
    try {
        & $hookPath
    }
    catch {
        $failure = $_
    }
    finally {
        Set-PSDebug -Off
    }
    if (-not $failure -or $failure.Exception.Message -notlike '*Scrapfly CLI archive SHA256 mismatch.*') {
        throw "Corrupt archive was not rejected by checksum verification: $failure"
    }
    if ((Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash -ne $originalHash) {
        throw "Checksum failure changed the existing Scrapfly executable."
    }
    Write-Output "Scrapfly checksum failure preserves the existing Windows executable."
}
finally {
    $env:USERPROFILE = $originalUserProfile
    $env:PROCESSOR_ARCHITECTURE = $originalArchitecture
    $env:PROCESSOR_ARCHITEW6432 = $originalWowArchitecture
    Remove-Item -LiteralPath $tempDir -Recurse -Force
}
