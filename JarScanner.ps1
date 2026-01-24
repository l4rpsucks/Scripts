<#
    .SYNOPSIS
    Minecraft Inspector v4.0 (Integrity + Origin Trace + Memory)
    
    .DESCRIPTION
    1. TOOLS: Downloads Handle, Procdump, Strings.
    2. DISK: 
       - Lists loaded .jars.
       - HASH CHECK: Verifies against Modrinth API.
       - ORIGIN CHECK: Reads 'Zone.Identifier' ADS to find source URL.
    3. MEMORY: Dumps memory and greps for cheats.
#>

# --- CONFIGURATION ---
$ToolDir = "C:\SS_Tools_Temp"
$DumpDir = "C:\SS_Memory_Dumps"
$Urls = @{
    "handle"   = "https://live.sysinternals.com/handle.exe"
    "procdump" = "https://live.sysinternals.com/procdump.exe"
    "strings"  = "https://live.sysinternals.com/strings.exe"
}

# --- CHEAT SIGNATURE DATABASE ---
$ClientNames = "Argon|Vape|Meteor Client|Krypton Client|Raven|LiquidBounce|Sigma|Wurst|Aristois|Inertia|Rise Client|Tenacity|Augustus"
$GenericCheats = "PlaceDelay|SwitchDelay|ExpandHitboxes|ExplodeChance|PlaceChance|SwitchChance|StopOnKill|Velocity|AntiKnockback"
$BlatantMods = "Autototem|AutoCrystal|AnchorMacro|AutoHitCrystal|AutoDoubleHand|TotemOffhand|Auto Xp|Auto Wtap|TriggerBot|AimAssist|AutoPot|AutoPotRefill|Reach|AutoJumpReset|NoMissDelay"
$CheatRegex = "(?i)($ClientNames|$GenericCheats|$BlatantMods)"

# Setup
if (-not (Test-Path $ToolDir)) { New-Item -Path $ToolDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $DumpDir)) { New-Item -Path $DumpDir -ItemType Directory -Force | Out-Null }

Clear-Host
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   MINECRAFT INSPECTOR v4.0 (ORIGIN TRACER)        " -ForegroundColor Cyan
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
$MCProcs = Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'"
if (-not $MCProcs) { Write-Host "[-] No 'javaw.exe' found." -ForegroundColor Red; Pause; Exit }

foreach ($Proc in $MCProcs) {
    $PID = $Proc.ProcessId
    Write-Host "`n[ TARGET LOCKED ] PID: $PID | Name: $($Proc.Name)" -ForegroundColor Green -BackgroundColor Black

    # --- PHASE A: INTEGRITY & ORIGIN SCAN ---
    Write-Host "`n   [A] FILE INTEGRITY & ORIGIN (Disk Artifacts)" -ForegroundColor Yellow
    Write-Host "       Scanning loaded jars for Modrinth Hashes and Zone.Identifiers..." -ForegroundColor Gray
    
    $HandleOut = & "$ToolDir\handle.exe" -p $PID -accepteula
    $FoundJars = $HandleOut | Select-String "([a-zA-Z]:\\.*\.jar)" -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Unique

    if ($FoundJars) {
        foreach ($JarPath in $FoundJars) {
            $JarPath = $JarPath.Trim()
            $FileName = Split-Path $JarPath -Leaf
            
            if (Test-Path $JarPath) {
                # 1. Modrinth Hash Check
                $HashObj = Get-FileHash -Path $JarPath -Algorithm SHA1
                $SHA1 = $HashObj.Hash.ToLower()
                
                # Default Status
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
                
                # Print File Status
                Write-Host "   ------------------------------------------------" -ForegroundColor DarkGray
                Write-Host "   FILE: " -NoNewline -ForegroundColor Gray
                Write-Host "$FileName " -NoNewline -ForegroundColor White
                Write-Host "$Status" -ForegroundColor $Color
                
                if ($Status -eq "[UNKNOWN/PRIVATE]") {
                     Write-Host "   PATH: $JarPath" -ForegroundColor DarkGray
                }

                # 2. ZONE.IDENTIFIER CHECK (The Origin Trace)
                $ZoneStream = "$JarPath`:Zone.Identifier"
                if (Test-Path $ZoneStream) {
                    $ZoneContent = Get-Content -Path $ZoneStream -Raw
                    
                    # Regex to pull URLs
                    if ($ZoneContent -match "HostUrl=(.*)") {
                        $Origin = $Matches[1].Trim()
                        Write-Host "   [ORIGIN] $Origin" -ForegroundColor Cyan
                        
                        # Heuristic: Check for common cheat hosts
                        if ($Origin -match "discord" -or $Origin -match "github" -or $Origin -match "mediafire") {
                            Write-Host "            (Suspicious: Downloaded from File Host/Chat, not a repo)" -ForegroundColor Magenta
                        }
                    }
                } else {
                    if ($Status -eq "[UNKNOWN/PRIVATE]") {
                        Write-Host "   [NO ORIGIN] Metadata missing (File cleaned or moved from USB?)" -ForegroundColor Red
                    }
                }
            }
        }
    } else {
        Write-Host "   [-] No .jar handles found. (Is game fully loaded?)" -ForegroundColor Red
    }

    # --- PHASE B: MEMORY STRING SCAN ---
    Write-Host "`n   [B] MEMORY STRING SCAN (Deep Analysis)" -ForegroundColor Yellow
    Write-Host "       Dumping memory..." -ForegroundColor Gray
    
    $DumpFile = "$DumpDir\mc_dump_$PID.dmp"
    $DumpProc = Start-Process -FilePath "$ToolDir\procdump.exe" -ArgumentList "-ma $PID `"$DumpFile`" -accepteula" -Wait -PassThru -NoNewWindow
    
    if (Test-Path $DumpFile) {
        Write-Host "       Scanning for strings..." -ForegroundColor Gray
        $HitCount = 0
        
        & "$ToolDir\strings.exe" -n 6 $DumpFile | ForEach-Object {
            $Line = $_
            
            if ($Line -match $CheatRegex) {
                Write-Host "       [!!!] CHEAT DETECTED: $Line" -ForegroundColor Red -BackgroundColor Yellow
                $HitCount++
            }
            if ($Line -match "\.class$") {
                if ($Line -match "(?i)(Mixins|Client|Cheat|Hack|Impl|Wrapper|Loader)") {
                     if ($Line -notmatch "net/minecraft" -and $Line -notmatch "com/mojang") {
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