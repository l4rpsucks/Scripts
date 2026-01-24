<#
    .SYNOPSIS
    Minecraft Inspector v4.3 (Strict "Exact Word" Matching)
    
    .DESCRIPTION
    1. STRICT REGEX: "Reach" now requires "\bReach\b" (Word Boundaries).
       - Matches: "Reach", " Reach ", "Reach."
       - IGNORES: "Breach", "Preach", "Reaching", "Outreach".
    2. RETAINS: Modrinth Integrity Check & Zone Identifier.
#>

# --- CONFIGURATION ---
$ToolDir = "C:\SS_Tools_Temp"
$DumpDir = "C:\SS_Memory_Dumps"
$Urls = @{
    "handle"   = "https://live.sysinternals.com/handle.exe"
    "procdump" = "https://live.sysinternals.com/procdump.exe"
    "strings"  = "https://live.sysinternals.com/strings.exe"
}

# --- CHEAT DATABASE (STRICT VS BROAD) ---

# 1. EXACT MATCH ONLY (Wrapped in \b...\b)
# These are common words that MUST be standalone to be considered a cheat.
$ExactWords = @(
    "Reach",       # Will NOT match "Breach"
    "Velocity",    # Will NOT match "HighVelocity"
    "Flight",      # Will NOT match "Inflight"
    "Timer",       # Will NOT match "TimerTask"
    "Blink",
    "Step",
    "AimAssist"
)
# Create Regex: \bReach\b|\bVelocity\b
$ExactRegex = ($ExactWords | ForEach-Object { "\b$_\b" }) -join "|"

# 2. BROAD MATCH (Standard Regex)
# Unique names where we want to catch "VapeClient", "Vape_v4", etc.
$BroadWords = @(
    "Argon", "Vape", "Meteor Client", "Krypton Client", "Raven", 
    "LiquidBounce", "Sigma", "Wurst", "Aristois", "Inertia", 
    "Rise Client", "Tenacity", "Augustus",
    "Autototem", "AutoCrystal", "AnchorMacro", "KillAura"
)
$BroadRegex = ($BroadWords -join "|")

# COMBINE: ((Strict)|(Broad))
$FinalCheatRegex = "(?i)($ExactRegex|$BroadRegex)"


# --- FALSE POSITIVE IGNORE LIST ---
$IgnoreList = @(
    "Washington state law", "breach of contract", "breach of warranty", 
    "conflict of laws", "consumer protection laws", "negligence", 
    "Mojang Synergies", "Apache Software"
)

# Setup
if (-not (Test-Path $ToolDir)) { New-Item -Path $ToolDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $DumpDir)) { New-Item -Path $DumpDir -ItemType Directory -Force | Out-Null }

Clear-Host
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   MINECRAFT INSPECTOR v4.3 (STRICT MODE)          " -ForegroundColor Cyan
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
$MCProcs = Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'" | Where-Object {$_.CommandLine -match "minecraft"}
if (-not $MCProcs) { 
    Write-Host "[-] No Minecraft process found." -ForegroundColor Red
    $MCProcs = Get-CimInstance Win32_Process -Filter "Name='javaw.exe'"
}

foreach ($Proc in $MCProcs) {
    $McPID = $Proc.ProcessId
    Write-Host "`n[ TARGET LOCKED ] PID: $McPID | Name: $($Proc.Name)" -ForegroundColor Green -BackgroundColor Black

    # --- PHASE A: INTEGRITY & ORIGIN ---
    Write-Host "`n   [A] FILE INTEGRITY & ORIGIN" -ForegroundColor Yellow
    
    $HandleOut = & "$ToolDir\handle.exe" -p $McPID -accepteula
    $FoundJars = $HandleOut | Select-String "(?i)([a-z]:\\[^:<>\x22]+\.jar)" -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Unique

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
    }

    # --- PHASE B: MEMORY STRING SCAN (STRICT) ---
    Write-Host "`n   [B] MEMORY STRING SCAN (Strict Match: ON)" -ForegroundColor Yellow
    Write-Host "       Dumping memory..." -ForegroundColor Gray
    
    $DumpFile = "$DumpDir\mc_dump_$McPID.dmp"
    $DumpProc = Start-Process -FilePath "$ToolDir\procdump.exe" -ArgumentList "-ma $McPID `"$DumpFile`" -accepteula" -Wait -PassThru -NoNewWindow
    
    if (Test-Path $DumpFile) {
        Write-Host "       Scanning strings..." -ForegroundColor Gray
        $HitCount = 0
        
        & "$ToolDir\strings.exe" -n 6 $DumpFile | ForEach-Object {
            $Line = $_.Trim()
            
            # 1. APPLY REGEX
            if ($Line -match $FinalCheatRegex) {
                
                # 2. CHECK IGNORE LIST
                $IsSafe = $false
                foreach ($Safe in $IgnoreList) { if ($Line -match [regex]::Escape($Safe)) { $IsSafe = $true; break } }
                
                if (-not $IsSafe) {
                    Write-Host "       [!!!] CHEAT DETECTED: $Line" -ForegroundColor Red -BackgroundColor Yellow
                    $HitCount++
                }
            }
        }
        
        if ($HitCount -eq 0) { Write-Host "       [-] No blatant strings found." -ForegroundColor Green }
        Remove-Item $DumpFile -Force
    }
}
Write-Host "`n[ SCAN COMPLETE ]" -ForegroundColor Cyan
Pause
