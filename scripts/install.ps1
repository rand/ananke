# Ananke Installation Script for Windows
# Installs Ananke constraint-driven code generation system
# Usage: irm https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.ps1 | iex
# Or: .\scripts\install.ps1 [-Prefix "C:\path\to\install"]

param(
    [string]$Prefix = "$env:LOCALAPPDATA\ananke",
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

# Configuration
$Repo = "ananke-ai/ananke"
$InstallDir = "$Prefix\bin"
$LibDir = "$Prefix\lib"
$IncludeDir = "$Prefix\include"

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput $Message "Green"
}

function Write-Error-Custom {
    param([string]$Message)
    Write-ColorOutput "Error: $Message" "Red"
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-ColorOutput "Warning: $Message" "Yellow"
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput $Message "Cyan"
}

# Detect architecture
function Get-Architecture {
    $arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")

    switch ($arch) {
        "AMD64" { return "x86_64" }
        "ARM64" { return "aarch64" }
        default {
            Write-Error-Custom "Unsupported architecture: $arch"
            exit 1
        }
    }
}

# Check system requirements
function Test-Requirements {
    Write-Info "[1/6] Checking system requirements..."

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        Write-Error-Custom "PowerShell 5.0 or later is required (found $psVersion)"
        exit 1
    }

    # Check for .NET Framework or .NET Core (needed for some operations)
    try {
        $null = [System.Net.ServicePointManager]::SecurityProtocol
    }
    catch {
        Write-Error-Custom "Unable to access .NET networking libraries"
        exit 1
    }

    Write-Success "✓ System requirements satisfied"
}

# Get latest release version
function Get-LatestVersion {
    $apiUrl = "https://api.github.com/repos/$Repo/releases/latest"

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get
        return $response.tag_name
    }
    catch {
        Write-Error-Custom "Failed to fetch latest version: $_"
        exit 1
    }
}

# Download file with progress
function Download-File {
    param(
        [string]$Url,
        [string]$Output
    )

    try {
        # Use BITS transfer for better progress reporting if available
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $Url -Destination $Output -Description "Downloading $(Split-Path $Output -Leaf)"
        }
        else {
            # Fallback to Invoke-WebRequest
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $Url -OutFile $Output
            $ProgressPreference = 'Continue'
        }
    }
    catch {
        Write-Error-Custom "Download failed: $_"
        exit 1
    }
}

# Download and extract Ananke
function Install-Ananke {
    param(
        [string]$Version,
        [string]$Architecture
    )

    Write-Info "[2/6] Downloading Ananke $Version for Windows-$Architecture..."

    if ($Version -eq "latest") {
        $Version = Get-LatestVersion
    }

    $archiveName = "ananke-$Version-windows-$Architecture.zip"
    $downloadUrl = "https://github.com/$Repo/releases/download/$Version/$archiveName"
    $tempDir = [System.IO.Path]::GetTempPath()
    $archivePath = Join-Path $tempDir $archiveName

    Download-File -Url $downloadUrl -Output $archivePath

    Write-Success "✓ Downloaded $archiveName"

    # Download and verify checksum
    Write-Info "[3/6] Verifying checksum..."
    $checksumUrl = "$downloadUrl.sha256"
    $checksumPath = "$archivePath.sha256"

    try {
        Download-File -Url $checksumUrl -Output $checksumPath

        $expectedHash = (Get-Content $checksumPath).Split()[0]
        $actualHash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLower()

        if ($expectedHash -ne $actualHash) {
            Write-Error-Custom "Checksum verification failed"
            Write-Error-Custom "Expected: $expectedHash"
            Write-Error-Custom "Got: $actualHash"
            exit 1
        }

        Write-Success "✓ Checksum verified"
    }
    catch {
        Write-Warning-Custom "Checksum verification skipped (file not found)"
    }

    # Extract archive
    Write-Info "[4/6] Extracting archive..."
    $extractDir = Join-Path $tempDir "ananke-extract"

    if (Test-Path $extractDir) {
        Remove-Item -Path $extractDir -Recurse -Force
    }

    Expand-Archive -Path $archivePath -DestinationPath $extractDir -Force
    Write-Success "✓ Extracted successfully"

    # Install binaries
    Write-Info "[5/6] Installing Ananke..."

    # Create installation directories
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    New-Item -ItemType Directory -Path $LibDir -Force | Out-Null
    New-Item -ItemType Directory -Path $IncludeDir -Force | Out-Null

    # Find extracted directory
    $extractedDir = Get-ChildItem -Path $extractDir -Directory | Where-Object { $_.Name -like "ananke-*" } | Select-Object -First 1

    if (-not $extractedDir) {
        Write-Error-Custom "Extracted directory not found"
        exit 1
    }

    # Install binary
    $binaryPath = Join-Path $extractedDir.FullName "bin\ananke.exe"
    if (Test-Path $binaryPath) {
        Copy-Item -Path $binaryPath -Destination $InstallDir -Force
        Write-Success "✓ Installed binary to $InstallDir\ananke.exe"
    }
    else {
        Write-Error-Custom "Binary not found in archive"
        exit 1
    }

    # Install libraries
    $libPath = Join-Path $extractedDir.FullName "lib"
    if (Test-Path $libPath) {
        Copy-Item -Path "$libPath\*" -Destination $LibDir -Recurse -Force
        Write-Success "✓ Installed libraries to $LibDir"
    }

    # Install headers
    $includePath = Join-Path $extractedDir.FullName "include"
    if (Test-Path $includePath) {
        Copy-Item -Path "$includePath\*" -Destination $IncludeDir -Recurse -Force
        Write-Success "✓ Installed headers to $IncludeDir"
    }

    # Cleanup
    Remove-Item -Path $archivePath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $checksumPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Verify installation
function Test-Installation {
    Write-Info "[6/6] Verifying installation..."

    $binaryPath = Join-Path $InstallDir "ananke.exe"

    if (-not (Test-Path $binaryPath)) {
        Write-Error-Custom "Binary not found at $binaryPath"
        exit 1
    }

    # Try to run version command
    try {
        $null = & $binaryPath --version 2>&1
        Write-Success "✓ Installation verified successfully"
    }
    catch {
        Write-Warning-Custom "Binary installed but version check failed"
        Write-Warning-Custom "This may be normal if dependencies are missing"
    }
}

# Add to PATH
function Add-ToPath {
    Write-Info "Checking PATH configuration..."

    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")

    if ($userPath -notlike "*$InstallDir*") {
        Write-Info "Adding $InstallDir to user PATH..."

        $newPath = "$InstallDir;$userPath"
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")

        # Update current session
        $env:Path = "$InstallDir;$env:Path"

        Write-Success "✓ Added to PATH (restart your terminal for changes to take effect)"
    }
    else {
        Write-Success "✓ Already in PATH"
    }
}

# Print success message
function Write-SuccessMessage {
    param([string]$Version)

    Write-Host ""
    Write-Success "================================================"
    Write-Success "  Ananke $Version installed successfully!"
    Write-Success "================================================"
    Write-Host ""
    Write-Host "Installation location: $InstallDir\ananke.exe"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Restart your terminal (or start a new PowerShell session)"
    Write-Host ""
    Write-Host "  2. Verify installation:"
    Write-Host "     ananke --version"
    Write-Host ""
    Write-Host "  3. Get started:"
    Write-Host "     ananke help"
    Write-Host ""
    Write-Host "Documentation: https://github.com/$Repo/blob/main/README.md"
    Write-Host "Quickstart: https://github.com/$Repo/blob/main/QUICKSTART.md"
    Write-Host ""
}

# Main installation flow
function Main {
    Write-Info "═══════════════════════════════════════════════"
    Write-Info "  Ananke Installation Script for Windows"
    Write-Info "═══════════════════════════════════════════════"
    Write-Host ""

    $architecture = Get-Architecture
    Write-Host "Platform: Windows-$architecture"
    Write-Host "Install prefix: $Prefix"
    Write-Host ""

    Test-Requirements
    Install-Ananke -Version $Version -Architecture $architecture
    Test-Installation
    Add-ToPath
    Write-SuccessMessage -Version $Version
}

# Run main function
try {
    Main
}
catch {
    Write-Error-Custom "Installation failed: $_"
    exit 1
}
