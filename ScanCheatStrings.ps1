Write-Host @"
=============================================
                    Nioki
=============================================
"@

# 1. Identify Minecraft Process
$javaProc = Get-Process -Name "javaw" -ErrorAction SilentlyContinue
if (-not $javaProc) { 
    Write-Host "[-] javaw.exe not found." -ForegroundColor Red; exit 
}
$JavaPID = $javaProc.Id[0]
$dumpFile = "$env:TEMP\heap_dump.hprof"
$stringsFile = "$env:TEMP\decoded_strings.txt"

# 2. Deep Scan: Use JCMD to dump the Java Heap
Write-Host "[*] Starting Deep Scan on PID $JavaPID..." -ForegroundColor Cyan
Write-Host "[!] This may freeze Minecraft for a few seconds." -ForegroundColor Yellow

# Try to find jcmd.exe (requires JDK)
$jcmd = Get-Command "jcmd.exe" -ErrorAction SilentlyContinue
if ($null -eq $jcmd) {
    Write-Host "[-] JCMD not found. Deep Scan requires the Java Development Kit (JDK)." -ForegroundColor Red
    Write-Host "[*] Falling back to standard memory scan..." -ForegroundColor Gray
    # Standard strings logic would go here
} else {
    # Generate a live heap dump
    & $jcmd $JavaPID GC.heap_dump $dumpFile
}

# 3. Analyze the Heap for Signatures
$cheatStrings = @(
    "AimAssist", "AutoCrystal", "FakePunch", "ShieldDisabler", "DamageTick",
    "breachSlot", "placeClock", "breakClock", "Randomization", "pendingTarget",
    # Class path signatures (harder to obfuscate)
    "Lcom/client/module", "net/minecraft/client/gui", "render/ESP"
)

if (Test-Path $dumpFile) {
    # Extract readable text from the binary heap dump
    Get-Content $dumpFile -Raw | Select-String -AllMatches -Pattern "[a-zA-Z0-9_/]{4,}" | 
        ForEach-Object { $_.Matches.Value } > $stringsFile

    $found = @()
    $lines = Get-Content $stringsFile
    foreach ($str in $cheatStrings) {
        if ($lines -match [regex]::Escape($str)) { $found += $str }
    }

    if ($found.Count -gt 0) {
        Write-Host "`n[!] DEEP SCAN DETECTED:`n" -ForegroundColor Red
        $found | Sort-Object | Get-Unique | ForEach-Object { Write-Host " -> $_" -ForegroundColor Red }
    } else {
        Write-Host "[+] Deep Scan clean." -ForegroundColor Green
    }

    # Cleanup large dump file
    Remove-Item $dumpFile, $stringsFile -ErrorAction SilentlyContinue
}

Write-Host "`nDone." -ForegroundColor Cyan
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
