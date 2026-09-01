$InformationPreference = 'Continue'

$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

function Invoke-YoloClaude {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

    # $env:CLAUDE_CODE_DISABLE_AUTO_UPDATE='1'

	& C:\Users\pedro\.local\bin\claude.exe --verbose --disallowedTools "NotebookEdit" --dangerously-skip-permissions --name $env:COMPUTERNAME --remote-control @Remaining
}

function Invoke-YoloClaudeFable {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& C:\Users\pedro\.local\bin\claude.exe --verbose --disallowedTools "NotebookEdit" --dangerously-skip-permissions --name $env:COMPUTERNAME --remote-control --model fable --effort high @Remaining
}

function Invoke-YoloClaudeOpus {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& C:\Users\pedro\.local\bin\claude.exe --verbose --disallowedTools "NotebookEdit" --dangerously-skip-permissions --name $env:COMPUTERNAME --remote-control --model opus --effort high @Remaining
}

function Invoke-YoloClaudeSonnet {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& C:\Users\pedro\.local\bin\claude.exe --verbose --disallowedTools "NotebookEdit" --dangerously-skip-permissions --name $env:COMPUTERNAME --remote-control --model sonnet --effort high @Remaining
}

function Invoke-YoloClaudeContinue { Invoke-YoloClaude --continue @args }
function Invoke-YoloClaudeFableContinue { Invoke-YoloClaudeFable --continue @args }
function Invoke-YoloClaudeOpusContinue { Invoke-YoloClaudeOpus --continue @args }
function Invoke-YoloClaudeSonnetContinue { Invoke-YoloClaudeSonnet --continue @args }

function Invoke-YoloCodex {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& codex --dangerously-bypass-approvals-and-sandbox @Remaining
}

function Invoke-YoloCodexSol {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& codex --dangerously-bypass-approvals-and-sandbox --model gpt-5.6-sol -c 'model_reasoning_effort="high"' @Remaining
}

function Invoke-YoloCodexTerra {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	& codex --dangerously-bypass-approvals-and-sandbox --model gpt-5.6-terra -c 'model_reasoning_effort="max"' @Remaining
}

function Invoke-YoloCodexLuna {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )
	& codex --dangerously-bypass-approvals-and-sandbox --model gpt-5.6-luna -c 'model_reasoning_effort="max"' @Remaining
}

function Invoke-YoloCodexContinue { Invoke-YoloCodex resume --last @args }
function Invoke-YoloCodexSolContinue { Invoke-YoloCodexSol resume --last @args }
function Invoke-YoloCodexTerraContinue { Invoke-YoloCodexTerra resume --last @args }
function Invoke-YoloCodexLunaContinue { Invoke-YoloCodexLuna resume --last @args }

function Invoke-YoloOmp { & omp --auto-approve @args }
function Invoke-YoloOmpFable { Invoke-YoloOmp --provider anthropic --model claude-fable-5 --thinking high @args }
function Invoke-YoloOmpOpus { Invoke-YoloOmp --provider anthropic --model claude-opus-5 --thinking high @args }
function Invoke-YoloOmpSol { Invoke-YoloOmp --provider openai-codex --model gpt-5.6-sol --thinking high @args }
function Invoke-YoloOmpTerra { Invoke-YoloOmp --provider openai-codex --model gpt-5.6-terra --thinking max @args }
function Invoke-YoloOmpLuna { Invoke-YoloOmp --provider openai-codex --model gpt-5.6-luna --thinking max @args }
function Invoke-YoloOmpContinue { Invoke-YoloOmp --continue @args }
function Invoke-YoloOmpFableContinue { Invoke-YoloOmpFable --continue @args }
function Invoke-YoloOmpOpusContinue { Invoke-YoloOmpOpus --continue @args }
function Invoke-YoloOmpSolContinue { Invoke-YoloOmpSol --continue @args }
function Invoke-YoloOmpTerraContinue { Invoke-YoloOmpTerra --continue @args }
function Invoke-YoloOmpLunaContinue { Invoke-YoloOmpLuna --continue @args }

# Run a temporary copy of the reviewed binary so pyo sessions do not lock the original.
$pyoBinary = 'C:\src\dogfood\omp-windows-x64.exe'
function Invoke-PinnedYoloOmp {
	$tempBinary = Join-Path ([System.IO.Path]::GetTempPath()) "omp-pyo-$([guid]::NewGuid()).exe"

	try {
		Copy-Item -LiteralPath $pyoBinary -Destination $tempBinary -ErrorAction Stop
		& $tempBinary --auto-approve @args
	}
	finally {
		Remove-Item -LiteralPath $tempBinary -Force -ErrorAction SilentlyContinue
	}
}
function Invoke-PinnedYoloOmpFable { Invoke-PinnedYoloOmp --provider anthropic --model claude-fable-5 --thinking high @args }
function Invoke-PinnedYoloOmpOpus { Invoke-PinnedYoloOmp --provider anthropic --model claude-opus-5 --thinking high @args }
function Invoke-PinnedYoloOmpSol { Invoke-PinnedYoloOmp --provider openai-codex --model gpt-5.6-sol --thinking high @args }
function Invoke-PinnedYoloOmpTerra { Invoke-PinnedYoloOmp --provider openai-codex --model gpt-5.6-terra --thinking max @args }
function Invoke-PinnedYoloOmpLuna { Invoke-PinnedYoloOmp --provider openai-codex --model gpt-5.6-luna --thinking max @args }
function Invoke-PinnedYoloOmpContinue { Invoke-PinnedYoloOmp --continue @args }
function Invoke-PinnedYoloOmpFableContinue { Invoke-PinnedYoloOmpFable --continue @args }
function Invoke-PinnedYoloOmpOpusContinue { Invoke-PinnedYoloOmpOpus --continue @args }
function Invoke-PinnedYoloOmpSolContinue { Invoke-PinnedYoloOmpSol --continue @args }
function Invoke-PinnedYoloOmpTerraContinue { Invoke-PinnedYoloOmpTerra --continue @args }
function Invoke-PinnedYoloOmpLunaContinue { Invoke-PinnedYoloOmpLuna --continue @args }
# Run an agent shortcut in a temporary project under C:\src\tmp-<name>.
# Temporary projects are removed after seven days without any file or
# directory modification. Continue shortcuts (the *c variants) are
# intentionally not wrapped.
function Remove-StaleTemporaryProjects {
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

        if ($latest -ge $cutoff) {
            continue
        }

        Write-Information "Removing stale temporary project: $($project.FullName)"
        Remove-Item -LiteralPath $project.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-TemporaryProject {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Command,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Name,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]] $Remaining
    )

    if (
        [string]::IsNullOrWhiteSpace($Name) -or
        $Name -match '(^\.{1,2}$|^[-]|[\\/:*?"<>|]|\p{Cc}|[. ]$)'
    ) {
        throw "Invalid temporary project name: $Name"
    }

    $sourcePath = 'C:\src'
    $projectPath = Join-Path -Path $sourcePath -ChildPath "tmp-$Name"
    [System.IO.Directory]::CreateDirectory($projectPath) | Out-Null

    try {
        Push-Location -LiteralPath $projectPath
        try {
            & $Command @Remaining
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Remove-StaleTemporaryProjects -SourcePath $sourcePath
    }
}

function Invoke-YoloClaudeTemporary { Invoke-TemporaryProject 'yc' @args }
function Invoke-YoloClaudeFableTemporary { Invoke-TemporaryProject 'ycf' @args }
function Invoke-YoloClaudeOpusTemporary { Invoke-TemporaryProject 'yco' @args }
function Invoke-YoloClaudeSonnetTemporary { Invoke-TemporaryProject 'ycs' @args }

function Invoke-YoloCodexTemporary { Invoke-TemporaryProject 'yx' @args }
function Invoke-YoloCodexSolTemporary { Invoke-TemporaryProject 'yxs' @args }
function Invoke-YoloCodexTerraTemporary { Invoke-TemporaryProject 'yxt' @args }
function Invoke-YoloCodexLunaTemporary { Invoke-TemporaryProject 'yxl' @args }

function Invoke-YoloOmpTemporary { Invoke-TemporaryProject 'yo' @args }
function Invoke-YoloOmpFableTemporary { Invoke-TemporaryProject 'yof' @args }
function Invoke-YoloOmpOpusTemporary { Invoke-TemporaryProject 'yoo' @args }
function Invoke-YoloOmpSolTemporary { Invoke-TemporaryProject 'yos' @args }
function Invoke-YoloOmpTerraTemporary { Invoke-TemporaryProject 'yot' @args }
function Invoke-YoloOmpLunaTemporary { Invoke-TemporaryProject 'yol' @args }

function Invoke-PinnedYoloOmpTemporary { Invoke-TemporaryProject 'pyo' @args }
function Invoke-PinnedYoloOmpFableTemporary { Invoke-TemporaryProject 'pyof' @args }
function Invoke-PinnedYoloOmpOpusTemporary { Invoke-TemporaryProject 'pyoo' @args }
function Invoke-PinnedYoloOmpSolTemporary { Invoke-TemporaryProject 'pyos' @args }
function Invoke-PinnedYoloOmpTerraTemporary { Invoke-TemporaryProject 'pyot' @args }
function Invoke-PinnedYoloOmpLunaTemporary { Invoke-TemporaryProject 'pyol' @args }

function Invoke-ShellGpt {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

	$request = $Remaining -join ' '
	uvx --from shell-gpt sgpt.exe --no-cache --shell $request
}

function Set-LocationSrc {
    Set-Location C:\src
}

function Invoke-KillAll {
    param(
        [string] $Name
    )

    Get-Process $Name -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Information "Killing process $($_.Name) with Id $($_.Id)"

        Stop-Process -Id $_.Id -ErrorAction SilentlyContinue
    }
}

function Invoke-RmRf {
    param(
        [string] $Path
    )

    Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
}

Set-Alias -Name yc -Value Invoke-YoloClaude
Set-Alias -Name ycf -Value Invoke-YoloClaudeFable
Set-Alias -Name yco -Value Invoke-YoloClaudeOpus
Set-Alias -Name ycs -Value Invoke-YoloClaudeSonnet
Set-Alias -Name ycc -Value Invoke-YoloClaudeContinue
Set-Alias -Name ycfc -Value Invoke-YoloClaudeFableContinue
Set-Alias -Name ycoc -Value Invoke-YoloClaudeOpusContinue
Set-Alias -Name ycsc -Value Invoke-YoloClaudeSonnetContinue
Set-Alias -Name yx -Value Invoke-YoloCodex
Set-Alias -Name yxs -Value Invoke-YoloCodexSol
Set-Alias -Name yxt -Value Invoke-YoloCodexTerra
Set-Alias -Name yxl -Value Invoke-YoloCodexLuna
Set-Alias -Name yxc -Value Invoke-YoloCodexContinue
Set-Alias -Name yxsc -Value Invoke-YoloCodexSolContinue
Set-Alias -Name yxtc -Value Invoke-YoloCodexTerraContinue
Set-Alias -Name yxlc -Value Invoke-YoloCodexLunaContinue
Set-Alias -Name yo -Value Invoke-YoloOmp
Set-Alias -Name yof -Value Invoke-YoloOmpFable
Set-Alias -Name yoo -Value Invoke-YoloOmpOpus
Set-Alias -Name yos -Value Invoke-YoloOmpSol
Set-Alias -Name yot -Value Invoke-YoloOmpTerra
Set-Alias -Name yol -Value Invoke-YoloOmpLuna
Set-Alias -Name yoc -Value Invoke-YoloOmpContinue
Set-Alias -Name yofc -Value Invoke-YoloOmpFableContinue
Set-Alias -Name yooc -Value Invoke-YoloOmpOpusContinue
Set-Alias -Name yosc -Value Invoke-YoloOmpSolContinue
Set-Alias -Name yotc -Value Invoke-YoloOmpTerraContinue
Set-Alias -Name yolc -Value Invoke-YoloOmpLunaContinue
Set-Alias -Name pyo -Value Invoke-PinnedYoloOmp
Set-Alias -Name pyof -Value Invoke-PinnedYoloOmpFable
Set-Alias -Name pyoo -Value Invoke-PinnedYoloOmpOpus
Set-Alias -Name pyos -Value Invoke-PinnedYoloOmpSol
Set-Alias -Name pyot -Value Invoke-PinnedYoloOmpTerra
Set-Alias -Name pyol -Value Invoke-PinnedYoloOmpLuna
Set-Alias -Name pyoc -Value Invoke-PinnedYoloOmpContinue
Set-Alias -Name pyofc -Value Invoke-PinnedYoloOmpFableContinue
Set-Alias -Name pyooc -Value Invoke-PinnedYoloOmpOpusContinue
Set-Alias -Name pyosc -Value Invoke-PinnedYoloOmpSolContinue
Set-Alias -Name pyotc -Value Invoke-PinnedYoloOmpTerraContinue
Set-Alias -Name pyolc -Value Invoke-PinnedYoloOmpLunaContinue

# The hyphenated base names avoid collisions with existing shortcuts whose
# t suffix already has another meaning (yot, yxt, and pyot).
Set-Alias -Name yct -Value Invoke-YoloClaudeTemporary
Set-Alias -Name yc-t -Value Invoke-YoloClaudeTemporary
Set-Alias -Name ycft -Value Invoke-YoloClaudeFableTemporary
Set-Alias -Name ycot -Value Invoke-YoloClaudeOpusTemporary
Set-Alias -Name ycst -Value Invoke-YoloClaudeSonnetTemporary

Set-Alias -Name yxtt -Value Invoke-YoloCodexTerraTemporary
Set-Alias -Name yx-t -Value Invoke-YoloCodexTemporary
Set-Alias -Name yxst -Value Invoke-YoloCodexSolTemporary
Set-Alias -Name yxlt -Value Invoke-YoloCodexLunaTemporary

Set-Alias -Name yo-t -Value Invoke-YoloOmpTemporary
Set-Alias -Name yoft -Value Invoke-YoloOmpFableTemporary
Set-Alias -Name yoot -Value Invoke-YoloOmpOpusTemporary
Set-Alias -Name yost -Value Invoke-YoloOmpSolTemporary
Set-Alias -Name yott -Value Invoke-YoloOmpTerraTemporary
Set-Alias -Name yolt -Value Invoke-YoloOmpLunaTemporary

Set-Alias -Name pyo-t -Value Invoke-PinnedYoloOmpTemporary
Set-Alias -Name pyoft -Value Invoke-PinnedYoloOmpFableTemporary
Set-Alias -Name pyoot -Value Invoke-PinnedYoloOmpOpusTemporary
Set-Alias -Name pyost -Value Invoke-PinnedYoloOmpSolTemporary
Set-Alias -Name pyott -Value Invoke-PinnedYoloOmpTerraTemporary
Set-Alias -Name pyolt -Value Invoke-PinnedYoloOmpLunaTemporary
Set-Alias -Name src -Value Set-LocationSrc
Set-Alias -Name ?? -Value Invoke-ShellGpt
Set-Alias -Name which -Value 'C:\Windows\System32\where.exe'
Set-Alias -Name killall -Value Invoke-KillAll
Set-Alias -Name rmrf -Value Invoke-RmRf
