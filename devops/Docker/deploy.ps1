# ---------------------------------------------------------
#  deploy.ps1
#  Copies Dockerfiles to project folders and starts
#  docker-compose for DevOpsProject-UserStory
# ---------------------------------------------------------

$ErrorActionPreference = "Stop"

# -- Paths -------------------------------------------------
$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = (Resolve-Path "$SCRIPT_DIR\..\..").Path
#$CONFIG_DIR  = "$SCRIPT_DIR\config"
$CONFIG_DIR  = (Resolve-Path "$SCRIPT_DIR\..\config").Path
$DOCKER_DIR = (Resolve-Path "$SCRIPT_DIR\config").Path
$VOLUME_NAME = "userstory_mariadb_data"
$env:COMPOSE_PROJECT_NAME = "userstory"

# -- Colors ------------------------------------------------
function Write-Cyan   { param($msg) Write-Host $msg -ForegroundColor Cyan    }
function Write-Green  { param($msg) Write-Host $msg -ForegroundColor Green   }
function Write-Yellow { param($msg) Write-Host $msg -ForegroundColor Yellow  }
function Write-Red    { param($msg) Write-Host $msg -ForegroundColor Red     }

Write-Host ""
Write-Cyan  "╔══════════════════════════════════════════╗"
Write-Cyan  "║        DevOpsProject-UserStory           ║"
Write-Cyan  "║              Docker Deploy               ║"
Write-Cyan  "╚══════════════════════════════════════════╝"
Write-Host ""

# -- Save starting directory ------------------------------
$startDir = Get-Location

# -- Check Docker -----------------------------------------
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Red "[ERROR] Docker not found. Install Docker Desktop and try again."
    exit 1
}
try { docker info 2>$null | Out-Null } catch {}
if ($LASTEXITCODE -ne 0) {
    Write-Red "[ERROR] Docker daemon is not running. Start Docker Desktop and try again."
    exit 1
}
try { docker compose version | Out-Null }
catch {
    Write-Red "[ERROR] Docker Compose not found."
    exit 1
}

# -- Function: setup .env ---------------------------------
function Setup-Env {
    Write-Host ""
    Write-Cyan "Setting up environment variables (.env)"
    Write-Host ""

    # DB_ROOT_PASSWORD - required, hidden input via SecureString
    do {
        $secRootPass = Read-Host "  DB_ROOT_PASSWORD (MariaDB root password)" -AsSecureString
        if ($secRootPass.Length -eq 0) { Write-Red "  [X] Password cannot be empty" }
    } while ($secRootPass.Length -eq 0)
    $bstrRoot = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secRootPass)
    $DB_ROOT_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstrRoot)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstrRoot)

    # DB_USERSTORYPROJ_USER - optional (default: userstory)
    do {
        $inputUser = (Read-Host "  DB_USERSTORYPROJ_USER (database user) [default: userstory]").Trim()

        if ([string]::IsNullOrWhiteSpace($inputUser)) {
            $inputUser = "userstory"
        }

        $isValid = $true

        if ($inputUser -eq "root") {
            Write-Red "  [X] Username cannot be 'root'."
            $isValid = $false
        }
        elseif ($inputUser -match "\s") {
            Write-Red "  [X] Username cannot contain spaces."
            $isValid = $false
        }
        elseif ($inputUser -notmatch '^[a-zA-Z0-9_]+$') {
            Write-Red "  [X] Username can only contain letters, numbers, and underscores (_)."
            $isValid = $false
        }
    } while (-not $isValid)
    $DB_USERSTORYPROJ_USER = $inputUser

    # DB_USERSTORYPROJ_PASSWORD - required, hidden input via SecureString
    do {
        $secPass = Read-Host "  DB_USERSTORYPROJ_PASSWORD (database user password)" -AsSecureString
        if ($secPass.Length -eq 0) { Write-Red "  [X] Password cannot be empty" }
    } while ($secPass.Length -eq 0)
    $bstrPass = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPass)
    $DB_USERSTORYPROJ_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstrPass)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstrPass)

    $projectDirForward = $PROJECT_DIR -replace "\\", "/"
    $envContent = "COMPOSE_PROJECT_NAME=userstory`r`nDB_ROOT_PASSWORD=$DB_ROOT_PASSWORD`r`nDB_USERSTORYPROJ_USER=$DB_USERSTORYPROJ_USER`r`nDB_USERSTORYPROJ_PASSWORD=$DB_USERSTORYPROJ_PASSWORD`r`nPROJECT_DIR=$projectDirForward`r`n"
    [System.IO.File]::WriteAllText("$CONFIG_DIR\.env", $envContent, [System.Text.Encoding]::UTF8)

    # Restrict .env to current user only
    icacls "$CONFIG_DIR\.env" /inheritance:r /grant:r "${env:USERNAME}:(R,W)" 2>$null | Out-Null

    # Clear plaintext passwords from memory
    $DB_ROOT_PASSWORD = $null; $DB_USERSTORYPROJ_PASSWORD = $null
    Remove-Variable DB_ROOT_PASSWORD, DB_USERSTORYPROJ_PASSWORD -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Green "  [OK] .env created successfully (restricted permissions)"
    Write-Host ""
}

# -- Check .env -------------------------------------------
if (-not (Test-Path -LiteralPath "$CONFIG_DIR\.env")) {
    Write-Yellow "[WARN] .env file not found."

    if (-not (Test-Path -LiteralPath "$CONFIG_DIR\.env.example")) {
        Write-Red "[ERROR] .env.example not found. Check project structure."
        exit 1
    }

    Write-Host "Choose an option:"
    Write-Green "  1) Enter values now (interactive)"
    Write-Green "  2) Copy .env.example and fill in manually later"
    Write-Host ""
    $envChoice = Read-Host "Your choice [1/2]"

    switch ($envChoice) {
        "1" { Setup-Env }
        "2" {
            Copy-Item "$CONFIG_DIR\.env.example" "$CONFIG_DIR\.env"
            icacls "$CONFIG_DIR\.env" /inheritance:r /grant:r "${env:USERNAME}:(R,W)" 2>$null | Out-Null
            Write-Yellow "[WARN] Edit $CONFIG_DIR\.env and run the script again."
            Set-Location $startDir
            exit 0
        }
        default {
            Write-Red "[ERROR] Invalid choice. Exiting."
            Set-Location $startDir
            exit 1
        }
    }
}

# -- Always update PROJECT_DIR in .env (atomic write) -----
Set-Location $CONFIG_DIR
$projectDirForward = $PROJECT_DIR -replace "\\", "/"

$envLines = Get-Content "$CONFIG_DIR\.env" | Where-Object { $_ -notmatch "^PROJECT_DIR=" }
$envLines += "PROJECT_DIR=$projectDirForward"
# Write directly — icacls applied after to restrict access
[System.IO.File]::WriteAllLines("$CONFIG_DIR\.env", $envLines, [System.Text.Encoding]::UTF8)
icacls "$CONFIG_DIR\.env" /inheritance:r /grant:r "${env:USERNAME}:(R,W)" 2>$null | Out-Null

# -- Switching to the dir with Docker files -----
Set-Location $DOCKER_DIR

# Переменная с явным указанием пути к .env для docker compose
$ENV_FILE = "$CONFIG_DIR\.env"

# -- Check if first deploy or re-deploy -------------------
$volumeExists = $false
try {
    docker volume inspect $VOLUME_NAME 2>$null | Out-Null
    $volumeExists = ($LASTEXITCODE -eq 0)
} catch { $volumeExists = $false }

if ($volumeExists) {

    # RE-DEPLOY
    Write-Yellow "[INFO] Existing deployment detected (volume: $VOLUME_NAME)"
    Write-Host ""

    $runningList = $null
    try {
        $runningList = docker compose --env-file $ENV_FILE ps --services --filter "status=running" 2>$null |
                       Where-Object { $_.Trim() -ne "" }
    } catch { $runningList = $null }
    $runningCount = if ($runningList) { @($runningList).Count } else { 0 }

    if ($runningCount -gt 0) {
        Write-Green "[INFO] Containers are running:"
        docker compose --env-file $ENV_FILE ps --format "table {{.Name}}`t{{.Status}}"
    } else {
        Write-Yellow "[INFO] Containers are stopped."
    }

    Write-Host ""
    Write-Host "What would you like to do?"
    Write-Green "  1) Start normally          (docker compose up -d)"
    Write-Green "  2) Restart without rebuild (docker compose restart)"
    Write-Green "  3) Rebuild and restart     (docker compose up --build -d)"
    Write-Green "  4) Exit without changes"
    Write-Host ""
    $choice = Read-Host "Your choice [1/2/3/4]"

    switch ($choice) {
        "1" {
            Write-Cyan "Starting containers..."
            docker compose --env-file $ENV_FILE up -d
            if ($LASTEXITCODE -ne 0) { Write-Red "[ERROR] Failed."; exit 1 }
        }
        "2" {
            Write-Cyan "Restarting containers..."
            docker compose --env-file $ENV_FILE restart
        }
        "3" {
            Write-Cyan "Rebuilding and restarting..."
            docker compose up --env-file $ENV_FILE --build -d
            if ($LASTEXITCODE -ne 0) { Write-Red "[ERROR] Failed."; exit 1 }
        }
        "4" {
            Write-Yellow "Exit without changes."
            Set-Location $startDir
            exit 0
        }
        default {
            Write-Red "[ERROR] Invalid choice. Exiting."
            Set-Location $startDir
            exit 1
        }
    }

} else {

    # FIRST DEPLOY
    Write-Cyan "[1/3] First deploy — copying files..."

    Copy-Item -Force ([IO.Path]::Combine($DOCKER_DIR, "backend.Dockerfile")) ([IO.Path]::Combine($PROJECT_DIR, "backend", "Dockerfile"))
    Write-Green "  [OK] backend/Dockerfile"

    Copy-Item -Force ([IO.Path]::Combine($DOCKER_DIR, "frontend.Dockerfile")) ([IO.Path]::Combine($PROJECT_DIR, "frontend", "Dockerfile"))
    Write-Green "  [OK] frontend/Dockerfile"

    Copy-Item -Force ([IO.Path]::Combine($CONFIG_DIR, "nginx.conf.example")) ([IO.Path]::Combine($PROJECT_DIR, "frontend", "nginx.conf"))
    Write-Green "  [OK] frontend/nginx.conf"

    $dbDest = [IO.Path]::Combine($PROJECT_DIR, "db")

    $dbSrc  = [IO.Path]::Combine($CONFIG_DIR, "db-init")
    if (-not (Test-Path -LiteralPath $dbDest)) {
        New-Item -ItemType Directory -Path $dbDest | Out-Null
    }
    Copy-Item -Recurse -Force "$dbSrc\*" $dbDest
    Write-Green "  [OK] db/ (init.sql)"

    Write-Host ""
    Write-Cyan "[2/3] Starting containers..."
    docker compose --env-file $ENV_FILE up --build -d
    if ($LASTEXITCODE -ne 0) {
        Write-Red "[ERROR] docker compose up failed. Check the logs above."
        exit 1
    }

    # -- Seed database -------------------------------------
    $seedFile = [IO.Path]::Combine($CONFIG_DIR, "db-init", "seed.sql")
    if (Test-Path -LiteralPath $seedFile) {
        Write-Host ""
        Write-Cyan "[3/3] Waiting for database to be ready..."

        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        $envContent = [System.IO.File]::ReadAllLines("$CONFIG_DIR\.env")
        $dbUser = ($envContent | Where-Object { $_ -match "^DB_USERSTORYPROJ_USER=" } | Select-Object -First 1) -replace "^DB_USERSTORYPROJ_USER=", ""
        $dbPass = ($envContent | Where-Object { $_ -match "^DB_USERSTORYPROJ_PASSWORD=" } | Select-Object -First 1) -replace "^DB_USERSTORYPROJ_PASSWORD=", ""
        $dbContainer = "userstory-db-1"

        # Debug: verify credentials were read
        if ([string]::IsNullOrEmpty($dbUser) -or [string]::IsNullOrEmpty($dbPass)) {
            Write-Red "  [ERROR] Could not read DB credentials from .env. Skipping seed."
            $ready = $false
        } else {
            Write-Yellow "  [INFO] Credentials loaded for user: $dbUser"
        }

        $timeout = 60
        $elapsed = 0
        $ready = $false

        if (-not ([string]::IsNullOrEmpty($dbUser)) -and -not ([string]::IsNullOrEmpty($dbPass))) {

        # Step 1: wait for DB connection
        # Pass password via -e flag to docker exec (MYSQL_PWD not forwarded on Windows)
        while ($elapsed -lt $timeout) {
            docker exec -e "MYSQL_PWD=$dbPass" $dbContainer mariadb -u"$dbUser" -e "SELECT 1;" 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { break }
            Start-Sleep -Seconds 2
            $elapsed += 2
            Write-Yellow "  ... waiting for connection (${elapsed}s)"
        }

        # Step 2: wait for schema (init.sql may still be running)
        $elapsed = 0
        while ($elapsed -lt $timeout) {
            docker exec -e "MYSQL_PWD=$dbPass" $dbContainer mariadb -u"$dbUser" -e "SELECT 1 FROM userstory.projects LIMIT 1;" 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $ready = $true; break }
            Start-Sleep -Seconds 2
            $elapsed += 2
            Write-Yellow "  ... waiting for schema (${elapsed}s)"
        }

        $ErrorActionPreference = $prevPref

        if ($ready) {
            Get-Content $seedFile | docker exec -i -e "MYSQL_PWD=$dbPass" $dbContainer mariadb -u"$dbUser" userstory 2>$null
            Write-Green "  [OK] Seed data loaded from db/seed.sql"
        } else {
            Write-Yellow "  [WARN] Database not ready within ${timeout}s. Skipping seed."
        }

        } # end credential guard

        # Clear credentials from memory
        $dbUser = $null; $dbPass = $null
        Remove-Variable dbUser, dbPass -ErrorAction SilentlyContinue
    }
}

# -- Result -----------------------------------------------
Write-Host ""
Write-Green "╔══════════════════════════════════════════╗"
Write-Green "║          Started successfully!  [OK]     ║"
Write-Green "╚══════════════════════════════════════════╝"
Write-Host ""
Write-Host "Container status:"
docker compose --env-file $ENV_FILE ps --format "table {{.Name}}`t{{.Status}}`t{{.Ports}}"
Write-Host ""

Set-Location $startDir
