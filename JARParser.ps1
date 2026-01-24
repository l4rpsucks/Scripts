<#
    .SYNOPSIS
    Minecraft Inspector v4.1 (Bugfix Release)
    
    .DESCRIPTION
    1. FIXED: 'PID' variable read-only error.
    2. FIXED: 'Reach' matching 'Breach of contract' (Added word boundaries).
    3. IMPROVED: Handle parsing regex to catch jars more reliably.
#>

# --- CONFIGURATION ---
$ToolDir = "C:\SS_Tools_Temp"
$DumpDir = "C:\SS_Memory_Dumps"
$Urls = @{
    "handle"   = "https://live.sysinternals.com/handle.exe"
    "procdump" = "https://live.sysinternals.com/procdump.exe"
    "strings"  = "https://live.sysinternals.com/strings.exe"
}

# --- CHEAT SIGNATURE DATABASE (Optimized) ---
# We use \b (Word Boundary) on common words to avoid EULA false positives
$ClientNames = "Argon|Vape|Meteor Client|Krypton Client|Raven|LiquidBounce|Sigma|Wurst|Aristois|Inertia|Rise Client|Tenacity|Augustus"
$GenericCheats = "PlaceDelay|SwitchDelay|ExpandHitboxes|ExplodeChance|PlaceChance|SwitchChance|StopOnKill|AntiKnockback"
# 'Velocity' and 'Reach' are common English words, so we force exact word matching (\b)
$RiskyWords  = "\bVelocity\b|\bReach\b|\bAimAssist\b" 
$BlatantMods = "Autototem|AutoCrystal|AnchorMacro|AutoHitCrystal|AutoDoubleHand|TotemOffhand|Auto Xp|Auto Wtap|TriggerBot|AutoPot|AutoPotRefill|AutoJumpReset|NoMissDelay"

# Combine regex
$CheatRegex = "(?i)($ClientNames|$GenericCheats|$BlatantMods|$RiskyWords)"

# Setup
if (-not (Test-Path $ToolDir)) { New-Item -Path $ToolDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $DumpDir)) { New-Item -Path $DumpDir -ItemType Directory -Force | Out-Null }

Clear-Host
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   MINECRAFT INSPECTOR v4.1 (STABLE)               " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 1. ACQUIRE TOOLS
Write-Host "[*] Checking Tools..." -ForegroundColor Yellow
foreach ($Tool in $Urls.Keys) {
    $ExePath = "$ToolDir\$Tool.exe"
    if (-not (Test-Path $ExePath)) {
        try { 
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $Urls[$Tool] -OutFile $ExePath 
            Write-Host "    [+] Downloaded $Tool.exe" -ForegroundColor Gray
        } catch { Write-Host "    [!] Failed to download $Tool" -ForegroundColor Red }
    }
}

# 2. FIND MINECRAFT
# Filter to ensure we don't grab the launcher, just the game
$MCProcs = Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'" | Where-Object {$_.CommandLine -match "minecraft"}

if (-not $MCProcs) { 
    Write-Host "[-] No Minecraft process found. (Ensure game is open, not just launcher)." -ForegroundColor Red
    # Fallback to just javaw if filter failed
    $MCProcs = Get-CimInstance Win32_Process -Filter "Name='javaw.exe'"
}

foreach ($Proc in $MCProcs) {
    $McPID = $Proc.ProcessId # FIXED: Renamed variable from $PID to $McPID
    Write-Host "`n[ TARGET LOCKED ] PID: $McPID | Name: $($Proc.Name)" -ForegroundColor Green -BackgroundColor Black

    # --- PHASE A: INTEGRITY & ORIGIN SCAN ---
    Write-Host "`n   [A] FILE INTEGRITY & ORIGIN (Disk Artifacts)" -ForegroundColor Yellow
    
    # Run Handle and capture all output
    $HandleOut = & "$ToolDir\handle.exe" -p $McPID -accepteula
    
    # IMPROVED REGEX: Captures any drive letter path ending in .jar, handling spaces/text around it
    $FoundJars = $HandleOut | Select-String "(?i)([a-z]:\\[^:<>\x22]+\.jar)" -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Unique

    if ($FoundJars) {
        Write-Host "       Found $($FoundJars.Count) loaded jar files." -ForegroundColor Gray
        foreach ($JarPath in $FoundJars) {
            $JarPath = $JarPath.Trim()
            $FileName = Split-Path $JarPath -Leaf
            
            if (Test-Path $JarPath) {
                # 1. Modrinth Hash Check
                $HashObj = Get-FileHash -Path $JarPath -Algorithm SHA1
                $SHA1 = $HashObj.Hash.ToLower()
                
                $Status = "[UNKNOWN/PRIVATE]"
                $Color = "Red"
                
                try {
                    $Uri = "https://api.modrinth.com/v2/version_file/$SHA1?algorithm=sha1"
                    $Response = Invoke-RestMethod -Uri $Uri -Method Get -ErrorAction Stop
                    $Status = "[VERIFIED]"
                    $Color = "Green"
                } catch { 
                    # 404 = Not found
                }
                
                Write-Host "   ------------------------------------------------" -ForegroundColor DarkGray
                Write-Host "   FILE: " -NoNewline -ForegroundColor Gray
                Write-Host "$FileName " -NoNewline -ForegroundColor White
                Write-Host "$Status" -ForegroundColor $Color
                
                # Only show full path if suspicious
                if ($Status -eq "[UNKNOWN/PRIVATE]") {
                     Write-Host "   PATH: $JarPath" -ForegroundColor DarkGray
                }

                # 2. ZONE.IDENTIFIER CHECK
                $ZoneStream = "$JarPath`:Zone.Identifier"
                if (Test-Path $ZoneStream) {
                    $ZoneContent = Get-Content -Path $ZoneStream -Raw
                    if ($ZoneContent -match "HostUrl=(.*)") {
                        $Origin = $Matches[1].Trim()
                        Write-Host "   [ORIGIN] $Origin" -ForegroundColor Cyan
                        if ($Origin -match "discord" -or $Origin -match "mediafire") {
                            Write-Host "            (Suspicious source)" -ForegroundColor Magenta
                        }
                    }
                }
            }
        }
    } else {
        Write-Host "   [-] No .jar handles found. (Is Handle.exe blocked by AV?)" -ForegroundColor Red
    }

    # --- PHASE B: MEMORY STRING SCAN ---
    Write-Host "`n   [B] MEMORY STRING SCAN (Deep Analysis)" -ForegroundColor Yellow
    Write-Host "       Dumping memory..." -ForegroundColor Gray
    
    $DumpFile = "$DumpDir\mc_dump_$McPID.dmp"
    $DumpProc = Start-Process -FilePath "$ToolDir\procdump.exe" -ArgumentList "-ma $McPID `"$DumpFile`" -accepteula" -Wait -PassThru -NoNewWindow
    
    if (Test-Path $DumpFile) {
        Write-Host "       Scanning for strings..." -ForegroundColor Gray
        $HitCount = 0
        
        & "$ToolDir\strings.exe" -n 6 $DumpFile | ForEach-Object {
            $Line = $_
            
            # FIXED: Regex now handles false positives better
            if ($Line -match $CheatRegex) {
                Write-Host "       [!!!] CHEAT DETECTED: $Line" -ForegroundColor Red -BackgroundColor Yellow
                $HitCount++
            }
            if ($Line -match "\.class$") {
                if ($Line -match "(?i)(Mixins|Client|Cheat|Hack|Impl|Wrapper|Loader)") {
                     if ($Line -notmatch "net/minecraft" -and $Line -notmatch "com/mojang" -and $Line -notmatch "apache") {
                        Write-Host "       [CLASS] $Line" -ForegroundColor Magenta
                     }
                }
            }
        }
        
        if ($HitCount -eq 0) { Write-Host "       [-] No blatant strings found." -ForegroundColor Green }
        Remove-Item $DumpFile -Force
    }
}

Write-Host "`n[ SCAN COMPLETE ]" -ForegroundColor Cyan
Pause
