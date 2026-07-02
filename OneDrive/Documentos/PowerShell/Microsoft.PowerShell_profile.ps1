$InformationPreference = 'Continue'

function Invoke-YoloClaude {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Remaining
    )
    
    # $env:CLAUDE_CODE_DISABLE_AUTO_UPDATE='1' 
	
	& C:\Users\pedro\.local\bin\claude.exe --verbose --disallowedTools "NotebookEdit" --dangerously-skip-permissions --name Local --remote-control @Remaining
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
Set-Alias -Name src -Value Set-LocationSrc
Set-Alias -Name ?? -Value Invoke-ShellGpt
Set-Alias -Name which -Value 'C:\Windows\System32\where.exe'
Set-Alias -Name killall -Value Invoke-KillAll
Set-Alias -Name rmrf -Value Invoke-RmRf