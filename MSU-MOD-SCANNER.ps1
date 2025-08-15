<#
    CheatModJarScanner.ps1
    Scans all .jar files in a directory for internal cheat/hack class names or suspicious cheat strings.
    Includes:
      - Modrinth hash check (via Modrinth API for SHA1)
      - ADS check (Zone.Identifier stream)
      - Only scans mod jars, not logs
      - Prints out per-jar findings
#>

Param(
    [string]$ModsPath = ""
)

# Prompt for ModsPath if missing/empty
while (-not $ModsPath -or [string]::IsNullOrWhiteSpace($ModsPath)) {
    $ModsPath = Read-Host "Enter the FULL PATH to your Minecraft mods folder (e.g. C:\Users\You\AppData\Roaming\.minecraft\mods)"
}

# Cheat class/indicator patterns (internal strings, file/class names, NOT log lines)
$CheatPatterns = @(
    # Class names
    "AutoTotem",
    "AutoCrystal",
    "SelfDestruct",
    "AimAssist",
    "AnchorTweaks",
    "AutoAnchor",
    "AutoDoubleHand",
    "AutoHitCrystal",
    "AutoPot",
    "InventoryTotem",
    "Hitboxes",
    "JumpReset",
    "LegitTotem",
    "PingSpoof",
    "Reach",
    "ShieldBreaker",
    "TriggerBot",
    "Velocity",
    "ClickCrystals",
    "FastCrystal",
    "ADH.class",
    "CwCrystal.class",
    "ModuleManager.class",
    "AA.java",
    "AC.java",
    "AE.java",
    "AJR.java",
    "AM.java",
    "EXPLODE_DELAY_MS",
    "GLOWSTONE_DELAY_MS",
    "FAKE_PUNCH",
    "AUTO_SWAP",
    "BREAK_CHANCE",
    "BREAK_DELAY",
    "Auto Loot Yeeter",
    "isDeadBodyNearbyr",
    "placeCrystal",
    "ItemUseMixin"
)

Write-Host "=======================================" -ForegroundColor Magenta
Write-Host " CheatModJarScanner: Minecraft Mod Audit " -ForegroundColor Magenta
Write-Host "=======================================" -ForegroundColor Magenta
Write-Host ""

if (-not (Test-Path $ModsPath -PathType Container)) {
    Write-Error "Designated mods path is invalid or inaccessible: $ModsPath"
    exit 1
}
Write-Host "Scanning mods folder: $ModsPath" -ForegroundColor White

$jarFiles = Get-ChildItem -Path $ModsPath -Filter *.jar -ErrorAction SilentlyContinue
if (-not $jarFiles) {
    Write-Host "No .jar mods detected in: $ModsPath" -ForegroundColor Yellow
    exit 0
}

function Get-AdsUrl {
    param (
        [string]$FilePath
    )
    try {
        $ads = Get-Content -Stream Zone.Identifier $FilePath -ErrorAction Stop -Raw
        if ($ads -match "HostUrl=(.+)") {
            return $matches[1]
        }
    } catch {}
    return $null
}

function Fetch-ModrinthData {
    param (
        [string]$Hash
    )
    $modrinthApiUrl = "https://api.modrinth.com/v2/version_file/$Hash"
    $modData = @{ Name = ""; Slug = ""; Source = "Modrinth API" }
    try {
        $response = Invoke-RestMethod -Uri $modrinthApiUrl -Method Get -TimeoutSec 15 -ErrorAction Stop
        if ($response.project_id) {
            $projectApiUrl = "https://api.modrinth.com/v2/project/$($response.project_id)"
            $projectData = Invoke-RestMethod -Uri $projectApiUrl -Method Get -TimeoutSec 15 -ErrorAction Stop
            $modData.Name = $projectData.title
            $modData.Slug = $projectData.slug
        }
    } catch {
        $modData.Source = "Modrinth API Failure/Unknown"
    }
    return $modData
}

function Scan-JarForCheatClasses {
    param (
        [string]$JarPath,
        [string[]]$Patterns
    )
    $foundMatches = @()
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($JarPath)
        foreach ($entry in $zip.Entries) {
            # Check the entry name itself (e.g., suspicious class file name)
            foreach ($pattern in $Patterns) {
                if ($entry.Name -match $pattern -or $entry.FullName -match $pattern) {
                    $foundMatches += "Class/File: $($entry.FullName) matches pattern '$pattern'"
                }
            }
            # For .class files, check for readable cheat strings inside
            if ($entry.Name -match '\.class$') {
                try {
                    $stream = $entry.Open()
                    $bytes = [byte[]]::new($entry.Length)
                    $stream.Read($bytes, 0, $bytes.Length) | Out-Null
                    $stream.Close()
                    $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
                    foreach ($pattern in $Patterns) {
                        if ($ascii -match $pattern) {
                            $foundMatches += "Internal String: '$pattern' found in $($entry.FullName)"
                        }
                    }
                } catch {}
            }
        }
        $zip.Dispose()
    } catch {
        Write-Warning "Could not scan '$JarPath': $($_.Exception.Message)"
    }
    return $foundMatches
}

$flaggedJars = @()
foreach ($jar in $jarFiles) {
    $result = Scan-JarForCheatClasses -JarPath $jar.FullName -Patterns $CheatPatterns

    # Modrinth hash check
    $sha1 = ""
    $modrinthStatus = ""
    try {
        $sha1 = (Get-FileHash -Path $jar.FullName -Algorithm SHA1 -ErrorAction Stop).Hash
        $modrinthData = Fetch-ModrinthData -Hash $sha1
        if ($modrinthData.Slug) {
            $modrinthStatus = "Verified Modrinth: $($modrinthData.Name) (https://modrinth.com/mod/$($modrinthData.Slug))"
        } else {
            $modrinthStatus = "Not found on Modrinth (SHA1 $sha1)"
        }
    } catch {
        $modrinthStatus = "SHA1 hash failed: $($_.Exception.Message)"
    }

    # ADS check
    $adsUrl = Get-AdsUrl -FilePath $jar.FullName

    if ($result.Count -gt 0 -or $modrinthStatus -notmatch "^Verified" -or $adsUrl) {
        $flaggedJars += [PSCustomObject]@{
            JarName = $jar.Name
            CheatFindings = $result
            ModrinthStatus = $modrinthStatus
            ADSUrl = $adsUrl
        }
    }
}

Write-Host ""
Write-Host "=== Cheat Mod Scan Results ===" -ForegroundColor Green
if ($flaggedJars.Count -eq 0) {
    Write-Host "No suspicious cheat classes or strings found in any mod jars." -ForegroundColor Cyan
} else {
    foreach ($mod in $flaggedJars) {
        Write-Host ">>> $($mod.JarName)" -ForegroundColor Red
        if ($mod.CheatFindings.Count -gt 0) {
            foreach ($f in $mod.CheatFindings) {
                Write-Host "    $f" -ForegroundColor Yellow
            }
        }
        Write-Host "    $($mod.ModrinthStatus)" -ForegroundColor DarkGray
        if ($mod.ADSUrl) {
            Write-Host "    Zone.Identifier HostUrl: $($mod.ADSUrl)" -ForegroundColor Magenta
        }
        Write-Host ""
    }
    Write-Host "Check the above jars for cheat code or mod removal." -ForegroundColor Magenta
}

Write-Host "Scan complete."
