if ($Host.Name -eq 'ConsoleHost') {
    Invoke-Expression (&starship init powershell)
}

# ----- Local overrides (not versioned) — env vars, machine-specific aliases, etc. -----
$localProfile = "$PROFILE.local"
if (Test-Path $localProfile) { . "$localProfile" }

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
                       -AltCCommand { param($Location) [Console]::SetCursorPosition(0, [Console]::CursorTop - 1); Set-Location $Location; if (Get-Command zoxide -ErrorAction SilentlyContinue) { zoxide add -- $Location } }

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

# ----- Linux staples (not provided by coreutils) -----
function which { (Get-Command @args).Source }
function mkcd { param([string]$Dir) New-Item -ItemType Directory -Path $Dir -Force | Out-Null; Set-Location $Dir }
# grep -> rg only as a fallback where coreutils' real grep isn't on PATH
if ((Get-Command rg -ErrorAction SilentlyContinue) -and -not (Get-Command grep -CommandType Application -ErrorAction SilentlyContinue)) { Set-Alias grep rg }

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

# ----- Coreutils (microsoft/coreutils): prefer native UNIX commands -----
# Installed by install.ps1 (winget Microsoft.Coreutils): uutils coreutils + findutils
# + grep + xargs as one multi-call binary. Commands with no PowerShell name conflict
# (touch, head, tail, wc, find, xargs, ...) already resolve from PATH, but PS ships
# aliases (ls -> Get-ChildItem, cat -> Get-Content, ...) and a mkdir *function* that
# shadow the rest. Unshadow only names that resolve to a real executable, so this
# respects `coreutils-manager disable <util>` and is a no-op where coreutils isn't
# installed. The cmdlets stay reachable by full name (Sort-Object, Tee-Object, ...).
if (Get-Command coreutils-manager -ErrorAction SilentlyContinue) {
    foreach ($u in 'cat', 'cp', 'ls', 'mv', 'rm', 'rmdir', 'echo', 'pwd', 'sort', 'tee', 'sleep') {
        if ((Test-Path "Alias:\$u") -and (Get-Command $u -CommandType Application -ErrorAction SilentlyContinue)) {
            Remove-Alias $u -Force -ErrorAction SilentlyContinue
        }
    }
    # mkdir is a PS function (no -p support); the coreutils one handles -p properly
    if ((Test-Path 'Function:\mkdir') -and (Get-Command mkdir -CommandType Application -ErrorAction SilentlyContinue)) {
        Remove-Item 'Function:\mkdir' -Force
    }
}
