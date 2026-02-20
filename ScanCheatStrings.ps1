Write-Host @"
=============================================
                    Nioki
=============================================
"@

# 1. Check for javaw process
$javaProc = Get-Process -Name "javaw" -ErrorAction SilentlyContinue

if (-not $javaProc) {
    Write-Host "[-] javaw.exe is not running. Please start Minecraft first." -ForegroundColor Red
    exit
}

# Renamed to $JavaPID to avoid the read-only error
$JavaPID = $javaProc.Id[0]
$tempFile = "$env:TEMP\javaw_strings.txt"
$stringsPath = "$env:USERPROFILE\Downloads\strings.exe"

# 2. Auto-Download strings.exe if missing
if (-not (Get-Command "strings.exe" -ErrorAction SilentlyContinue) -and -not (Test-Path $stringsPath)) {
    Write-Host "[*] strings.exe not found. Downloading from Microsoft..." -ForegroundColor Yellow
    $url = "https://download.sysinternals.com/files/Strings.zip"
    $zipPath = "$env:TEMP\Strings.zip"
    
    Invoke-WebRequest -Uri $url -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath "$env:TEMP\StringsExtract" -Force
    Move-Item -Path "$env:TEMP\StringsExtract\strings.exe" -Destination $stringsPath -Force
    
    # Cleanup zip
    Remove-Item $zipPath, "$env:TEMP\StringsExtract" -Recurse -ErrorAction SilentlyContinue
}

if (Test-Path $stringsPath) { Set-Alias strings $stringsPath }

Write-Host "[*] Found javaw.exe (PID: $JavaPID)" -ForegroundColor Cyan
Write-Host "[*] Extracting strings from memory... Please wait." -ForegroundColor Yellow

# 3. Extract strings using the corrected variable
try {
    strings -a -p $JavaPID > $tempFile
} catch {
    Write-Host "[-] Failed to extract strings. Run as Administrator." -ForegroundColor Red
    exit
}

# 4. Comprehensive Cheat String List (Including all new requests)
$cheatStrings = @(
    "AimAssist", "Automatically aims at players for you", "AnchorMacro", "AutoCrystal", 
    "placeDelay", "breakDelay", "stopOnKill", "clickSimulation", "damageTick", 
    "particleChance", "antiWeakness", "Automatically crystals fast for you", "fakePunch", 
    "Switch Delay", "Switch Chance", "Sword Swap", "Work With Crystal", "Work With Totem", 
    "Auto Hit Crystal", "Automatically hit-crystals for you", "Auto Inventory Totem", 
    "autoOpen", "forceTotem", "totemSlot", "AutoJumpReset", "AutoPot", "throwDelay", 
    "goToPrevSlot", "AutoWTap", "HoverTotem", "autoSwitch", "TriggerBot", "onlyCritSword", 
    "AutoClicker", "AutoXP", "FakeLag", "Freecam", "PingSpoof", "anchorOnAnchor", 
    "doubleGlowstone", "glowstoneMisplace", "DoubleAnchor", "NoBreakDelay", "NoJumpDelay", 
    "PLACE_DELAY", "BREAK_DELAY", "PLACE_CHANCE", "BREAK_CHANCE", "STOP_ON_KILL", 
    "DAMAGE_TICK", "switchToSword", "damageTickCheck", "isDeadBodyNearby", "SWITCH_CHANCE", 
    "EXPLODE_DELAY_MS", "EXPLODE_SLOT", "isRightClickHeld", "PacketLag", "wasOnGround", 
    "isAttackButtonPressed", "findKnockbackSword", "Failed to create temp file",
    # New String Detections
    "onlyOnGround", "originalSlot", "isSwapped", "switchBack", "setSlot", "breachSlot", 
    "executeMacroStep", "getSelectedSlot", "swingHand", "activateKeyPressed", 
    "findItemInHotbar", "MouseSimulation", "mouseClick", "waitingToAttack", "pendingTarget"
)

if (Test-Path $tempFile) {
    $lines = Get-Content $tempFile
    $caughtStrings = @()

    Write-Host "[*] Scanning memory for cheat signatures..." -ForegroundColor Cyan

    foreach ($str in $cheatStrings) {
        if ($lines -match [regex]::Escape($str)) {
            $caughtStrings += $str
        }
    }

    if ($caughtStrings.Count -gt 0) {
        Write-Host "`n[!] DETECTED CHEAT STRINGS IN MEMORY:`n" -ForegroundColor Red
        $caughtStrings | Sort-Object | Get-Unique | ForEach-Object { Write-Host " -> $_" -ForegroundColor Red }
    } else {
        Write-Host "[+] No suspicious strings found in javaw memory." -ForegroundColor Green
    }

    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

Write-Host "`nDone." -ForegroundColor Cyan
