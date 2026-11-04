$ErrorActionPreference = "Stop"

$repoDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).ProviderPath
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("omp-secrets-test-" + [System.Guid]::NewGuid().ToString("N"))
$agentDir = Join-Path $tempDir "agent"
$fixtures = Join-Path $tempDir "azure"
$hookPath = Join-Path $tempDir "hook.ps1"
$runnerPath = Join-Path $tempDir "run.ps1"
New-Item -ItemType Directory -Path $agentDir, $fixtures -Force | Out-Null
$oldEnvironment = @{}
foreach ($name in @("AZ_FIXTURES", "AZ_FAIL", "PI_CODING_AGENT_DIR")) {
    $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
}
try {
    $env:AZ_FIXTURES = $fixtures
    $env:PI_CODING_AGENT_DIR = $agentDir
    Remove-Item Env:AZ_FAIL -ErrorAction SilentlyContinue
    # Keep Azure mocked inside the child so the same test runs on Windows and Linux.
    @'
$ErrorActionPreference = "Stop"
function az {
    $command = $args -join " "
    if ($command.StartsWith("webapp config appsettings list ")) { $file = "token" }
    elseif ($command.StartsWith("keyvault secret list ")) { $file = "names" }
    elseif ($command.StartsWith("keyvault secret show ")) {
        $index = [Array]::IndexOf($args, "--name")
        $file = $args[$index + 1]
    }
    else { throw "Unexpected Azure command." }
    if ($env:AZ_FAIL -eq $file) {
        $global:LASTEXITCODE = 42
        return
    }
    $global:LASTEXITCODE = 0
    [IO.File]::ReadAllText((Join-Path $env:AZ_FIXTURES ($file + ".json")))
}
# Exercise the hook with caller tracing enabled as well.
Set-PSDebug -Trace 2
. (Join-Path $PSScriptRoot "hook.ps1")
'@ | Set-Content -LiteralPath $runnerPath -Encoding utf8
    '"fresh-test-token"' | Set-Content (Join-Path $fixtures "token.json")
    '["EXA-API-KEY","QUOTED-KEY","EMPTY-KEY"]' | Set-Content (Join-Path $fixtures "names.json")
    '"fresh-exa-secret"' | Set-Content (Join-Path $fixtures "EXA-API-KEY.json")
    '"  quote\u0027s # $dollar \\path  "' | Set-Content (Join-Path $fixtures "QUOTED-KEY.json")
    '""' | Set-Content (Join-Path $fixtures "EMPTY-KEY.json")

    & chezmoi execute-template --source $repoDir `
        --file (Join-Path $repoDir "run_onchange_after_hindsight-api-key.ps1.tmpl") `
        --override-data '{"platform":"windows"}' --output $hookPath
    if ($LASTEXITCODE -ne 0) { throw "Could not render Windows secrets hook." }
    $envPath = Join-Path $agentDir ".env"
    @(
        "OTHER_SETTING=keep"
        "# keep this comment"
        "HINDSIGHT_API_TOKEN=stale-token"
        "export HINDSIGHT_API_TOKEN=older-token"
        "EXA_API_KEY=stale-exa"
        "export EXA_API_KEY=older-exa"
    ) | Set-Content -LiteralPath $envPath -Encoding utf8
    $expected = @(
        "OTHER_SETTING=keep"
        "# keep this comment"
        "HINDSIGHT_API_TOKEN='fresh-test-token'"
        "EXA_API_KEY='fresh-exa-secret'"
        'QUOTED_KEY="  quote''s # $dollar \path  "'
        "EMPTY_KEY=''"
    )
    $pwshCommand = (Get-Process -Id $PID).Path
    $firstOutput = (& $pwshCommand -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $runnerPath *>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        $diagnostic = $firstOutput.Replace("fresh-test-token", "[redacted]").Replace("fresh-exa-secret", "[redacted]").Replace('  quote''s # $dollar \path  ', "[redacted]")
        throw "Windows secrets hook failed: $diagnostic"
    }
    if ($firstOutput -match 'fresh-test-token|fresh-exa-secret|quote.s # ') {
        throw "Windows hook leaked a secret in output or tracing."
    }
    if (Compare-Object $expected ([IO.File]::ReadAllLines($envPath))) {
        throw "Windows hook did not preserve and import dotenv entries correctly."
    }
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $acl = Get-Acl -LiteralPath $envPath
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        if (-not $acl.AreAccessRulesProtected -or @($acl.Access | Where-Object { $_.IdentityReference.Value -ne $identity }).Count) {
            throw "Windows dotenv ACL is not user-only."
        }
    }
    $firstHash = (Get-FileHash -LiteralPath $envPath -Algorithm SHA256).Hash
    & $pwshCommand -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $runnerPath *> (Join-Path $tempDir "repeat-output")
    if ($LASTEXITCODE -ne 0) {
        $diagnostic = [IO.File]::ReadAllText((Join-Path $tempDir "repeat-output")).Replace("fresh-test-token", "[redacted]").Replace("fresh-exa-secret", "[redacted]").Replace('  quote''s # $dollar \path  ', "[redacted]")
        throw "Repeated hook execution failed: $diagnostic"
    }
    if ((Get-FileHash $envPath -Algorithm SHA256).Hash -ne $firstHash) {
        throw "Repeated hook execution changed dotenv content."
    }
    foreach ($failure in @("token", "names", "QUOTED-KEY")) {
        $env:AZ_FAIL = $failure
        & $pwshCommand -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $runnerPath *> (Join-Path $tempDir "failure-output")
        if ($LASTEXITCODE -eq 0) { throw "Hook succeeded despite Azure failure: $failure" }
        if ((Get-FileHash $envPath -Algorithm SHA256).Hash -ne $firstHash) {
            throw "Failed Azure fetch partially updated dotenv."
        }
    }
    Remove-Item Env:AZ_FAIL
    foreach ($invalid in @(@("token", '""'), @("QUOTED-KEY", '"line one\nline two"'))) {
        $invalid[1] | Set-Content (Join-Path $fixtures ($invalid[0] + ".json"))
        & $pwshCommand -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $runnerPath *> (Join-Path $tempDir "invalid-output")
        if ($LASTEXITCODE -eq 0) { throw "Hook accepted invalid secret content." }
        if ((Get-FileHash $envPath -Algorithm SHA256).Hash -ne $firstHash) {
            throw "Invalid secret partially updated dotenv."
        }
        '"fresh-test-token"' | Set-Content (Join-Path $fixtures "token.json")
    }
    "OMP secrets imported, quoted, preserved, idempotent, and failure-guarded."
}
finally {
    foreach ($name in $oldEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name])
    }
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
