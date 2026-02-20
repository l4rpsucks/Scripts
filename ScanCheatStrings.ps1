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

$pid = $javaProc.Id[0]
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

# Set alias if we just downloaded it
if (Test-Path $stringsPath) {
    Set-Alias strings $stringsPath
}

Write-Host "[*] Found javaw.exe (PID: $pid)" -ForegroundColor Cyan
Write-Host "[*] Extracting strings from memory... Please wait." -ForegroundColor Yellow

# 3. Extract strings from memory 
try {
    # -a (scan all), -p (numeric process ID)
    strings -a -p $pid > $tempFile
} catch {
    Write-Host "[-] Failed to extract strings. You might need to run as Administrator." -ForegroundColor Red
    exit
}

# 4. Scan for Cheat Strings
$cheatStrings = @(
    "AimAssist", "Automatically aims at players for you", "AnchorMacro",
    "AutoCrystal", "placeDelay", "breakDelay", "stopOnKill",
    "clickSimulation", "damageTick", "particleChance", "antiWeakness",
    "Automatically crystals fast for you", "fakePunch", "Switch Delay",
    "Switch Chance", "Sword Swap", "Work With Crystal", "Work With Totem",
    "Auto Hit Crystal", "Automatically hit-crystals for you", "Auto Inventory Totem",
    "autoOpen", "forceTotem", "totemSlot", "AutoJumpReset", "AutoPot",
    "throwDelay", "goToPrevSlot", "AutoWTap", "HoverTotem", "autoSwitch",
    "TriggerBot", "onlyCritSword", "AutoClicker", "AutoXP", "FakeLag",
    "Freecam", "PingSpoof", "anchorOnAnchor", "doubleGlowstone",
    "glowstoneMisplace", "DoubleAnchor", "NoBreakDelay", "NoJumpDelay",
    "PLACE_DELAY", "BREAK_DELAY", "PLACE_CHANCE", "BREAK_CHANCE",
    "STOP_ON_KILL", "DAMAGE_TICK", "switchToSword", "damageTickCheck",
    "isDeadBodyNearby", "SWITCH_CHANCE", "EXPLODE_DELAY_MS", "EXPLODE_SLOT",
    "isRightClickHeld", "PacketLag", "wasOnGround", "isAttackButtonPressed",
    "findKnockbackSword", "Failed to create temp file"
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

    # 5. Results
    if ($caughtStrings.Count -gt 0) {
        Write-Host "`n[!] DETECTED CHEAT STRINGS IN MEMORY:`n" -ForegroundColor Red
        $caughtStrings | Sort-Object | Get-Unique | ForEach-Object { Write-Host " -> $_" -ForegroundColor Red }
    } else {
        Write-Host "[+] No suspicious strings found in javaw memory." -ForegroundColor Green
    }

    # Cleanup memory dump for privacy
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

Write-Host "`nDone." -ForegroundColor Cyan
