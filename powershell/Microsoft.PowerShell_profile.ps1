if ($Host.Name -eq 'ConsoleHost') {
    Invoke-Expression (&starship init powershell)
}

# ----- PSReadLine: Vi mode -----
# Skip PSReadLine in neovim's embedded terminal (redirected I/O breaks predictions)
if ($Host.Name -eq 'ConsoleHost' -and -not $env:NVIM -and [Console]::OutputEncoding -and -not [Console]::IsOutputRedirected) {
    Import-Module PSReadLine -MinimumVersion 2.2 -ErrorAction SilentlyContinue

    Set-PSReadLineOption -EditMode Vi
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
    Set-PSReadLineOption -PredictionViewStyle InlineView
    Set-PSReadLineOption -MaximumHistoryCount 20000
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -ShowToolTips:$false

    # Vi mode: cursor shape changes instantly (block=normal, line=insert)
    Set-PSReadLineOption -ViModeIndicator Cursor

    # History search with arrow keys
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # ----- PSFzf: fuzzy finder integration -----
    if ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Import-Module PSFzf -PassThru -ErrorAction SilentlyContinue)) {
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' `
                       -AltCCommand { param($Location) [Console]::SetCursorPosition(0, [Console]::CursorTop - 1); Set-Location $Location; zoxide add -- $Location }

        # Tab: use fzf for completion, with fuzzy directory fallback for cd
        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock {
            param($key, $arg)
            $line = $null; $cursor = $null
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

            $isCd = $line -match '^\s*(cd|Set-Location|Push-Location|sl)\s+(.*?)$'
            if ($isCd) {
                $word = $Matches[2].Trim() -replace '^[''"]|[''"]$'
                $completions = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $cursor, $null)
                if ($completions.CompletionMatches.Count -eq 0 -and $word) {
                    if ($word -match '^(.+)[/\\](.*)$') {
                        $baseDir = $Matches[1]; $query = $Matches[2]
                    } else { $baseDir = '.'; $query = $word }
                    $pick = Get-ChildItem -Path $baseDir -Directory -Force -ErrorAction SilentlyContinue |
                        ForEach-Object { $_.Name } |
                        fzf --query $query --select-1 --exit-0 --height=~40% --reverse
                    if ($pick) {
                        $rel = if ($baseDir -eq '.') { $pick } else { Join-Path $baseDir $pick }
                        $c = if ($rel -match '\s') { "'$rel'" } else { $rel }
                        $cmdLen = ([regex]::Match($line, '^\s*(cd|Set-Location|Push-Location|sl)\s+')).Length
                        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($cmdLen, $cursor - $cmdLen, $c)
                    }
                    return
                }
            }
            Invoke-FzfTabCompletion
        }

        Set-PSReadLineKeyHandler -Key Shift+Tab -Function MenuComplete
    } else {
        Set-PSReadLineKeyHandler -Key Tab        -Function MenuComplete
        Set-PSReadLineKeyHandler -Key Shift+Tab  -Function MenuComplete
    }
}

if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Set-Alias vi nvim
    Set-Alias vim nvim
    $env:EDITOR = 'nvim'
}

function copilot { & (Get-Command copilot.exe).Source --yolo @args }

# ----- Linux staples -----
function which { (Get-Command @args).Source }
function touch { param([Parameter(ValueFromRemainingArguments)]$Path)
    foreach ($p in $Path) {
        if (Test-Path $p) { (Get-Item $p).LastWriteTime = Get-Date }
        else { New-Item $p -ItemType File | Out-Null }
    }
}
function mkcd { param([string]$Dir) New-Item -ItemType Directory -Path $Dir -Force | Out-Null; Set-Location $Dir }
if (Get-Command rg -ErrorAction SilentlyContinue) { Set-Alias grep rg }

# ----- Git shortcuts -----
function gs { git --no-pager status -sb @args }
function gl { git --no-pager log --oneline -20 @args }
function gd { git --no-pager diff --no-ext-diff @args }

# ----- Navigation -----
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& zoxide init powershell | Out-String)
}

# ----- Git Worktree helpers -----
function gwc {
    param([Parameter(Mandatory)][string]$Feature)
    $branch = "dev/khoitran/$Feature"
    $root = git rev-parse --show-toplevel 2>$null
    if (-not $root) { Write-Error "Not in a git repository"; return }
    $repo = Split-Path $root -Leaf
    $dest = Join-Path (Split-Path $root) "$repo-feature-$Feature"
    git worktree add $dest -b $branch
    if ($LASTEXITCODE -eq 0) { $dest }
}

function gwcv {
    param([Parameter(Mandatory)][string]$Feature)
    $dest = gwc $Feature
    if (-not $dest) { return }
    Set-Location $dest
    code .
}

function gwcc {
    param([Parameter(Mandatory)][string]$Feature)
    $dest = gwc $Feature
    if (-not $dest) { return }
    Set-Location $dest
    copilot
}

function gwd {
    $root = git rev-parse --show-toplevel 2>$null
    if (-not $root) { Write-Error "Not in a git repository"; return }
    $mainWorktree = Split-Path (git rev-parse --path-format=absolute --git-common-dir 2>$null)
    if ($root -eq $mainWorktree) { Write-Error "gwd: already on main worktree, nothing to remove"; return }
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    Set-Location $mainWorktree
    [System.IO.Directory]::SetCurrentDirectory((Resolve-Path $mainWorktree))
    git worktree remove $root --force
    git branch -D $branch 2>$null
}

# ----- Unix-like rm -----
Remove-Alias rm -Force -ErrorAction SilentlyContinue

function rm {
    param(
        [switch]$r,
        [switch]$f,
        [switch]$rf,
        [switch]$fr,
        [Parameter(ValueFromRemainingArguments)]$Path
    )
    if (-not $Path) { Write-Error "rm: missing operand"; return }

    $recurse = $r -or $rf -or $fr
    $force = $f -or $rf -or $fr

    foreach ($p in $Path) {
        $params = @{ Path = $p; ErrorAction = if ($force) { 'SilentlyContinue' } else { 'Stop' } }
        if ($recurse) { $params.Recurse = $true }
        if ($force) { $params.Force = $true; $params.Confirm = $false }
        Remove-Item @params
    }
}

# ----- Linux-like ls -----
Remove-Alias ls -Force -ErrorAction SilentlyContinue

function ls {
    param(
        [switch]$l,
        [switch]$a,
        [switch]$la,
        [switch]$al,
        [Parameter(ValueFromRemainingArguments)]$Path
    )
    $paths = if ($Path) { @($Path) } else { @(".") }
    $showHidden = $a -or $la -or $al
    $showDetails = $l -or $la -or $al
    $multiPath = $paths.Count -gt 1

    foreach ($targetPath in $paths) {
        if ($multiPath) { Write-Host "${targetPath}:" }

        if ($showHidden) {
            $items = Get-ChildItem -Path $targetPath -Force
        } else {
            $items = Get-ChildItem -Path $targetPath -Force | Where-Object {
                $_.Name -notlike '.*' -and
                -not ($_.Attributes -band [IO.FileAttributes]::Hidden) -and
                -not ($_.Attributes -band [IO.FileAttributes]::System)
            }
        }

        if ($showDetails) {
            $items | Format-Table -AutoSize Mode, LastWriteTime, Length, Name
        } else {
            $names = @($items | ForEach-Object { $_.Name })
            if ($names.Count -eq 0) { if ($multiPath) { Write-Host }; continue }
            $maxLen = ($names | Measure-Object -Maximum -Property Length).Maximum + 2
            $width = $Host.UI.RawUI.WindowSize.Width
            $cols = [Math]::Max(1, [Math]::Floor($width / $maxLen))
            $i = 0
            foreach ($name in $names) {
                Write-Host -NoNewline ($name.PadRight($maxLen))
                $i++
                if ($i % $cols -eq 0) { Write-Host }
            }
            if ($i % $cols -ne 0) { Write-Host }
        }
        if ($multiPath) { Write-Host }
    }
}
