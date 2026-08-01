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
Set-Alias -Name src -Value Set-LocationSrc
Set-Alias -Name ?? -Value Invoke-ShellGpt
Set-Alias -Name which -Value 'C:\Windows\System32\where.exe'
Set-Alias -Name killall -Value Invoke-KillAll
Set-Alias -Name rmrf -Value Invoke-RmRf
