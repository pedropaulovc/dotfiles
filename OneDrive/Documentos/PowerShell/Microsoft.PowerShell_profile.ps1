$InformationPreference = 'Continue'

# Machine-local secrets — untracked, NOT in the dotfiles repo (mirrors the
# ~/.config/shell/secrets.sh hook in .bashrc). Define $env:CLAUDEX_* etc. here.
$secretsFile = Join-Path $HOME '.config\shell\secrets.ps1'
if (Test-Path $secretsFile) { . $secretsFile }

function Invoke-YoloClaude {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )
    
    # $env:CLAUDE_CODE_DISABLE_AUTO_UPDATE='1' 
	
	& C:\Users\pedro\.local\bin\claude.exe --verbose --disallowedTools "NotebookEdit" --dangerously-skip-permissions --name Local --remote-control @Remaining
}

# claudex — Windows twin of the .bashrc `claudex`. Runs the Claude Code harness
# against a Claude-compatible proxy/model without disturbing your normal claude.
# PowerShell has no inline `VAR=val cmd` prefix, so the overrides are set on
# $env: for the call and restored in finally. Proxy endpoint + token come from
# the untracked secrets.ps1; refuses to run if they're unset.
function Invoke-ClaudeX {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

    if (-not $env:CLAUDEX_BASE_URL -or -not $env:CLAUDEX_AUTH_TOKEN) {
        Write-Error 'claudex: set $env:CLAUDEX_BASE_URL and $env:CLAUDEX_AUTH_TOKEN in ~/.config/shell/secrets.ps1'
        return
    }

    $model = if ($env:CLAUDEX_MODEL) { $env:CLAUDEX_MODEL } else { 'gpt-5.6-sol' }

    $overrides = @{
        ANTHROPIC_BASE_URL                   = $env:CLAUDEX_BASE_URL
        ANTHROPIC_AUTH_TOKEN                 = $env:CLAUDEX_AUTH_TOKEN
        CLAUDE_CODE_SUBAGENT_MODEL           = $model
        CLAUDE_CODE_ALWAYS_ENABLE_EFFORT     = '1'
        CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY = '3'
        ENABLE_TOOL_SEARCH                   = 'false'
    }

    # Snapshot prior values so the overrides apply only to this invocation.
    $saved = @{}
    foreach ($k in $overrides.Keys) { $saved[$k] = (Get-Item "Env:$k" -ErrorAction SilentlyContinue).Value }

    try {
        foreach ($k in $overrides.Keys) { Set-Item "Env:$k" $overrides[$k] }
        & C:\Users\pedro\.local\bin\claude.exe --model $model @Remaining
    }
    finally {
        foreach ($k in $saved.Keys) {
            if ($null -eq $saved[$k]) { Remove-Item "Env:$k" -ErrorAction SilentlyContinue }
            else { Set-Item "Env:$k" $saved[$k] }
        }
    }
}

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
Set-Alias -Name claudex -Value Invoke-ClaudeX
Set-Alias -Name src -Value Set-LocationSrc
Set-Alias -Name ?? -Value Invoke-ShellGpt
Set-Alias -Name which -Value 'C:\Windows\System32\where.exe'
Set-Alias -Name killall -Value Invoke-KillAll
Set-Alias -Name rmrf -Value Invoke-RmRf