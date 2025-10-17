# Prompt user for the path to the dump file
$dumpFile = Read-Host "Enter the path to your strings.txt file"

# List of known cheat client strings to scan for
$cheatStrings = @(
    "AimAssist",
    "Automatically aims at players for you",
    "AnchorMacro",
    "AutoCrystal",
    "placeDelay",
    "breakDelay",
    "stopOnKill",
    "clickSimulation",
    "damageTick",
    "particleChance",
    "antiWeakness",
    "Automatically crystals fast for you",
    "fakePunch",
    "Switch Delay",
    "Switch Chance",
    "Sword Swap",
    "Work With Crystal",
    "Work With Totem",
    "Auto Hit Crystal",
    "Automatically hit-crystals for you",
    "Auto Inventory Totem",
    "autoOpen",
    "forceTotem",
    "totemSlot",
    "AutoJumpReset",
    "AutoPot",
    "throwDelay",
    "goToPrevSlot",
    "AutoWTap",
    "HoverTotem",
    "autoSwitch",
    "TriggerBot",
    "onlyCritSword",
    "AutoClicker",
    "AutoXP",
    "FakeLag",
    "Freecam",
    "PingSpoof",
    "anchorOnAnchor",
    "doubleGlowstone",
    "glowstoneMisplace",
    "DoubleAnchor",
    "NoBreakDelay",
    "NoJumpDelay",
    "PLACE_DELAY",
    "BREAK_DELAY",
    "PLACE_CHANCE",
    "BREAK_CHANCE",
    "STOP_ON_KILL",
    "DAMAGE_TICK",
    "switchToSword",
    "damageTickCheck",
    "isDeadBodyNearby",
    "SWITCH_CHANCE",
    "EXPLODE_DELAY_MS",
    "EXPLODE_SLOT",
    "isRightClickHeld",
    "PacketLag",
    "wasOnGround",
    "isAttackButtonPressed",
    "findKnockbackSword",
    "Failed to create temp file"
)

if (Test-Path $dumpFile) {
    $lines = Get-Content $dumpFile
    $caughtStrings = @()

    foreach ($str in $cheatStrings) {
        # If any line in the file contains the cheat string
        if ($lines | Where-Object { $_ -match [regex]::Escape($str) }) {
            $caughtStrings += $str
        }
    }

    if ($caughtStrings.Count -gt 0) {
        Write-Host "`nDetected the following cheat strings in $dumpFile:`n"
        $caughtStrings | Sort-Object | Get-Unique | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "No suspicious strings found in $dumpFile."
    }
} else {
    Write-Host "File not found. Please check the path and try again."
}