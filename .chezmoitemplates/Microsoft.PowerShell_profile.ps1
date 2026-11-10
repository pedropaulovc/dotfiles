$InformationPreference = 'Continue'

Remove-Item -Path @(
    'Alias:yom'
    'Alias:yomc'
    'Alias:yomt'
    'Alias:pyom'
    'Alias:pyomc'
    'Alias:pyomt'
    'Function:Invoke-YoloOmpMimo'
    'Function:Invoke-YoloOmpMimoContinue'
    'Function:Invoke-YoloOmpMimoTemporary'
    'Function:Invoke-PinnedYoloOmpMimo'
    'Function:Invoke-PinnedYoloOmpMimoContinue'
    'Function:Invoke-PinnedYoloOmpMimoTemporary'
) -ErrorAction SilentlyContinue

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

function global:Invoke-YoloOmpFable { Invoke-YoloOmp       --model anthropic/claude-fable-5-2:medium --thinking medium --smol anthropic/claude-haiku-5-5:max --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-2:xhigh @args }
function global:Invoke-YoloOmpOpus  { Invoke-YoloOmp       --model anthropic/claude-opus-5-5:medium  --thinking medium --smol anthropic/claude-haiku-5-5:max --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-2:xhigh @args }
function global:Invoke-YoloOmpHaiku { Invoke-YoloOmp --model anthropic/claude-haiku-5-5 --thinking max --smol anthropic/claude-haiku-5-5:max --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-2:xhigh @args }
function global:Invoke-YoloOmpContinue      { Invoke-YoloOmp       --continue @args }
function global:Invoke-YoloOmpFableContinue { Invoke-YoloOmpFable       --continue @args }
function global:Invoke-YoloOmpHaikuContinue { Invoke-YoloOmpHaiku --continue @args }
function global:Invoke-YoloOmpOpusContinue  { Invoke-YoloOmpOpus       --continue @args }

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
function global:Invoke-PinnedYoloOmpFable { Invoke-PinnedYoloOmp --model anthropic/claude-fable-5-2:medium --thinking medium --smol anthropic/claude-haiku-5-5:max --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-2:xhigh @args }
function global:Invoke-PinnedYoloOmpOpus  { Invoke-PinnedYoloOmp --model anthropic/claude-opus-5-5:medium --thinking medium --smol anthropic/claude-haiku-5-5:max --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-2:xhigh @args }
function global:Invoke-PinnedYoloOmpHaiku { Invoke-PinnedYoloOmp --model anthropic/claude-haiku-5-5 --thinking max --smol anthropic/claude-haiku-5-5:max --slow anthropic/claude-opus-5-5:medium --plan anthropic/claude-fable-5-2:xhigh @args }
function global:Invoke-PinnedYoloOmpContinue      { Invoke-PinnedYoloOmp --continue @args }
function global:Invoke-PinnedYoloOmpFableContinue { Invoke-PinnedYoloOmpFable --continue @args }
function global:Invoke-PinnedYoloOmpHaikuContinue { Invoke-PinnedYoloOmpHaiku --continue @args }
function global:Invoke-PinnedYoloOmpOpusContinue  { Invoke-PinnedYoloOmpOpus --continue @args }

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

function global:Invoke-YoloOmpTemporary { Invoke-TemporaryProject 'yo' @args }
function global:Invoke-YoloOmpFableTemporary { Invoke-TemporaryProject 'yof' @args }
function global:Invoke-YoloOmpHaikuTemporary { Invoke-TemporaryProject 'yoh' @args }
function global:Invoke-YoloOmpOpusTemporary { Invoke-TemporaryProject 'yoo' @args }

function global:Invoke-PinnedYoloOmpTemporary { Invoke-TemporaryProject 'pyo' @args }
function global:Invoke-PinnedYoloOmpFableTemporary { Invoke-TemporaryProject 'pyof' @args }
function global:Invoke-PinnedYoloOmpHaikuTemporary { Invoke-TemporaryProject 'pyoh' @args }
function global:Invoke-PinnedYoloOmpOpusTemporary { Invoke-TemporaryProject 'pyoo' @args }

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
Set-Alias -Scope Global -Name yo -Value Invoke-YoloOmp
Set-Alias -Scope Global -Name omp-plugin-upgrade -Value Invoke-OmpPluginUpgrade
Set-Alias -Scope Global -Name pyu -Value Invoke-Pyu

Set-Alias -Scope Global -Name yof -Value Invoke-YoloOmpFable
Set-Alias -Scope Global -Name yoh -Value Invoke-YoloOmpHaiku
Set-Alias -Scope Global -Name yoo -Value Invoke-YoloOmpOpus
Set-Alias -Scope Global -Name yoc -Value Invoke-YoloOmpContinue
Set-Alias -Scope Global -Name yofc -Value Invoke-YoloOmpFableContinue
Set-Alias -Scope Global -Name yohc -Value Invoke-YoloOmpHaikuContinue
Set-Alias -Scope Global -Name yooc -Value Invoke-YoloOmpOpusContinue
Set-Alias -Scope Global -Name pyo -Value Invoke-PinnedYoloOmp
Set-Alias -Scope Global -Name pyof -Value Invoke-PinnedYoloOmpFable
Set-Alias -Scope Global -Name pyoh -Value Invoke-PinnedYoloOmpHaiku
Set-Alias -Scope Global -Name pyoo -Value Invoke-PinnedYoloOmpOpus
Set-Alias -Scope Global -Name pyoc -Value Invoke-PinnedYoloOmpContinue
Set-Alias -Scope Global -Name pyofc -Value Invoke-PinnedYoloOmpFableContinue
Set-Alias -Scope Global -Name pyohc -Value Invoke-PinnedYoloOmpHaikuContinue
Set-Alias -Scope Global -Name pyooc -Value Invoke-PinnedYoloOmpOpusContinue

# The hyphenated base names avoid collisions with existing shortcuts whose
# t suffix already has another meaning (yct).
Set-Alias -Scope Global -Name yct -Value Invoke-YoloClaudeTemporary
Set-Alias -Scope Global -Name yc-t -Value Invoke-YoloClaudeTemporary
Set-Alias -Scope Global -Name ycft -Value Invoke-YoloClaudeFableTemporary
Set-Alias -Scope Global -Name ycot -Value Invoke-YoloClaudeOpusTemporary
Set-Alias -Scope Global -Name ycst -Value Invoke-YoloClaudeSonnetTemporary


Set-Alias -Scope Global -Name yo-t -Value Invoke-YoloOmpTemporary
Set-Alias -Scope Global -Name yoft -Value Invoke-YoloOmpFableTemporary
Set-Alias -Scope Global -Name yoht -Value Invoke-YoloOmpHaikuTemporary
Set-Alias -Scope Global -Name yoot -Value Invoke-YoloOmpOpusTemporary

Set-Alias -Scope Global -Name pyo-t -Value Invoke-PinnedYoloOmpTemporary
Set-Alias -Scope Global -Name pyoft -Value Invoke-PinnedYoloOmpFableTemporary
Set-Alias -Scope Global -Name pyoht -Value Invoke-PinnedYoloOmpHaikuTemporary
Set-Alias -Scope Global -Name pyoot -Value Invoke-PinnedYoloOmpOpusTemporary
Set-Alias -Scope Global -Name src -Value Set-LocationSrc
Set-Alias -Scope Global -Name ?? -Value Invoke-ShellGpt
Set-Alias -Scope Global -Name which -Value 'C:\Windows\System32\where.exe'
Set-Alias -Scope Global -Name killall -Value Invoke-KillAll
Set-Alias -Scope Global -Name rmrf -Value Invoke-RmRf
