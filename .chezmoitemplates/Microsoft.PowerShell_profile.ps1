$InformationPreference = 'Continue'

$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
$env:EDITOR = 'code --wait'

function global:Invoke-YoloClaude {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

    # $env:CLAUDE_CODE_DISABLE_AUTO_UPDATE='1'

	& C:\Users\pedro\.local\bin\claude.exe --verbose --disallowedTools "NotebookEdit" --dangerously-skip-permissions --name $env:COMPUTERNAME --remote-control @Remaining
}

function global:Invoke-YoloClaudeFable {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& C:\Users\pedro\.local\bin\claude.exe --verbose --disallowedTools "NotebookEdit" --dangerously-skip-permissions --name $env:COMPUTERNAME --remote-control --model fable --effort high --autocompact 1M @Remaining
}

function global:Invoke-YoloClaudeOpus {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& C:\Users\pedro\.local\bin\claude.exe --verbose --disallowedTools "NotebookEdit" --dangerously-skip-permissions --name $env:COMPUTERNAME --remote-control --model opus --effort high --autocompact 500k @Remaining
}

function global:Invoke-YoloClaudeSonnet {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& C:\Users\pedro\.local\bin\claude.exe --verbose --disallowedTools "NotebookEdit" --dangerously-skip-permissions --name $env:COMPUTERNAME --remote-control --model sonnet --effort high --autocompact 500k @Remaining
}

function global:Invoke-YoloClaudeContinue { Invoke-YoloClaude --continue @args }
function global:Invoke-YoloClaudeFableContinue { Invoke-YoloClaudeFable --continue @args }
function global:Invoke-YoloClaudeOpusContinue { Invoke-YoloClaudeOpus --continue @args }
function global:Invoke-YoloClaudeSonnetContinue { Invoke-YoloClaudeSonnet --continue @args }

function global:Invoke-YoloCodex {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& codex --dangerously-bypass-approvals-and-sandbox @Remaining
}

function global:Invoke-YoloCodexSol {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& codex --dangerously-bypass-approvals-and-sandbox --model gpt-6-sol -c 'model_reasoning_effort="high"' @Remaining
}

function global:Invoke-YoloCodexTerra {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& codex --dangerously-bypass-approvals-and-sandbox --model gpt-5.6-terra -c 'model_reasoning_effort="max"' @Remaining
}

function global:Invoke-YoloCodexLuna {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )
	& codex --dangerously-bypass-approvals-and-sandbox --model gpt-6-luna -c 'model_reasoning_effort="max"' @Remaining
}
function global:Invoke-YoloCodexAstra {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& codex --dangerously-bypass-approvals-and-sandbox --model gpt-6-astra -c 'model_reasoning_effort="low"' @Remaining
}

function global:Invoke-YoloCodexContinue { Invoke-YoloCodex resume --last @args }
function global:Invoke-YoloCodexSolContinue { Invoke-YoloCodexSol resume --last @args }
function global:Invoke-YoloCodexTerraContinue { Invoke-YoloCodexTerra resume --last @args }
function global:Invoke-YoloCodexLunaContinue { Invoke-YoloCodexLuna resume --last @args }
function global:Invoke-YoloCodexAstraContinue { Invoke-YoloCodexAstra resume --last @args }

function global:Invoke-YoloOmp { & omp --auto-approve @args }
function global:Invoke-OmpPluginUpgrade {
    & omp plugin marketplace update
    if ($LASTEXITCODE -ne 0) {
        throw "omp could not update plugin marketplaces."
    }

    $pluginListJson = (& omp plugin list --json | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "omp could not list installed plugins."
    }

    try {
        $pluginList = $pluginListJson | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "omp returned invalid plugin list JSON: $($_.Exception.Message)"
    }

    foreach ($plugin in @($pluginList.marketplace)) {
        if ($null -eq $plugin) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace([string]$plugin.id)) {
            throw "omp returned a marketplace plugin without an ID."
        }
        if ($plugin.scope -ne "user" -and $plugin.scope -ne "project") {
            throw "omp returned an invalid scope for $($plugin.id): $($plugin.scope)."
        }

        & omp plugin upgrade $plugin.id --scope $plugin.scope
        if ($LASTEXITCODE -ne 0) {
            throw "omp could not upgrade $($plugin.id) ($($plugin.scope) scope)."
        }
    }
}

function global:Invoke-Pyu {
    $ErrorActionPreference = 'Stop'
    & chezmoi update
    if ($LASTEXITCODE -ne 0) {
        throw "chezmoi update failed (exit code $LASTEXITCODE)."
    }

    # The profile is deployed by chezmoi update. Its functions and aliases
    # explicitly use global scope so dot-sourcing here refreshes this session.
    . $PROFILE.CurrentUserCurrentHost

    Invoke-PinnedYoloOmp update
    if ($LASTEXITCODE -ne 0) {
        throw "pyo update failed (exit code $LASTEXITCODE)."
    }

    Invoke-OmpPluginUpgrade
}

function global:Invoke-YoloOmpFable { Invoke-YoloOmp       --model anthropic/claude-fable-5-1:medium --thinking medium --smol openrouter/xiaomi/mimo-v2.6-pro --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-1:xhigh @args }
function global:Invoke-YoloOmpOpus  { Invoke-YoloOmp       --model anthropic/claude-opus-5-5:medium  --thinking medium --smol openrouter/xiaomi/mimo-v2.6-pro --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-1:xhigh @args }
function global:Invoke-YoloOmpMimo  { Invoke-YoloOmp       --model openrouter/xiaomi/mimo-v2.6-pro   --thinking medium --smol openrouter/xiaomi/mimo-v2.6-pro --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-1:xhigh @args }
function global:Invoke-YoloOmpSol   { Invoke-YoloOmp       --model openai-codex/gpt-6-sol:medium     --thinking medium --smol openai-codex/gpt-6-luna:max    --slow openai-codex/gpt-6-sol:medium   --plan openai-codex/gpt-6-astra:high   @args }
function global:Invoke-YoloOmpTerra { Invoke-YoloOmp       --model openai-codex/gpt-5.6-terra:medium --thinking medium --smol openai-codex/gpt-6-luna:max    --slow openai-codex/gpt-6-sol:medium   --plan openai-codex/gpt-6-astra:high   @args }
function global:Invoke-YoloOmpLuna  { Invoke-YoloOmp       --model openai-codex/gpt-6-luna:max       --thinking max    --smol openai-codex/gpt-6-luna:max    --slow openai-codex/gpt-6-sol:medium   --plan openai-codex/gpt-6-astra:high   @args }
function global:Invoke-YoloOmpAstra { Invoke-YoloOmp       --model openai-codex/gpt-6-astra:low      --thinking low    --smol openai-codex/gpt-6-luna:max    --slow openai-codex/gpt-6-sol:medium   --plan openai-codex/gpt-6-astra:high   @args }
function global:Invoke-YoloOmpContinue      { Invoke-YoloOmp       --continue @args }
function global:Invoke-YoloOmpFableContinue { Invoke-YoloOmpFable       --continue @args }
function global:Invoke-YoloOmpOpusContinue  { Invoke-YoloOmpOpus       --continue @args }
function global:Invoke-YoloOmpMimoContinue  { Invoke-YoloOmpMimo       --continue @args }
function global:Invoke-YoloOmpSolContinue   { Invoke-YoloOmpSol       --continue @args }
function global:Invoke-YoloOmpTerraContinue { Invoke-YoloOmpTerra       --continue @args }
function global:Invoke-YoloOmpLunaContinue  { Invoke-YoloOmpLuna       --continue @args }
function global:Invoke-YoloOmpAstraContinue { Invoke-YoloOmpAstra       --continue @args }

# Run a temporary copy of the self-updating fork dogfood binary so pyo sessions do not lock the original. `update` runs the original so the replacement persists.
$global:pyoBinary = Join-Path $HOME '.bun\bin\omp-dogfood.exe'
function global:Invoke-PinnedYoloOmp {
	if ($args -contains 'update') {
		& $pyoBinary --auto-approve @args
		return
	}

	$tempBinary = Join-Path ([System.IO.Path]::GetTempPath()) "omp-pyo-$([guid]::NewGuid()).exe"

	try {
		Copy-Item -LiteralPath $pyoBinary -Destination $tempBinary -ErrorAction Stop
		& $tempBinary --auto-approve @args
	}
	finally {
		Remove-Item -LiteralPath $tempBinary -Force -ErrorAction SilentlyContinue
	}
}
function global:Invoke-PinnedYoloOmpFable { Invoke-PinnedYoloOmp --model anthropic/claude-fable-5-1:medium --thinking medium --smol openrouter/xiaomi/mimo-v2.6-pro --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-1:xhigh @args }
function global:Invoke-PinnedYoloOmpOpus  { Invoke-PinnedYoloOmp --model anthropic/claude-opus-5-5:medium  --thinking medium --smol openrouter/xiaomi/mimo-v2.6-pro --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-1:xhigh @args }
function global:Invoke-PinnedYoloOmpMimo  { Invoke-PinnedYoloOmp --model openrouter/xiaomi/mimo-v2.6-pro   --thinking medium --smol openrouter/xiaomi/mimo-v2.6-pro --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-1:xhigh @args }
function global:Invoke-PinnedYoloOmpSol   { Invoke-PinnedYoloOmp --model openai-codex/gpt-6-sol:medium     --thinking medium --smol openai-codex/gpt-6-luna:max    --slow openai-codex/gpt-6-sol:medium   --plan openai-codex/gpt-6-astra:high   @args }
function global:Invoke-PinnedYoloOmpTerra { Invoke-PinnedYoloOmp --model openai-codex/gpt-5.6-terra:medium --thinking medium --smol openai-codex/gpt-6-luna:max    --slow openai-codex/gpt-6-sol:medium   --plan openai-codex/gpt-6-astra:high   @args }
function global:Invoke-PinnedYoloOmpLuna  { Invoke-PinnedYoloOmp --model openai-codex/gpt-6-luna:max       --thinking max    --smol openai-codex/gpt-6-luna:max    --slow openai-codex/gpt-6-sol:medium   --plan openai-codex/gpt-6-astra:high   @args }
function global:Invoke-PinnedYoloOmpAstra { Invoke-PinnedYoloOmp --model openai-codex/gpt-6-astra:low      --thinking low    --smol openai-codex/gpt-6-luna:max    --slow openai-codex/gpt-6-sol:medium   --plan openai-codex/gpt-6-astra:high   @args }
function global:Invoke-PinnedYoloOmpContinue      { Invoke-PinnedYoloOmp --continue @args }
function global:Invoke-PinnedYoloOmpFableContinue { Invoke-PinnedYoloOmpFable --continue @args }
function global:Invoke-PinnedYoloOmpOpusContinue  { Invoke-PinnedYoloOmpOpus --continue @args }
function global:Invoke-PinnedYoloOmpMimoContinue  { Invoke-PinnedYoloOmpMimo --continue @args }
function global:Invoke-PinnedYoloOmpSolContinue   { Invoke-PinnedYoloOmpSol --continue @args }
function global:Invoke-PinnedYoloOmpTerraContinue { Invoke-PinnedYoloOmpTerra --continue @args }
function global:Invoke-PinnedYoloOmpLunaContinue  { Invoke-PinnedYoloOmpLuna --continue @args }
function global:Invoke-PinnedYoloOmpAstraContinue { Invoke-PinnedYoloOmpAstra --continue @args }

# Run an agent shortcut in a temporary project under C:\src\tmp-<name>.
# Temporary projects are removed after seven days without any file or
# directory modification. Continue shortcuts (the *c variants) are
# intentionally not wrapped.
function global:Remove-StaleTemporaryProject {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string] $SourcePath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        return
    }

    $cutoff = [DateTime]::UtcNow.AddDays(-7)
    $projects = Get-ChildItem -LiteralPath $SourcePath -Directory -Force -ErrorAction SilentlyContinue
    foreach ($project in $projects) {
        if ($project.Name -notlike 'tmp-*') {
            continue
        }

        if ($project.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Warning "Skipping symbolic link or junction: $($project.FullName)"
            continue
        }

        try {
            $latest = $project.LastWriteTimeUtc
            $entries = @(Get-ChildItem -LiteralPath $project.FullName -Force -Recurse -ErrorAction Stop)
            foreach ($entry in $entries) {
                if ($entry.LastWriteTimeUtc -gt $latest) {
                    $latest = $entry.LastWriteTimeUtc
                }
            }
        }
        catch {
            Write-Warning "Unable to inspect temporary project: $($project.FullName)"
            continue
        }

        if ($latest -gt $cutoff) {
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($project.FullName, 'Remove stale temporary project')) {
            continue
        }

        Write-Information "Removing stale temporary project: $($project.FullName)"
        try {
            Remove-Item -LiteralPath $project.FullName -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Unable to remove stale temporary project: $($project.FullName)"
        }
    }
}

function global:Invoke-TemporaryProject {
    $arguments = @($args)
    if ($arguments.Count -lt 2) {
        $shortcut = if ($arguments.Count -gt 0) { [string] $arguments[0] } else { 'temporary project shortcut' }
        throw "Usage: $shortcut <name> [args...]"
    }

    $command = [string] $arguments[0]
    $name = [string] $arguments[1]
    $remaining = [object[]] @()
    if ($arguments.Count -gt 2) {
        $remaining = [object[]] $arguments[2..($arguments.Count - 1)]
    }

    if (
        [string]::IsNullOrWhiteSpace($name) -or
        $name -match '(^\.{1,2}$|^[-]|[\\/:*?"<>|]|\p{Cc}|[. ]$)'
    ) {
        throw "Invalid temporary project name: $name"
    }

    $sourcePath = 'C:\src'
    $projectPath = Join-Path -Path $sourcePath -ChildPath "tmp-$name"
    $existingProject = Get-Item -LiteralPath $projectPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $existingProject -and ($existingProject.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        throw "Temporary project path is a symbolic link or junction: $projectPath"
    }
    [System.IO.Directory]::CreateDirectory($projectPath) | Out-Null

    $commandSucceeded = $true
    $commandExitCode = $null
    $global:LASTEXITCODE = 0
    try {
        Push-Location -LiteralPath $projectPath
        try {
            & $command @remaining
            $commandSucceeded = $?
            $commandExitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Remove-StaleTemporaryProject -SourcePath $sourcePath
    }

    if ($null -ne $commandExitCode) {
        $global:LASTEXITCODE = $commandExitCode
    }
    $commandFailed = -not $commandSucceeded -or ($null -ne $commandExitCode -and $commandExitCode -ne 0)
    if ($commandFailed) {
        if ($null -ne $commandExitCode) {
            throw "Temporary project command '$command' exited with code $commandExitCode."
        }

        throw "Temporary project command '$command' failed."
    }
}

function global:Invoke-YoloClaudeTemporary { Invoke-TemporaryProject 'yc' @args }
function global:Invoke-YoloClaudeFableTemporary { Invoke-TemporaryProject 'ycf' @args }
function global:Invoke-YoloClaudeOpusTemporary { Invoke-TemporaryProject 'yco' @args }
function global:Invoke-YoloClaudeSonnetTemporary { Invoke-TemporaryProject 'ycs' @args }

function global:Invoke-YoloCodexTemporary { Invoke-TemporaryProject 'yx' @args }
function global:Invoke-YoloCodexSolTemporary { Invoke-TemporaryProject 'yxs' @args }
function global:Invoke-YoloCodexTerraTemporary { Invoke-TemporaryProject 'yxt' @args }
function global:Invoke-YoloCodexLunaTemporary { Invoke-TemporaryProject 'yxl' @args }
function global:Invoke-YoloCodexAstraTemporary { Invoke-TemporaryProject 'yxa' @args }

function global:Invoke-YoloOmpTemporary { Invoke-TemporaryProject 'yo' @args }
function global:Invoke-YoloOmpFableTemporary { Invoke-TemporaryProject 'yof' @args }
function global:Invoke-YoloOmpOpusTemporary { Invoke-TemporaryProject 'yoo' @args }
function global:Invoke-YoloOmpMimoTemporary { Invoke-TemporaryProject 'yom' @args }
function global:Invoke-YoloOmpSolTemporary { Invoke-TemporaryProject 'yos' @args }
function global:Invoke-YoloOmpTerraTemporary { Invoke-TemporaryProject 'yot' @args }
function global:Invoke-YoloOmpLunaTemporary { Invoke-TemporaryProject 'yol' @args }
function global:Invoke-YoloOmpAstraTemporary { Invoke-TemporaryProject 'yoa' @args }

function global:Invoke-PinnedYoloOmpTemporary { Invoke-TemporaryProject 'pyo' @args }
function global:Invoke-PinnedYoloOmpFableTemporary { Invoke-TemporaryProject 'pyof' @args }
function global:Invoke-PinnedYoloOmpOpusTemporary { Invoke-TemporaryProject 'pyoo' @args }
function global:Invoke-PinnedYoloOmpMimoTemporary { Invoke-TemporaryProject 'pyom' @args }
function global:Invoke-PinnedYoloOmpSolTemporary { Invoke-TemporaryProject 'pyos' @args }
function global:Invoke-PinnedYoloOmpTerraTemporary { Invoke-TemporaryProject 'pyot' @args }
function global:Invoke-PinnedYoloOmpLunaTemporary { Invoke-TemporaryProject 'pyol' @args }
function global:Invoke-PinnedYoloOmpAstraTemporary { Invoke-TemporaryProject 'pyoa' @args }

function global:Invoke-ShellGpt {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	$request = $Remaining -join ' '
	uvx --from shell-gpt sgpt.exe --no-cache --shell $request
}

function global:Set-LocationSrc {
    Set-Location C:\src
}

function global:Invoke-KillAll {
    param(
        [string] $Name
    )

    Get-Process $Name -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Information "Killing process $($_.Name) with Id $($_.Id)"

        Stop-Process -Id $_.Id -ErrorAction SilentlyContinue
    }
}

function global:Invoke-RmRf {
    param(
        [string] $Path
    )

    Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
}

Set-Alias -Scope Global -Name yc -Value Invoke-YoloClaude
Set-Alias -Scope Global -Name ycf -Value Invoke-YoloClaudeFable
Set-Alias -Scope Global -Name yco -Value Invoke-YoloClaudeOpus
Set-Alias -Scope Global -Name ycs -Value Invoke-YoloClaudeSonnet
Set-Alias -Scope Global -Name ycc -Value Invoke-YoloClaudeContinue
Set-Alias -Scope Global -Name ycfc -Value Invoke-YoloClaudeFableContinue
Set-Alias -Scope Global -Name ycoc -Value Invoke-YoloClaudeOpusContinue
Set-Alias -Scope Global -Name ycsc -Value Invoke-YoloClaudeSonnetContinue
Set-Alias -Scope Global -Name yx -Value Invoke-YoloCodex
Set-Alias -Scope Global -Name yxs -Value Invoke-YoloCodexSol
Set-Alias -Scope Global -Name yxt -Value Invoke-YoloCodexTerra
Set-Alias -Scope Global -Name yxl -Value Invoke-YoloCodexLuna
Set-Alias -Scope Global -Name yxa -Value Invoke-YoloCodexAstra
Set-Alias -Scope Global -Name yxc -Value Invoke-YoloCodexContinue
Set-Alias -Scope Global -Name yxsc -Value Invoke-YoloCodexSolContinue
Set-Alias -Scope Global -Name yxtc -Value Invoke-YoloCodexTerraContinue
Set-Alias -Scope Global -Name yxlc -Value Invoke-YoloCodexLunaContinue
Set-Alias -Scope Global -Name yxac -Value Invoke-YoloCodexAstraContinue
Set-Alias -Scope Global -Name yo -Value Invoke-YoloOmp
Set-Alias -Scope Global -Name omp-plugin-upgrade -Value Invoke-OmpPluginUpgrade
Set-Alias -Scope Global -Name pyu -Value Invoke-Pyu

Set-Alias -Scope Global -Name yof -Value Invoke-YoloOmpFable
Set-Alias -Scope Global -Name yoo -Value Invoke-YoloOmpOpus
Set-Alias -Scope Global -Name yom -Value Invoke-YoloOmpMimo
Set-Alias -Scope Global -Name yos -Value Invoke-YoloOmpSol
Set-Alias -Scope Global -Name yot -Value Invoke-YoloOmpTerra
Set-Alias -Scope Global -Name yol -Value Invoke-YoloOmpLuna
Set-Alias -Scope Global -Name yoa -Value Invoke-YoloOmpAstra
Set-Alias -Scope Global -Name yoc -Value Invoke-YoloOmpContinue
Set-Alias -Scope Global -Name yofc -Value Invoke-YoloOmpFableContinue
Set-Alias -Scope Global -Name yooc -Value Invoke-YoloOmpOpusContinue
Set-Alias -Scope Global -Name yomc -Value Invoke-YoloOmpMimoContinue
Set-Alias -Scope Global -Name yosc -Value Invoke-YoloOmpSolContinue
Set-Alias -Scope Global -Name yotc -Value Invoke-YoloOmpTerraContinue
Set-Alias -Scope Global -Name yolc -Value Invoke-YoloOmpLunaContinue
Set-Alias -Scope Global -Name yoac -Value Invoke-YoloOmpAstraContinue
Set-Alias -Scope Global -Name pyo -Value Invoke-PinnedYoloOmp
Set-Alias -Scope Global -Name pyof -Value Invoke-PinnedYoloOmpFable
Set-Alias -Scope Global -Name pyoo -Value Invoke-PinnedYoloOmpOpus
Set-Alias -Scope Global -Name pyom -Value Invoke-PinnedYoloOmpMimo
Set-Alias -Scope Global -Name pyos -Value Invoke-PinnedYoloOmpSol
Set-Alias -Scope Global -Name pyot -Value Invoke-PinnedYoloOmpTerra
Set-Alias -Scope Global -Name pyol -Value Invoke-PinnedYoloOmpLuna
Set-Alias -Scope Global -Name pyoa -Value Invoke-PinnedYoloOmpAstra
Set-Alias -Scope Global -Name pyoc -Value Invoke-PinnedYoloOmpContinue
Set-Alias -Scope Global -Name pyofc -Value Invoke-PinnedYoloOmpFableContinue
Set-Alias -Scope Global -Name pyooc -Value Invoke-PinnedYoloOmpOpusContinue
Set-Alias -Scope Global -Name pyomc -Value Invoke-PinnedYoloOmpMimoContinue
Set-Alias -Scope Global -Name pyosc -Value Invoke-PinnedYoloOmpSolContinue
Set-Alias -Scope Global -Name pyotc -Value Invoke-PinnedYoloOmpTerraContinue
Set-Alias -Scope Global -Name pyolc -Value Invoke-PinnedYoloOmpLunaContinue
Set-Alias -Scope Global -Name pyoac -Value Invoke-PinnedYoloOmpAstraContinue

# The hyphenated base names avoid collisions with existing shortcuts whose
# t suffix already has another meaning (yot, yxt, and pyot).
Set-Alias -Scope Global -Name yct -Value Invoke-YoloClaudeTemporary
Set-Alias -Scope Global -Name yc-t -Value Invoke-YoloClaudeTemporary
Set-Alias -Scope Global -Name ycft -Value Invoke-YoloClaudeFableTemporary
Set-Alias -Scope Global -Name ycot -Value Invoke-YoloClaudeOpusTemporary
Set-Alias -Scope Global -Name ycst -Value Invoke-YoloClaudeSonnetTemporary

Set-Alias -Scope Global -Name yxtt -Value Invoke-YoloCodexTerraTemporary
Set-Alias -Scope Global -Name yx-t -Value Invoke-YoloCodexTemporary
Set-Alias -Scope Global -Name yxst -Value Invoke-YoloCodexSolTemporary
Set-Alias -Scope Global -Name yxlt -Value Invoke-YoloCodexLunaTemporary
Set-Alias -Scope Global -Name yxat -Value Invoke-YoloCodexAstraTemporary

Set-Alias -Scope Global -Name yo-t -Value Invoke-YoloOmpTemporary
Set-Alias -Scope Global -Name yoft -Value Invoke-YoloOmpFableTemporary
Set-Alias -Scope Global -Name yoot -Value Invoke-YoloOmpOpusTemporary
Set-Alias -Scope Global -Name yomt -Value Invoke-YoloOmpMimoTemporary
Set-Alias -Scope Global -Name yost -Value Invoke-YoloOmpSolTemporary
Set-Alias -Scope Global -Name yott -Value Invoke-YoloOmpTerraTemporary
Set-Alias -Scope Global -Name yolt -Value Invoke-YoloOmpLunaTemporary
Set-Alias -Scope Global -Name yoat -Value Invoke-YoloOmpAstraTemporary

Set-Alias -Scope Global -Name pyo-t -Value Invoke-PinnedYoloOmpTemporary
Set-Alias -Scope Global -Name pyoft -Value Invoke-PinnedYoloOmpFableTemporary
Set-Alias -Scope Global -Name pyoot -Value Invoke-PinnedYoloOmpOpusTemporary
Set-Alias -Scope Global -Name pyomt -Value Invoke-PinnedYoloOmpMimoTemporary
Set-Alias -Scope Global -Name pyost -Value Invoke-PinnedYoloOmpSolTemporary
Set-Alias -Scope Global -Name pyott -Value Invoke-PinnedYoloOmpTerraTemporary
Set-Alias -Scope Global -Name pyolt -Value Invoke-PinnedYoloOmpLunaTemporary
Set-Alias -Scope Global -Name pyoat -Value Invoke-PinnedYoloOmpAstraTemporary
Set-Alias -Scope Global -Name src -Value Set-LocationSrc
Set-Alias -Scope Global -Name ?? -Value Invoke-ShellGpt
Set-Alias -Scope Global -Name which -Value 'C:\Windows\System32\where.exe'
Set-Alias -Scope Global -Name killall -Value Invoke-KillAll
Set-Alias -Scope Global -Name rmrf -Value Invoke-RmRf
