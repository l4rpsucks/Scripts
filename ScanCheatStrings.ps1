Write-Host @"
=============================================
                    Nioki
=============================================
"@

# 1. Identify Minecraft Process
$javaProc = Get-Process -Name "javaw" -ErrorAction SilentlyContinue
if (-not $javaProc) { 
    Write-Host "[-] javaw.exe is not running. Please start Minecraft first." -ForegroundColor Red
    exit 
}

$JavaPID = $javaProc.Id[0]
$dumpFile = "$env:TEMP\javaw_heap.hprof"
$stringsFile = "$env:TEMP\heap_strings.txt"

# 2. Check for JDK (Required for Deep Scan)
$jcmd = Get-Command "jcmd.exe" -ErrorAction SilentlyContinue
if ($null -eq $jcmd) {
    Write-Host "[!] JDK not found. Deep Scan (Heap Dump) requires the Java Development Kit." -ForegroundColor Yellow
    Write-Host "[*] Falling back to standard memory scan using strings.exe..." -ForegroundColor Gray
    $mode = "Standard"
} else {
    Write-Host "[*] JCMD Found. Using Deep Scan Mode..." -ForegroundColor Cyan
    $mode = "Deep"
}

Write-Host "[*] Target: javaw.exe (PID: $JavaPID)" -ForegroundColor Cyan
Write-Host "[*] Extracting signatures... Please wait (Game may freeze briefly)." -ForegroundColor Yellow

# 3. Extraction Logic
try {
    if ($mode -eq "Deep") {
        # Perform live heap dump (captures internal Java strings)
        & $jcmd $JavaPID GC.heap_dump $dumpFile | Out-Null
        # Extract readable text from the binary dump
        Get-Content $dumpFile -Raw | Select-String -AllMatches -Pattern "[a-zA-Z0-9_/ ]{4,}" | 
            ForEach-Object { $_.Matches.Value } > $stringsFile
    } else {
        # Standard strings.exe logic
        $stringsPath = "$env:USERPROFILE\Downloads\strings.exe"
        if (Test-Path $stringsPath) {
            & $stringsPath -a -p $JavaPID > $stringsFile
        } else {
            Write-Host "[-] strings.exe not found. Cannot perform scan." -ForegroundColor Red; exit
        }
    }
} catch {
    Write-Host "[-] Extraction failed. Make sure to Run as Administrator." -ForegroundColor Red
    exit
}

# 4. Updated Cheat String List
$cheatStrings = @(
    "AimAssist", "Automatically aims at players for you", "AnchorMacro", "AutoCrystal", 
    "placeDelay", "breakDelay", "stopOnKill", "clickSimulation", "damageTick", 
    "particleChance", "antiWeakness", "fakePunch", "Switch Delay", "Sword Swap", 
    "Work With Crystal", "Work With Totem", "Auto Hit Crystal", "Auto Inventory Totem", 
    "autoOpen", "forceTotem", "totemSlot", "AutoJumpReset", "AutoPot", "throwDelay", 
    "goToPrevSlot", "AutoWTap", "HoverTotem", "autoSwitch", "TriggerBot", "onlyCritSword", 
    "AutoClicker", "AutoXP", "FakeLag", "Freecam", "PingSpoof", "NoBreakDelay", "NoJumpDelay", 
    "PLACE_DELAY", "BREAK_DELAY", "STOP_ON_KILL", "DAMAGE_TICK", "isDeadBodyNearby", 
    "onlyOnGround", "originalSlot", "isSwapped", "switchBack", "setSlot", "breachSlot", 
    "executeMacroStep", "getSelectedSlot", "swingHand", "activateKeyPressed", 
    "findItemInHotbar", "MouseSimulation", "mouseClick", "waitingToAttack", "pendingTarget",
    "Stop On Kill", "Particle Chance", "Randomization", "placeClock", "breakClock",
    "Fake Punch", "FakePunch", "Damage Tick", "DamageTick", "Shield Disabler", "ShieldDisabler"
)

# 5. Scan & Results
if (Test-Path $stringsFile) {
    $results = Get-Content $stringsFile
    $found = @()

    foreach ($str in $cheatStrings) {
        if ($results -match [regex]::Escape($str)) { $found += $str }
    }

    if ($found.Count -gt 0) {
        Write-Host "`n[!] DETECTED CHEAT SIGNATURES:`n" -ForegroundColor Red
        $found | Sort-Object | Get-Unique | ForEach-Object { Write-Host " -> $_" -ForegroundColor Red }
    } else {
        Write-Host "[+] No suspicious signatures found in memory." -ForegroundColor Green
    }

    # Cleanup
    Remove-Item $dumpFile, $stringsFile -ErrorAction SilentlyContinue
}

Write-Host "`nDone." -ForegroundColor Cyan
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
