
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

$events = Get-WinEvent -FilterHashtable @{
    LogName='Windows PowerShell'
    Id=600
} | Select-Object -Property TimeCreated, Message

$results = @()
foreach ($event in $events) {
    $command = ""
    if ($event.Message -match "CommandLine = (.+)") {
        $command = $matches[1].Trim()
    }
    if ($command) {
        $results += [PSCustomObject]@{
            Date    = $event.TimeCreated
            Command = $command
        }
    }
}

$results | Export-Csv -Path $CsvFile -NoTypeInformation -Force

Write-Host "`nSaved results to $CsvFile"
