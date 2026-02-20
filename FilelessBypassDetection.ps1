Write-Host @"
=============================================
                    Nioki
=============================================
"@

$eventIDs = 600, 4104, 403, 800, 4103, 4100
$base64Pattern = '[A-Za-z0-9+/]{100,}={0,2}'

# Detects Reflection, IEX, Web Requests, File Droppers, and Java Execution
$alertPattern = 'Invoke-Expression|IEX|Invoke-RestMethod|IRM|\[System\.Reflection\.Assembly\]::Load\(|Net\.WebClient|DownloadData|WriteAllBytes|DownloadFile|java\s+-jar'

while ($true) {
    $useCurrent = Read-Host "Save CSV to current folder? (Y/N)"
    if ($useCurrent -match '^[YyNn]$') { break }
}

if ($useCurrent -match '^[Yy]$') {
    $outFolder = Get-Location
} else {
    do {
        $outFolder = Read-Host "Enter full folder path"
        if (-not (Test-Path $outFolder)) {
            Write-Host "Folder not found, try again." -ForegroundColor Red
            $outFolder = $null
        }
    } while (-not $outFolder)
}

while ($true) {
    $combine = Read-Host "Put all results in one CSV? (Y/N)"
    if ($combine -match '^[YyNn]$') { break }
}

while ($true) {
    $optimize = Read-Host "Optimize messages in CSV? (Y/N)"
    if ($optimize -match '^[YyNn]$') { break }
}

while ($true) {
    $filterToday = Read-Host "Only events from today? (Y/N)"
    if ($filterToday -match '^[YyNn]$') { break }
}

if ($filterToday -match '^[Yy]$') {
    $startTime = [datetime]::Today
    $endTime = $startTime.AddDays(1).AddSeconds(-1)
} else {
    $startTime = $null
    $endTime = $null
}

$all = @()
$alertsOnly = @()
$byEvent = @{}

Write-Host "`nGetting events..." -ForegroundColor Cyan

foreach ($id in $eventIDs) {
    $logName = if ($id -eq 600) { "Windows PowerShell" } else { "Microsoft-Windows-PowerShell/Operational" }
    try {
        $evts = Get-WinEvent -FilterHashtable @{LogName=$logName; Id=$id} -ErrorAction Stop
    } catch {
        Write-Host "Can't get events for ID $id in $logName" -ForegroundColor Red
        continue
    }

    foreach ($evt in $evts) {
        if ($startTime) {
            if ($evt.TimeCreated -lt $startTime -or $evt.TimeCreated -gt $endTime) { continue }
        }

        $msg = $evt.Message
        if (-not $msg -or $msg -match '^Provider ".*" is Started') { continue }

        $outMsg = $null
        if ($msg -match 'HostApplication=(.+?)(\s\w+=|\s*$)') {
            $outMsg = $matches[1].Trim()
        } elseif ($msg -match 'CommandLine=(.+?)(\s\w+=|\s*$)') {
            $outMsg = $matches[1].Trim()
        } elseif ($msg -match 'Error Message =') {
            if ($msg -match 'Host Application = (.+?)(\r?\n\S+\s*=|\r?\n$)') {
                $outMsg = $matches[1].Trim()
            } else {
                $outMsg = ($msg -split "`r?`n")[0].Trim()
            }
        } else {
            $outMsg = $msg.Trim()
        }

        if ($optimize -match '^[Yy]$' -and $outMsg) {
            if ($outMsg -match '^(.+?)(;|`n|`r|$)') {
                $outMsg = $matches[1].Trim()
            }
        }

        if ([string]::IsNullOrWhiteSpace($outMsg)) { continue }

        $base64 = if ($outMsg -match $base64Pattern) { "Yes" } else { "No" }

        $obj = [PSCustomObject]@{
            TimeCreated = $evt.TimeCreated
            Message     = $outMsg
            EventID     = $id
            Base64      = $base64
        }

        $all += $obj

        # Check for High-Risk Commands including java -jar
        if ($outMsg -match $alertPattern) {
            $alertsOnly += $obj
        }

        if (-not $byEvent.ContainsKey($id)) {
            $byEvent[$id] = @()
        }
        $byEvent[$id] += $obj
    }
}

if ($all.Count -eq 0) {
    Write-Host "No events found." -ForegroundColor Yellow
    exit
}

$date = (Get-Date).ToString("yyyy-MM-dd")

if ($combine -match '^[Yy]$') {
    $file = Join-Path $outFolder "PowerShell_Combined_$date.csv"
    $all | Sort-Object TimeCreated | Export-Csv -Path $file -NoTypeInformation -Encoding UTF8 -Force
    Write-Host "`nSaved all results to $file" -ForegroundColor Green
} else {
    foreach ($k in $byEvent.Keys) {
        $file = Join-Path $outFolder "$k`_$date.csv"
        $byEvent[$k] | Sort-Object TimeCreated | Export-Csv -Path $file -NoTypeInformation -Encoding UTF8 -Force
        Write-Host "Saved $file" -ForegroundColor Green
    }

    if ($alertsOnly.Count) {
        $file = Join-Path $outFolder "AlertsOnly_$date.csv"
        $alertsOnly | Sort-Object TimeCreated | Export-Csv -Path $file -NoTypeInformation -Encoding UTF8 -Force
        Write-Host "Saved $file (Check for Java/Dropper/Web behavior)" -ForegroundColor Red
    }
}

Write-Host "`nDone." -ForegroundColor Cyan
