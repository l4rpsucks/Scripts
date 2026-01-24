<#
    .SYNOPSIS
    Minecraft Inspector v4.4 (Strict Exact-Match & Bugfix)
    
    .DESCRIPTION
    1. FIXED: Renamed $PID to $TargetPID to stop the crash.
    2. FIXED: Added 'Select-Object -Unique' to stop scanning the same process 3 times.
    3. STRICT MODE: "Reach" now uses \bReach\b. It will IGNORE "Breach", "Preach", etc.
#>

# --- CONFIGURATION ---
$ToolDir = "C:\SS_Tools_Temp"
$DumpDir = "C:\SS_Memory_Dumps"
$Urls = @{
    "handle"   = "https://live.sysinternals.com/handle.exe"
    "procdump" = "https://live.sysinternals.com/procdump.exe"
    "strings"  = "https://live.sysinternals.com/strings.exe"
}

# --- CHEAT DETECTION DATABASE (STRICT) ---

# 1. STRICT WORDS (Common English words that must be EXACT matches)
# Using \b (Word Boundary) prevents "Reach" from matching "Breach"
$StrictWords = @(
    "\bReach\b", 
    "\bVelocity\b", 
    "\bAimAssist\b", 
    "\bFlight\b", 
    "\bKillaura\b", 
    "\bHitbox\b",
    "\bTimer\b"
)
$StrictRegex = $StrictWords -join "|"

# 2. CLIENT NAMES (Unique names, broad matching allowed)
$ClientNames = "Argon|Vape|Meteor Client|Krypton Client|Raven|LiquidBounce|Sigma|Wurst|Aristois|Inertia|Rise Client|Tenacity|Augustus"

# 3. BLATANT MOD FEATURES (Specific compound words)
$BlatantMods = "Autototem|AutoCrystal|AnchorMacro|AutoHitCrystal|AutoDoubleHand|TotemOffhand|AutoWtapp|TriggerBot|AutoPot|AutoJumpReset|NoMissDelay"

# Combine all into one Case-Insensitive Regex
$CheatRegex = "(?i)($StrictRegex|$ClientNames|$BlatantMods)"

# Setup Workspace
if (-not (Test-Path $ToolDir)) { New-Item -Path $ToolDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $DumpDir)) { New-Item -Path $DumpDir -ItemType Directory -Force | Out-Null }

Clear-Host
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   MINECRAFT INSPECTOR v4.4 (STRICT MODE)          " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 1. ACQUIRE TOOLS
Write-Host "[*] Checking Tools..." -ForegroundColor Yellow
foreach ($Tool in $Urls.Keys) {
    $ExePath = "$ToolDir\$Tool.exe"
    if (-not (Test-Path $ExePath)) {
        try { 
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $Urls[$Tool] -OutFile $ExePath 
        } catch { Write-Host "    [!] Failed to download $Tool" -ForegroundColor Red }
    }
}

# 2. FIND MINECRAFT
# We filter for Unique PIDs to avoid scanning the same process multiple times
$MCProcs = Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'" | 
           Where-Object {$_.CommandLine -match "minecraft" -or $_.CommandLine -match "lunar" -or $_.CommandLine -match "badlion"} |
           Select-Object -Property ProcessId, Name, CommandLine -Unique

if (-not $MCProcs) { 
    Write-Host "[-] No Minecraft process found." -ForegroundColor Red
    # Fallback to simple scan if filter was too strict
    $MCProcs = Get-CimInstance Win32_Process -Filter "Name='javaw.exe'" | Select-Object -Property ProcessId, Name, CommandLine -Unique
}

foreach ($Proc in $MCProcs) {
    $TargetPID = $Proc.ProcessId # FIXED: Using $TargetPID instead of reserved $PID
    Write-Host "`n[ TARGET LOCKED ] PID: $TargetPID | Name: $($Proc.Name)" -ForegroundColor Green -BackgroundColor Black

    # --- PHASE A: INTEGRITY & ORIGIN ---
    Write-Host "`n   [A] FILE INTEGRITY & ORIGIN" -ForegroundColor Yellow
    
    $HandleOut = & "$ToolDir\handle.exe" -p $TargetPID -accepteula
    # Improved Regex for file paths
    $FoundJars = $HandleOut | Select-String "(?i)([a-z]:\\[^:<>\x22\x7c?*]+\.jar)" -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Unique

    if ($FoundJars) {
        foreach ($JarPath in $FoundJars) {
            $JarPath = $JarPath.Trim()
            $FileName = Split-Path $JarPath -Leaf
            
            if (Test-Path $JarPath) {
                $HashObj = Get-FileHash -Path $JarPath -Algorithm SHA1
                $SHA1 = $HashObj.Hash.ToLower()
                $Status = "[UNKNOWN/PRIVATE]"; $Color = "Red"
                
                try {
                    $Uri = "https://api.modrinth.com/v2/version_file/$SHA1?algorithm=sha1"
                    $Response = Invoke-RestMethod -Uri $Uri -Method Get -ErrorAction Stop
                    $Status = "[VERIFIED]"; $Color = "Green"
                } catch {}
                
                Write-Host "   FILE: $FileName " -NoNewline -ForegroundColor White
                Write-Host "$Status" -ForegroundColor $Color

                if ($Status -eq "[UNKNOWN/PRIVATE]") { Write-Host "   PATH: $JarPath" -ForegroundColor DarkGray }

                $ZoneStream = "$JarPath`:Zone.Identifier"
                if (Test-Path $ZoneStream) {
                    $ZoneContent = Get-Content -Path $ZoneStream -Raw
                    if ($ZoneContent -match "HostUrl=(.*)") {
                        Write-Host "   [ORIGIN] $($Matches[1].Trim())" -ForegroundColor Cyan
                    }
                }
            }
        }
    } else {
        Write-Host "   [-] No .jar handles found (Game might be loading or AV blocking)." -ForegroundColor DarkGray
    }

    # --- PHASE B: MEMORY STRING SCAN ---
    Write-Host "`n   [B] MEMORY STRING SCAN (Strict Match Only)" -ForegroundColor Yellow
    Write-Host "       Dumping memory..." -ForegroundColor Gray
    
    $DumpFile = "$DumpDir\mc_dump_$TargetPID.dmp"
    $DumpProc = Start-Process -FilePath "$ToolDir\procdump.exe" -ArgumentList "-ma $TargetPID `"$DumpFile`" -accepteula" -Wait -PassThru -NoNewWindow
    
    if (Test-Path $DumpFile) {
        Write-Host "       Scanning strings..." -ForegroundColor Gray
        $HitCount = 0
        
        & "$ToolDir\strings.exe" -n 6 $DumpFile | ForEach-Object {
            $Line = $_.Trim()
            
            # THE FIX: This Regex now enforces \b boundaries
            if ($Line -match $CheatRegex) {
                Write-Host "       [!!!] CHEAT DETECTED: $Line" -ForegroundColor Red -BackgroundColor Yellow
                $HitCount++
            }
        }
        
        if ($HitCount -eq 0) { Write-Host "       [-] No blatant strings found." -ForegroundColor Green }
        
        # Cleanup
        Remove-Item $DumpFile -Force
    }
}
Write-Host "`n[ SCAN COMPLETE ]" -ForegroundColor Cyan
Pause
