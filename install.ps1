#Requires -Version 5.1
<#
.SYNOPSIS
    Dotfiles installer for Windows.
.DESCRIPTION
    Sets up neovim, starship, fzf, ripgrep, fd, and links config files.
    Run from an elevated PowerShell or ensure Developer Mode is enabled for symlinks.
.EXAMPLE
    # One-liner from the internet:
    irm https://raw.githubusercontent.com/nkhoit/dotfiles/main/install.ps1 | iex
    # Or clone first:
    git clone git@github.com:nkhoit/dotfiles.git $HOME\.dotfiles; & $HOME\.dotfiles\install.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DotfilesDir = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME '.dotfiles' }
$DotfilesRepo = if ($env:DOTFILES_REPO) { $env:DOTFILES_REPO } else { 'https://github.com/nkhoit/dotfiles.git' }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Info  { param([string]$Msg) Write-Host "[info]  $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "[ok]    $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "[warn]  $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "[error] $Msg" -ForegroundColor Red; exit 1 }

function Test-Command { param([string]$Name) $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

function Test-SymlinkSupport {
    $testFile = Join-Path $env:TEMP "dotfiles_symlink_test_$(Get-Random)"
    $testLink = "${testFile}_link"
    try {
        Set-Content $testFile "test"
        New-Item -ItemType SymbolicLink -Path $testLink -Target $testFile -ErrorAction Stop | Out-Null
        Remove-Item $testLink, $testFile -Force
        return $true
    } catch {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        return $false
    }
}

# ---------------------------------------------------------------------------
# Install packages via winget
# ---------------------------------------------------------------------------
function Install-WingetPackage {
    param([string]$Id, [string]$Name)
    if (-not (winget list --id $Id 2>$null | Select-String $Id)) {
        Write-Info "Installing ${Name}..."
        winget install --id $Id --accept-source-agreements --accept-package-agreements --silent
    } else {
        Write-Ok "${Name} already installed"
    }
}

function Install-Packages {
    if (-not (Test-Command winget)) {
        Write-Err "winget is required but not found. Install App Installer from the Microsoft Store."
    }

    Install-WingetPackage 'Git.Git'           'Git'
    Install-WingetPackage 'Neovim.Neovim'     'Neovim'
    Install-WingetPackage 'Neovide.Neovide'   'Neovide'
    Install-WingetPackage 'Starship.Starship'  'Starship'
    Install-WingetPackage 'junegunn.fzf'       'fzf'
    Install-WingetPackage 'BurntSushi.ripgrep.MSVC' 'ripgrep'
    Install-WingetPackage 'sharkdp.fd'         'fd'
    Install-WingetPackage 'OpenJS.NodeJS.LTS'  'Node.js'
    Install-WingetPackage 'Python.Python.3.12' 'Python'

    # Refresh PATH so newly installed tools are found
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')

    # Nerd Font (CaskaydiaCove) — install from Nerd Fonts GitHub release
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    if (-not (Test-Path (Join-Path $fontDir 'CaskaydiaCoveNerdFont-Regular.ttf'))) {
        Write-Info "Installing CaskaydiaCove Nerd Font..."
        try {
            $release = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
            $asset = $release.assets | Where-Object { $_.name -eq 'CascadiaCode.zip' } | Select-Object -First 1
            if (-not $asset) { throw "CascadiaCode.zip not found in latest Nerd Fonts release" }

            $tmpZip = Join-Path $env:TEMP 'CascadiaCode-NerdFont.zip'
            $tmpDir = Join-Path $env:TEMP 'CascadiaCode-NerdFont'
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip -UseBasicParsing
            if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
            Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

            if (-not (Test-Path $fontDir)) { New-Item -ItemType Directory -Path $fontDir -Force | Out-Null }
            $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
            if (-not (Test-Path $regPath)) { New-Item $regPath -Force | Out-Null }
            Get-ChildItem $tmpDir -Filter '*.ttf' | ForEach-Object {
                $dest = Join-Path $fontDir $_.Name
                if (-not (Test-Path $dest)) { Copy-Item $_.FullName $dest -Force }
                # Register per-user so apps see the font without admin/relog
                $regName = "$($_.BaseName) (TrueType)"
                if (-not (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
                    New-ItemProperty -Path $regPath -Name $regName -Value $dest -PropertyType String -Force | Out-Null
                }
            }
            Remove-Item $tmpZip, $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warn "Could not auto-install CaskaydiaCove Nerd Font: $($_.Exception.Message)"
            Write-Warn "Install manually from https://github.com/ryanoasis/nerd-fonts/releases"
        }
    }

    # PSFzf module
    if (-not (Get-Module PSFzf -ListAvailable)) {
        Write-Info "Installing PSFzf PowerShell module..."
        Install-Module -Name PSFzf -Scope CurrentUser -Force -AcceptLicense
    }
    Write-Ok "All packages installed"
}

# ---------------------------------------------------------------------------
# Clone / update dotfiles
# ---------------------------------------------------------------------------
function Setup-DotfilesRepo {
    if (Test-Path (Join-Path $DotfilesDir '.git')) {
        Write-Info "Updating dotfiles repo..."
        git -C $DotfilesDir pull --rebase --quiet
    } else {
        if (Test-Path $DotfilesDir) { Remove-Item $DotfilesDir -Recurse -Force }
        Write-Info "Cloning dotfiles repo..."
        git clone $DotfilesRepo $DotfilesDir
    }
    Write-Ok "Dotfiles repo ready at ${DotfilesDir}"
}

# ---------------------------------------------------------------------------
# Symlink / copy helper
# ---------------------------------------------------------------------------
$UseSymlinks = $false

function Link-Config {
    param([string]$Source, [string]$Target)

    # Back up existing
    if ((Test-Path $Target) -and -not (Get-Item $Target -Force).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
        $backup = "${Target}.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Write-Warn "Backing up ${Target} → ${backup}"
        Move-Item $Target $backup
    } elseif (Test-Path $Target) {
        Remove-Item $Target -Force -Recurse
    }

    $parentDir = Split-Path $Target -Parent
    if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }

    if ($UseSymlinks) {
        if (Test-Path $Source -PathType Container) {
            New-Item -ItemType Junction -Path $Target -Target $Source | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
        }
        Write-Ok "Linked ${Target} → ${Source}"
    } else {
        Copy-Item -Path $Source -Destination $Target -Recurse -Force
        Write-Ok "Copied ${Source} → ${Target}"
        Write-Warn "  (Enable Developer Mode for symlinks — changes won't auto-sync with git pull)"
    }
}

function Create-Symlinks {
    Write-Info "Linking config files..."

    # Test symlink support
    $script:UseSymlinks = Test-SymlinkSupport
    if (-not $UseSymlinks) {
        Write-Warn "Symlinks not available — falling back to copy. Enable Developer Mode for symlinks."
    }

    # Neovim
    Link-Config (Join-Path $DotfilesDir 'nvim') (Join-Path $env:LOCALAPPDATA 'nvim')

    # Neovide (uses %APPDATA%\neovide on Windows)
    Link-Config (Join-Path $DotfilesDir 'neovide\config.toml') (Join-Path $env:APPDATA 'neovide\config.toml')

    # Starship
    $starshipDir = Join-Path $HOME '.config'
    Link-Config (Join-Path $DotfilesDir 'starship\starship.toml') (Join-Path $starshipDir 'starship.toml')

    # PowerShell profile
    $profileDir = Split-Path $PROFILE -Parent
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
    Link-Config (Join-Path $DotfilesDir 'powershell\Microsoft.PowerShell_profile.ps1') $PROFILE

    # AI agent instructions (shared by Copilot CLI and opencode)
    $copilotDir = Join-Path $HOME '.copilot'
    if (-not (Test-Path $copilotDir)) { New-Item -ItemType Directory -Path $copilotDir -Force | Out-Null }
    Link-Config (Join-Path $DotfilesDir 'ai\instructions.md') (Join-Path $copilotDir 'copilot-instructions.md')

    $opencodeDir = Join-Path $HOME '.config\opencode'
    if (-not (Test-Path $opencodeDir)) { New-Item -ItemType Directory -Path $opencodeDir -Force | Out-Null }
    Link-Config (Join-Path $DotfilesDir 'ai\instructions.md') (Join-Path $opencodeDir 'AGENTS.md')
}

# ===========================================================================
# Main
# ===========================================================================
function Main {
    Write-Info "Starting dotfiles setup for Windows..."

    Install-Packages
    Setup-DotfilesRepo
    Create-Symlinks

    Write-Host ""
    Write-Ok "✨ Dotfiles setup complete!"
    Write-Info "Restart your terminal to apply changes."
    Write-Info "Neovim will auto-install plugins on first launch — just run: nvim"
}

Main
