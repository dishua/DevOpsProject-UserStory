# ---------------------------------------------------------
#  cleanup.ps1
#  Stops and removes containers, images, volumes
#  for DevOpsProject-UserStory
# ---------------------------------------------------------

$ErrorActionPreference = "Stop"

# -- Paths -------------------------------------------------
$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = (Resolve-Path "$SCRIPT_DIR\..\.." ).Path
$CONFIG_DIR  = Join-Path $SCRIPT_DIR "config"
$VOLUME_NAME = "userstory_mariadb_data"
$env:COMPOSE_PROJECT_NAME = "userstory"

# -- Colors ------------------------------------------------
function Write-Cyan   { param($msg) Write-Host $msg -ForegroundColor Cyan    }
function Write-Green  { param($msg) Write-Host $msg -ForegroundColor Green   }
function Write-Yellow { param($msg) Write-Host $msg -ForegroundColor Yellow  }
function Write-Red    { param($msg) Write-Host $msg -ForegroundColor Red     }

Write-Host ""
Write-Red  "╔══════════════════════════════════════════╗"
Write-Red  "║        DevOpsProject-UserStory           ║"
Write-Red  "║              Docker Cleanup              ║"
Write-Red  "╚══════════════════════════════════════════╝"
Write-Host ""

# -- Save start location -----------------------------------
$startLocation = Get-Location

# -- Check Docker ------------------------------------------
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Red "[ERROR] Docker not found."
    exit 1
}

# -- Check if anything was ever deployed -------------------
Set-Location $CONFIG_DIR

$volumeExists = $false
try {
    docker volume inspect $VOLUME_NAME 2>$null | Out-Null
    $volumeExists = ($LASTEXITCODE -eq 0)
} catch { $volumeExists = $false }

$copiedFiles = @(
    [IO.Path]::Combine($PROJECT_DIR, "backend", "Dockerfile"),
    [IO.Path]::Combine($PROJECT_DIR, "frontend", "Dockerfile"),
    [IO.Path]::Combine($PROJECT_DIR, "frontend", "nginx.conf"),
    [IO.Path]::Combine($PROJECT_DIR, "db")
)
$filesExist = $false
foreach ($f in $copiedFiles) {
    if (Test-Path -LiteralPath $f) { $filesExist = $true; break }
}

if (-not $volumeExists -and -not $filesExist) {
    Write-Yellow "[INFO] No existing deployment found."
    Write-Yellow "       Volume $VOLUME_NAME not detected and no copied files found."
    exit 0
}

Write-Host ""
if ($volumeExists) {
    Write-Green "  [found] Volume: $VOLUME_NAME"
} else {
    Write-Yellow "  [none]  Volume: $VOLUME_NAME not found"
}

foreach ($f in $copiedFiles) {
    if (Test-Path -LiteralPath $f) {
        $rel = $f.Replace($PROJECT_DIR + "", "")
        Write-Green "  [found] File:   $rel"
    }
}
Write-Host ""

# -- Select cleanup level ----------------------------------
Write-Host "Select cleanup level:"
Write-Host ""
Write-Green "  1) Soft    - stop containers, remove copied files"
Write-Green "  2) Full    - + remove volume (database data will be lost!)"
Write-Green "  3) Nuclear - + remove Docker images"
Write-Green "  4) Exit without changes"
Write-Host ""
$level = Read-Host "Your choice [1/2/3/4]"

if ($level -eq "4") {
    Write-Yellow "Exit without changes."
    exit 0
}

if ($level -notin @("1","2","3")) {
    Write-Red "[ERROR] Invalid choice. Exiting."
    exit 1
}

# -- Confirm -----------------------------------------------
Write-Host ""
if ($level -in @("2","3")) {
    Write-Red "!! WARNING: This action is irreversible! Database data will be deleted! !!"
}
$confirm = Read-Host "Continue? [y/N]"
if ($confirm -notmatch "^[Yy]$") {
    Write-Yellow "Cancelled."
    exit 0
}

Write-Host ""

# -- Step 1: Stop and remove containers -------------------
Write-Cyan "[1/3] Stopping containers..."

# Use Continue so docker stderr warnings don't abort the script
$prevPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"

$hasContainers = $false
try {
    $ps = docker compose ps -q 2>$null
    $hasContainers = ($null -ne $ps -and @($ps).Count -gt 0)
} catch { $hasContainers = $false }

if ($level -in @("2","3")) {
    docker compose down -v 2>$null
    if ($hasContainers) {
        Write-Green "  [OK] Containers stopped, volume removed"
    } else {
        Write-Yellow "  [--] No containers were running, volume removed"
    }
} else {
    docker compose down 2>$null
    if ($hasContainers) {
        Write-Green "  [OK] Containers stopped"
    } else {
        Write-Yellow "  [--] No containers were running"
    }
}

$ErrorActionPreference = $prevPref

# -- Step 2: Remove Docker images -------------------------
Write-Host ""
if ($level -eq "3") {
    Write-Cyan "[2/3] Removing Docker images..."

    $ErrorActionPreference = "Continue"
    $images = @("userstory-backend", "userstory-frontend")
    foreach ($image in $images) {
        docker image inspect $image 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            docker rmi $image 2>$null | Out-Null
            Write-Green "  [OK] Removed image: $image"
        } else {
            Write-Yellow "  [--] Image not found: $image"
        }
    }
    $ErrorActionPreference = "Stop"
} else {
    Write-Yellow "[2/3] Image removal - skipped"
}

# -- Step 3: Remove copied files --------------------------
Write-Host ""
Write-Cyan "[3/3] Removing copied files..."

$filesToRemove = @(
    [IO.Path]::Combine($PROJECT_DIR, "backend", "Dockerfile"),
    [IO.Path]::Combine($PROJECT_DIR, "frontend", "Dockerfile"),
    [IO.Path]::Combine($PROJECT_DIR, "frontend", "nginx.conf")
)

foreach ($file in $filesToRemove) {
    if (Test-Path -LiteralPath $file) {
        Remove-Item -LiteralPath $file -Force
        $relative = $file.Replace($PROJECT_DIR + "\", "")
        Write-Green "  [OK] Removed: $relative"
    } else {
        $relative = $file.Replace($PROJECT_DIR + "\", "")
        Write-Yellow "  [--] Not found: $relative"
    }
}

$dbPath = [IO.Path]::Combine($PROJECT_DIR, "db")
if (Test-Path -LiteralPath $dbPath) {
    Remove-Item -LiteralPath $dbPath -Recurse -Force
    Write-Green "  [OK] Removed: db/"
} else {
    Write-Yellow "  [--] Not found: db/"
}

# -- Result -----------------------------------------------
Write-Host ""
Write-Green "╔══════════════════════════════════════════╗"
Write-Green "║           Cleanup complete!  [OK]        ║"
Write-Green "╚══════════════════════════════════════════╝"
Write-Host ""

switch ($level) {
    "1" { Write-Host "  Done: containers stopped, copied files removed" }
    "2" { Write-Host "  Done: containers + volume removed, files removed" }
    "3" { Write-Host "  Done: containers + volume + images removed, files removed" }
}

Write-Host ""
Write-Cyan "  To deploy again: .\deploy.ps1"
Write-Host ""

Set-Location $startLocation