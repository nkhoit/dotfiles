Invoke-Expression (&starship init powershell)

Set-Alias -Name vi -Value nvim
Set-Alias -Name vim -Value nvim

function copilot { & copilot.exe --yolo @args }

# --- Vi mode ---
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Cursor

# --- Shell behavior ---
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -HistorySearchCursorMovesToEnd

# Keep familiar shortcuts in insert mode
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key Shift+Tab -Function MenuComplete

# --- PSFzf (fuzzy finder integration) ---
Import-Module PSFzf

# Ctrl+T  = fuzzy file search, Ctrl+R = fuzzy history search
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# Tab completion uses fzf when multiple matches exist
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }

# Alt+C = fuzzy cd into subdirectory
Set-PsFzfOption -PSReadlineChordSetLocation 'Alt+c'

# Unix-like ls: columns without dotfiles; supports -a, -l, -la
Remove-Alias -Name ls -Force -ErrorAction SilentlyContinue
function ls {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Args_)
    $showAll = $false; $long = $false; $paths = @()
    foreach ($a in $Args_) {
        if ($a -match '^-') {
            if ($a -match 'a') { $showAll = $true }
            if ($a -match 'l') { $long = $true }
        } else { $paths += $a }
    }
    if (-not $paths) { $paths = @('.') }
    $items = Get-ChildItem -Path $paths -Force:$showAll
    if (-not $showAll) { $items = $items | Where-Object { $_.Name -notmatch '^\.' } }
    if ($long) { $items } else { $items | Format-Wide -Property Name -AutoSize }
}
