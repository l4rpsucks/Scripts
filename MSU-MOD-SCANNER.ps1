#>
[CmdletBinding()]
Param(
    [string]$ModsPath,
    [string]$LogPath,

    [Parameter()]
    [hashtable[]]$KnownBadLogPatterns = @(
        @{ name = "Wurst Client"; value = "- wurst" },
        @{ name = "Meteor Client"; value = "- meteor-client" },
        @{ name = "Francium Client"; value = "- org_apache"},
        @{ name = "Doomsday Client"; value = "- dd"},
        @{ name = "Prestige Client"; value = "- prestige"},
        @{ name = "Inertia Client"; value = "- inertia"},
        @{ name = "Thunder Hack"; value = "- thunderhack"},
        @{ name = "Walksy Optimizer"; value = "- walksycrystaloptimizer" },
        @{ name = "Walksy Shield Statuses"; value = "- shieldstatus" },
        @{ name = "Accurate Block Placement"; value = "- accurateblockplacement" },
        @{ name = "Elytra Chest Swapper"; value = "- ecs" },
        @{ name = "Click Crystals"; value = "- clickcrystals" },
        @{ name = "Fast Crystal"; value = "- fastcrystal" },
        @{ name = "Auto Totem"; value = "- autototem" },
        @{ name = "InventoryTotem"; value = "InventoryTotem" },
        @{ name = "Hitboxes"; value = "Hitboxes" },
        @{ name = "JumpReset"; value = "JumpReset" },
        @{ name = "LegitTotem"; value = "LegitTotem" },
        @{ name = "PingSpoof"; value = "PingSpoof" },
        @{ name = "Reach"; value = "Reach" },
        @{ name = "SelfDestruct"; value = "SelfDestruct" },
        @{ name = "ShieldBreaker"; value = "ShieldBreaker" },
        @{ name = "TriggerBot"; value = "TriggerBot" },
        @{ name = "Velocity"; value = "Velocity" }
    ),

    [Parameter()]
    [hashtable[]]$SuspiciousJarPatterns = @(
        @{ name = "AimAssist"; value = "AimAssist" },
        @{ name = "AnchorTweaks"; value = "AnchorTweaks" },
        @{ name = "AutoAnchor"; value = "AutoAnchor" },
        @{ name = "AutoCrystal"; value = "AutoCrystal" },
        @{ name = "AutoDoubleHand"; value = "AutoDoubleHand" },
        @{ name = "AutoHitCrystal"; value = "AutoHitCrystal" },
        @{ name = "AutoPot"; value = "AutoPot" },
        @{ name = "AutoTotem"; value = "AutoTotem" },
        @{ name = "InventoryTotem"; value = "InventoryTotem" },
        @{ name = "Hitboxes"; value = "Hitboxes" },
        @{ name = "JumpReset"; value = "JumpReset" },
        @{ name = "LegitTotem"; value = "LegitTotem" },
        @{ name = "PingSpoof"; value = "PingSpoof" },
        @{ name = "Reach"; value = "Reach" },
        @{ name = "SelfDestruct"; value = "SelfDestruct" },
        @{ name = "ShieldBreaker"; value = "ShieldBreaker" },
        @{ name = "TriggerBot"; value = "TriggerBot" },
        @{ name = "Velocity"; value = "Velocity" }
    )
)

# Prompt for ModsPath if missing/empty
while (-not $ModsPath -or [string]::IsNullOrWhiteSpace($ModsPath)) {
    $ModsPath = Read-Host "Enter the FULL PATH to your Minecraft mods folder (e.g. C:\Users\You\AppData\Roaming\.minecraft\mods)"
}

# Prompt for LogPath if missing/empty
while (-not $LogPath -or [string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Read-Host "Enter the FULL PATH to your Minecraft log file (e.g. C:\Users\You\AppData\Roaming\.minecraft\logs\latest.log)"
}

Clear-Host
Write-Host "=======================================" -ForegroundColor Magenta
Write-Host " Project Insight: Minecraft Mod Dossier " -ForegroundColor Magenta
Write-Host "      Authored by " -ForegroundColor DarkMagenta -NoNewline
Write-Host "ECHOAC" -ForegroundColor DarkMagenta
Write-Host "=======================================" -ForegroundColor Magenta
Write-Host ""

# --- Validate Paths ---
if (-not (Test-Path $ModsPath -PathType Container)) {
    Write-Error "Designated mods path is invalid or inaccessible: $ModsPath"
    exit 1
}
Write-Host "Operational target acquired: " -ForegroundColor White -NoNewline
Write-Host $ModsPath -ForegroundColor DarkGray
Write-Host ""

# --- Check for Running Minecraft Process ---
Write-Host "=== Operational Status: Minecraft Process ===" -ForegroundColor Green
$process = Get-Process javaw -ErrorAction SilentlyContinue

if ($process) {
    $startTime = $process.StartTime
    $elapsedTime = (Get-Date) - $startTime

    Write-Host "Status: javaw.exe process detected." -ForegroundColor Cyan
    Write-Host "  Process ID: $($process.Id)" -ForegroundColor DarkGray
    Write-Host "  Commenced: $startTime" -ForegroundColor DarkGray
    Write-Host "  Duration: $($elapsedTime.Hours)h $($elapsedTime.Minutes)m $($elapsedTime.Seconds)s" -ForegroundColor DarkGray
} else {
    Write-Host "Status: javaw.exe process not detected." -ForegroundColor Yellow
}
Write-Host ""

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

function Find-PatternsInText {
    param (
        [string[]]$Lines,
        [hashtable[]]$Patterns
    )
    $foundNames = New-Object System.Collections.Generic.HashSet[string]
    if (-not $Lines) { return $foundNames }
    foreach ($line in $Lines) {
        foreach ($pattern in $Patterns) {
            if ($line -imatch $pattern.value) {
                $foundNames.Add($pattern.name) | Out-Null
            }
        }
    }
    return $foundNames
}

function Check-JarContents {
    param (
        [string]$FilePath,
        [hashtable[]]$Patterns
    )
    $foundNames = New-Object System.Collections.Generic.HashSet[string]
    if (-not (Test-Path $FilePath -PathType Leaf)) {
         Write-Error "Artifact not found for internal content scan: $FilePath"
         return $foundNames
    }
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipArchive]::Open($FilePath, [System.IO.Compression.ZipArchiveMode]::Read)
        foreach ($entry in $zip.Entries) {
            $entryPath = $entry.FullName -replace '[/\\]', '/'
            foreach ($pattern in $Patterns) {
                if ($entryPath -imatch $pattern.value) {
                    $foundNames.Add($pattern.name) | Out-Null
                }
            }
        }
        $zip.Dispose()
    } catch {
        Write-Warning "Could not conduct internal scan on artifact '$($FilePath)': $($_.Exception.Message)"
    }
    return $foundNames
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

Write-Host "=== Artifact Analysis: Mod Repository ===" -ForegroundColor Green
$unknownModsSummary = @()
$jarFiles = Get-ChildItem -Path $ModsPath -Filter *.jar -ErrorAction SilentlyContinue
if (-not $jarFiles) {
    Write-Host "No .jar artifacts located in target repository: $ModsPath" -ForegroundColor Yellow
} else {
    foreach ($file in $jarFiles) {
        Write-Host "Artifact Name: $($file.Name)" -ForegroundColor DarkCyan
        $hash = $null
        try {
            $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA1 -ErrorAction Stop).Hash
            Write-Host "  Fingerprint (SHA1): $hash" -ForegroundColor DarkGray
        } catch {
             Write-Warning "  Failed to compute fingerprint for artifact '$($file.Name)': $($_.Exception.Message)"
        }
        if ($hash) {
            $modrinthData = Fetch-ModrinthData -Hash $hash
            if ($modrinthData.Slug) {
                Write-Host "  Identification Status: Verified - $($modrinthData.Name)" -ForegroundColor Cyan
                Write-Host "  Source: Modrinth Database" -ForegroundColor DarkGray
                Write-Host "  Access Link: https://modrinth.com/mod/$($modrinthData.Slug)" -ForegroundColor DarkGray
            } else {
                 Write-Host "  Identification Status: Anomaly Detected (Unknown/API Error)" -ForegroundColor Yellow
                $adsUrl = Get-AdsUrl -FilePath $file.FullName
                if ($adsUrl) {
                    Write-Host "  Origin Trace (ADS): $adsUrl" -ForegroundColor DarkGray
                }
                $jarPatternsFound = Check-JarContents -FilePath $file.FullName -Patterns $SuspiciousJarPatterns
                $suspiciousPatterns = $jarPatternsFound | ForEach-Object { $_ }
                if ($suspiciousPatterns.Count -gt 0) {
                    Write-Host "  Suspicious internal signatures found:" -ForegroundColor Red
                    $suspiciousPatterns | ForEach-Object { Write-Host "    >>> $_" -ForegroundColor Red }
                }
                $unknownModsSummary += [PSCustomObject]@{
                     FileName = $file.Name
                     ADSUrl = $adsUrl
                     SuspiciousInternalPatterns = $suspiciousPatterns
                     HashComputed = ($hash -ne $null)
                 }
            }
        } else {
             Write-Host "  Identification Status: Anomaly Detected (Fingerprint Computation Failed)" -ForegroundColor Yellow
             $unknownModsSummary += [PSCustomObject]@{
                 FileName = $file.Name
                 ADSUrl = (Get-AdsUrl -FilePath $file.FullName)
                 SuspiciousInternalPatterns = @("SHA1 Fingerprint Computation Failed")
                 HashComputed = $false
             }
        }
        Write-Host "===" -ForegroundColor DarkGray
    }
}
Write-Host ""

Write-Host "=== Operational Log Analysis: $LogPath ===" -ForegroundColor Green
if (Test-Path $LogPath -PathType Leaf) {
    try {
        $logContent = Get-Content -Path $LogPath -ErrorAction Stop
        $logPatternsFound = Find-PatternsInText -Lines $logContent -Patterns $KnownBadLogPatterns
        if ($logPatternsFound.Count -gt 0) {
            Write-Warning "Potential traces found within operational log:"
            $logPatternsFound | ForEach-Object { Write-Warning "  >>> $_" }
        } else {
            Write-Host "No known suspicious traces found within the operational log." -ForegroundColor Cyan
        }
    } catch {
        Write-Error "Failed to access or process operational log '$LogPath': $($_.Exception.Message)"
    }
} else {
    Write-Warning "Operational log artifact not located: $LogPath"
}
Write-Host ""

Write-Host "=== Dossier Summary: Anomalies & Unverified Artifacts ===" -ForegroundColor Magenta
if ($unknownModsSummary.Count -gt 0) {
    Write-Host "The following artifacts require further scrutiny (Unidentified via Modrinth or flagged internally):" -ForegroundColor Red
    foreach ($mod in $unknownModsSummary) {
        Write-Host "- $($mod.FileName)" -ForegroundColor Red
        if ($mod.HashComputed -eq $false) {
             Write-Host "  Reason: Fingerprint computation failed." -ForegroundColor DarkGray
        } elseif (-not $mod.ADSUrl -and $mod.SuspiciousInternalPatterns.Count -eq 0) {
             Write-Host "  Reason: Unidentified by Modrinth, no ADS trace, no suspicious internal signatures found." -ForegroundColor DarkGray
         } else {
             Write-Host "  Reason: Unidentified by Modrinth." -ForegroundColor DarkGray
         }
        if ($mod.ADSUrl) {
            Write-Host "  Origin Trace (ADS): $($mod.ADSUrl)" -ForegroundColor DarkGray
        }
        if ($mod.SuspiciousInternalPatterns.Count -gt 0) {
            Write-Host "  Flagged Signatures:" -ForegroundColor Red
            $mod.SuspiciousInternalPatterns | ForEach-Object { Write-Host "    >>> $_" -ForegroundColor Red }
        }
    }
} else {
    Write-Host "Nothing sus" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "Doesn't look like we found anything. Still verify manually, though..." -ForegroundColor Magenta