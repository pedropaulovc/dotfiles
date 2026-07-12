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
# against the local LiteLLM proxy (OpenAI backend) without disturbing your
# normal claude. Start the proxy first with `claudex-proxy`. PowerShell has no
# inline `VAR=val cmd` prefix, so overrides are set on $env: for the call and
# restored in finally.
function Invoke-ClaudeX {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

    $model = if ($env:CLAUDEX_MODEL) { $env:CLAUDEX_MODEL } else { 'gpt-5.6-sol' }
    $base  = if ($env:CLAUDEX_BASE_URL) { $env:CLAUDEX_BASE_URL } else { 'http://127.0.0.1:4000' }
    $token = if ($env:CLAUDEX_AUTH_TOKEN) { $env:CLAUDEX_AUTH_TOKEN } else { 'sk-claudex-local' }

    try { $null = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Uri "$base/v1/models" -Headers @{ 'x-api-key' = $token } }
    catch { Write-Error "claudex: proxy not reachable at $base — start it with: claudex-proxy"; return }

    $overrides = @{
        ANTHROPIC_BASE_URL                   = $base
        ANTHROPIC_AUTH_TOKEN                 = $token
        CLAUDE_CODE_SUBAGENT_MODEL           = $model
        CLAUDE_CODE_ALWAYS_ENABLE_EFFORT     = '1'
        CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY = '3'
        ENABLE_TOOL_SEARCH                   = 'false'
    }

    # Snapshot prior values so the overrides apply only to this invocation.
    $saved = @{}
    foreach ($k in $overrides.Keys) { $saved[$k] = (Get-Item "Env:$k" -ErrorAction SilentlyContinue).Value }

    $exitCode = 0
    try {
        foreach ($k in $overrides.Keys) { Set-Item "Env:$k" $overrides[$k] }
        & C:\Users\pedro\.local\bin\claude.exe --model $model @Remaining
        $exitCode = $LASTEXITCODE
    }
    finally {
        foreach ($k in $saved.Keys) {
            if ($null -eq $saved[$k]) { Remove-Item "Env:$k" -ErrorAction SilentlyContinue }
            else { Set-Item "Env:$k" $saved[$k] }
        }
    }
    # The restore cmdlets don't touch $LASTEXITCODE, but re-emit it explicitly so
    # `pwsh -Command 'claudex …'` propagates claude.exe's status to callers,
    # matching the bash wrapper (whose last command is the claude call).
    $global:LASTEXITCODE = $exitCode
}

# claudex-proxy — Windows twin of the .bashrc `claudex-proxy`. Starts the
# LiteLLM proxy `claudex` points at, routing an Anthropic /v1/messages endpoint
# on localhost to OpenAI per ~/.config/litellm/config.yaml. Foreground (Ctrl-C
# to stop). Reads $env:OPENAI_API_KEY from secrets.ps1; pinned to Python 3.13.
function Invoke-ClaudexProxy {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )

    if (-not $env:OPENAI_API_KEY) {
        Write-Error 'claudex-proxy: set $env:OPENAI_API_KEY in ~/.config/shell/secrets.ps1'
        return
    }

    $port   = if ($env:CLAUDEX_PROXY_PORT) { $env:CLAUDEX_PROXY_PORT } else { '4000' }
    $config = Join-Path $HOME '.config\litellm\config.yaml'
    uvx --python 3.13 --from 'litellm[proxy]' litellm --config $config --host 127.0.0.1 --port $port @Remaining
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
Set-Alias -Name claudex-proxy -Value Invoke-ClaudexProxy
Set-Alias -Name src -Value Set-LocationSrc
Set-Alias -Name ?? -Value Invoke-ShellGpt
Set-Alias -Name which -Value 'C:\Windows\System32\where.exe'
Set-Alias -Name killall -Value Invoke-KillAll
Set-Alias -Name rmrf -Value Invoke-RmRf