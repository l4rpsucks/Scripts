#&gt;
[CmdletBinding()]
Param(
    [Parameter(Position=0)]
    [string]$ModsPath = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods",

    [Parameter()]
    [string]$LogPath = "$env:USERPROFILE\AppData\Roaming\.minecraft\logs\latest.log",

    [Parameter()]
    [hashtable[]]$KnownBadLogPatterns = @(
        @{ name = "Wurst Client"; value = "- wurst" },
        @{ name = "Meteor Client"; value = "- meteor-client" },
        @{ name = "Francium Client"; value = "- org_apache"}, # This pattern seems weak/generic
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
        # Consider adding package names like "client.cheat", "hack.module", etc.
        # @{ name = "CheatClientPackage"; value = "client/cheat" }
        # @{ name = "HackModulePackage"; value = "hack/module" }
    )
)

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

# --- Function to get Zone.Identifier URL ---
function Get-AdsUrl {
    param (
        [string]$FilePath
    )
    try {
        # Reads the Zone.Identifier Alternate Data Stream - indicates download origin
        $ads = Get-Content -Stream Zone.Identifier $FilePath -ErrorAction Stop -Raw
        if ($ads -match "HostUrl=(.+)") {
            return $matches[1]
        }
    } catch {
        # Ignore errors if stream doesn&#39;t exist or access is denied
        # Write-Verbose "Could not retrieve ADS for &#39;$($FilePath.Name)&#39;: $($_.Exception.Message)"
    }
    return $null
}

# --- Function to find patterns in text content (e.g., log file) ---
function Find-PatternsInText {
    &lt;#
    .SYNOPSIS
    Scans text content for predefined pattern signatures.

    .PARAMETER Lines
    An array of text strings (log entries, etc.) for analysis.

    .PARAMETER Patterns
    A data array containing &#39;name&#39; and &#39;value&#39; (pattern signature) pairs to search for.
    #&gt;
    param (
        [string[]]$Lines,
        [hashtable[]]$Patterns
    )

    $foundNames = New-Object System.Collections.Generic.HashSet[string]

    if (-not $Lines) { return $foundNames }

    foreach ($line in $Lines) {
        foreach ($pattern in $Patterns) {
            # Use -imatch for case-insensitive matching
            if ($line -imatch $pattern.value) {
                $foundNames.Add($pattern.name) | Out-Null
                # Optional: break inner loop if any pattern matches a line, assumes one hit per line is enough
                # break
            }
        }
    }
    return $foundNames
}

# --- Function to check internal file paths within a JAR archive ---
function Check-JarContents {
    &lt;#
    .SYNOPSIS
    Inspects internal file paths within a .jar archive for predefined pattern signatures.

    .DESCRIPTION
    Treats the .jar file as a compressed archive and examines the names of its constituent entries.
    Probes for pattern signatures within these internal paths (e.g., package/class name traces).
    Note: This process does not involve decompilation of binary code.

    .PARAMETER FilePath
    The absolute path to the .jar artifact.

    .PARAMETER Patterns
    A data array containing &#39;name&#39; and &#39;value&#39; (pattern signature) pairs for internal path scrutiny.
    #&gt;
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
        # Requires .NET Framework 4.5+ / PowerShell 5.0+ / Core
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipArchive]::Open($FilePath, [System.IO.Compression.ZipArchiveMode]::Read)

        foreach ($entry in $zip.Entries) {
            # Normalize path separators to forward slashes for consistent matching
            $entryPath = $entry.FullName -replace &#39;[/\\]&#39;, &#39;/&#39;

            foreach ($pattern in $Patterns) {
                 # Use -imatch for case-insensitive matching
                if ($entryPath -imatch $pattern.value) {
                    $foundNames.Add($pattern.name) | Out-Null
                    # If we find a pattern in this entry path, no need to check other patterns for this entry
                    # break # Optional optimization
                }
            }
        }
        # Explicitly dispose the ZipArchive object to release the file handle
        $zip.Dispose()
    } catch {
        Write-Warning "Could not conduct internal scan on artifact &#39;$($FilePath)&#39;: $($_.Exception.Message)"
        # Continue script execution
    }

    return $foundNames
}


# --- Function to fetch mod data from Modrinth ---
function Fetch-ModrinthData {
    &lt;#
    .SYNOPSIS
    Queries the Modrinth API for mod intelligence based on a file hash fingerprint.

    .PARAMETER Hash
    The SHA1 hash fingerprint of the artifact.
    #&gt;
    param (
        [string]$Hash
    )
    $modrinthApiUrl = "https://api.modrinth.com/v2/version_file/$Hash"
    $modData = @{ Name = ""; Slug = ""; Source = "Modrinth API" } # Indicate source query

    try {
        $response = Invoke-RestMethod -Uri $modrinthApiUrl -Method Get -TimeoutSec 15 -ErrorAction Stop

        if ($response.project_id) {
            # Found a version file based on hash, now get project details
            $projectApiUrl = "https://api.modrinth.com/v2/project/$($response.project_id)"
            $projectData = Invoke-RestMethod -Uri $projectApiUrl -Method Get -TimeoutSec 15 -ErrorAction Stop

            $modData.Name = $projectData.title
            $modData.Slug = $projectData.slug
            # Source already set to "Modrinth API"
        }
        # If response is 200 but no project_id, it means the hash wasn&#39;t found. $modData remains with default values.

    } catch {
        # Handle specific API errors (e.g., 404 Not Found) differently if needed
        # For now, just log the error and return empty data
        # Write-Verbose "Modrinth API query failed for hash &#39;$Hash&#39;: $($_.Exception.Message)"
        $modData.Source = "Modrinth API Failure/Unknown" # Indicate failure source
    }

    return $modData
}

# --- Analyze Mods Folder ---
Write-Host "=== Artifact Analysis: Mod Repository ===" -ForegroundColor Green
$unknownModsSummary = @()

$jarFiles = Get-ChildItem -Path $ModsPath -Filter *.jar -ErrorAction SilentlyContinue

if (-not $jarFiles) {
    Write-Host "No .jar artifacts located in target repository: $ModsPath" -ForegroundColor Yellow
} else {
    foreach ($file in $jarFiles) {
        Write-Host "Artifact Name: $($file.Name)" -ForegroundColor DarkCyan

        # Get SHA1 Hash
        $hash = $null
        try {
            $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA1 -ErrorAction Stop).Hash
            Write-Host "  Fingerprint (SHA1): $hash" -ForegroundColor DarkGray
        } catch {
             Write-Warning "  Failed to compute fingerprint for artifact &#39;$($file.Name)&#39;: $($_.Exception.Message)"
        }


        # Query Modrinth
        if ($hash) {
            $modrinthData = Fetch-ModrinthData -Hash $hash
            if ($modrinthData.Slug) {
                Write-Host "  Identification Status: Verified - $($modrinthData.Name)" -ForegroundColor Cyan
                Write-Host "  Source: Modrinth Database" -ForegroundColor DarkGray
                Write-Host "  Access Link: https://modrinth.com/mod/$($modrinthData.Slug)" -ForegroundColor DarkGray
            } else {
                 Write-Host "  Identification Status: Anomaly Detected (Unknown/API Error)" -ForegroundColor Yellow

                # Check Zone.Identifier ADS
                $adsUrl = Get-AdsUrl -FilePath $file.FullName
                if ($adsUrl) {
                    Write-Host "  Origin Trace (ADS): $adsUrl" -ForegroundColor DarkGray
                }

                # Check internal JAR contents for suspicious patterns
                $jarPatternsFound = Check-JarContents -FilePath $file.FullName -Patterns $SuspiciousJarPatterns
                $suspiciousPatterns = $jarPatternsFound | ForEach-Object { $_ } # Convert HashSet to Array

                if ($suspiciousPatterns.Count -gt 0) {
                    Write-Host "  Suspicious internal signatures found:" -ForegroundColor Red
                    $suspiciousPatterns | ForEach-Object { Write-Host "    &gt;&gt;&gt; $_" -ForegroundColor Red }
                }

                # Add to summary for unknown mods section
                 $unknownModsSummary += [PSCustomObject]@{
                     FileName = $file.Name
                     ADSUrl = $adsUrl
                     SuspiciousInternalPatterns = $suspiciousPatterns
                     HashComputed = ($hash -ne $null) # Track if hash failed
                 }
            }
        } else {
             # If hash calculation failed, treat as unknown anomaly
             Write-Host "  Identification Status: Anomaly Detected (Fingerprint Computation Failed)" -ForegroundColor Yellow
              # Add to summary for unknown mods section
                 $unknownModsSummary += [PSCustomObject]@{
                     FileName = $file.Name
                     ADSUrl = (Get-AdsUrl -FilePath $file.FullName)
                     SuspiciousInternalPatterns = @("SHA1 Fingerprint Computation Failed") # Indicate why it&#39;s unknown
                     HashComputed = $false
                 }
        }

        Write-Host "===" -ForegroundColor DarkGray
    }
}
Write-Host ""

# --- Analyze Minecraft Log File ---
Write-Host "=== Operational Log Analysis: $LogPath ===" -ForegroundColor Green

if (Test-Path $LogPath -PathType Leaf) {
    try {
        # Read log file content
        $logContent = Get-Content -Path $LogPath -ErrorAction Stop
        # Find patterns in the log content
        $logPatternsFound = Find-PatternsInText -Lines $logContent -Patterns $KnownBadLogPatterns

        if ($logPatternsFound.Count -gt 0) {
            Write-Warning "Potential traces found within operational log:"
            $logPatternsFound | ForEach-Object { Write-Warning "  &gt;&gt;&gt; $_" }
        } else {
            Write-Host "No known suspicious traces found within the operational log." -ForegroundColor Cyan
        }
    } catch {
        Write-Error "Failed to access or process operational log &#39;$LogPath&#39;: $($_.Exception.Message)"
    }
} else {
    Write-Warning "Operational log artifact not located: $LogPath"
}
Write-Host ""


# --- Summary of Unknown/Suspicious Mods ---
Write-Host "=== Dossier Summary: Anomalies &amp; Unverified Artifacts ===" -ForegroundColor Magenta
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
            $mod.SuspiciousInternalPatterns | ForEach-Object { Write-Host "    &gt;&gt;&gt; $_" -ForegroundColor Red }
        }
    }
} else {
    Write-Host "Nothing sus" -ForegroundColor Cyan
}
Write-Host ""

Write-Host "Doesn&#39;t look like we found anything. Still verify manually, though..." -ForegroundColor Magenta
