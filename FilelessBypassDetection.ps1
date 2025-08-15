<#
.SYNOPSIS
  Detects PowerShell fileless bypasses by monitoring Event ID 600 (engine start) and Event ID 4104 (script block logging).
  Extracts suspicious commands (including Invoke-WebRequest usage) and saves findings to a CSV file.
.DESCRIPTION
  - Queries Windows PowerShell event logs for Event ID 600 and 4104.
  - Extracts command lines and script blocks containing 'Invoke-WebRequest'.
  - Saves results (date, type, suspicious command/script) to a CSV file.
  - User can choose to save in current directory or specify a location.
#>


$choice = Read-Host "Save CSV to current directory? (Y/N)"
if ($choice -match "^[Yy]") {
    $OutputDirectory = Get-Location
} else {
    $OutputDirectory = Read-Host "Enter full path to save the CSV file"
    if (-not (Test-Path $OutputDirectory)) {
        Write-Host "Directory does not exist. Creating: $OutputDirectory"
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    }
}

$CsvFile = Join-Path $OutputDirectory "FilelessBypassDetection.csv"

$results = @()

$events600 = Get-WinEvent -FilterHashtable @{
    LogName='Windows PowerShell'
    Id=600
} | Select-Object -Property TimeCreated, Message

foreach ($event in $events600) {
    $command = ""
    if ($event.Message -match "CommandLine = (.+)") {
        $command = $matches[1].Trim()
    }
    if ($command) {
        $results += [PSCustomObject]@{
            Date    = $event.TimeCreated
            Type    = "EngineStart"
            Details = $command
        }
    }
}

$events4104 = Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-PowerShell/Operational'
    Id=4104
} | Select-Object -Property TimeCreated, Message

foreach ($event in $events4104) {
    $scriptBlock = $event.Message
    if ($scriptBlock -match "(?i)Invoke-WebRequest") {
        $results += [PSCustomObject]@{
            Date    = $event.TimeCreated
            Type    = "ScriptBlock-InvokeWebRequest"
            Details = $scriptBlock
        }
    }
}


$results | Export-Csv -Path $CsvFile -NoTypeInformation -Force

Write-Host "`nSaved results to $CsvFile"
