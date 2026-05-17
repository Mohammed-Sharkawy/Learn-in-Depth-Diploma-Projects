# Create the folder if it doesn't exist
New-Item -ItemType Directory -Path "C:\AdminTools" -Force | Out-Null

# Prompt for credentials and export them encrypted
Get-Credential -Message "Enter TEST\Administrator credentials for Sysmon deployment" |
    Export-Clixml -Path "C:\AdminTools\sysmon-cred.xml"

Write-Host "Encrypted credential file created at C:\AdminTools\sysmon-cred.xml" -ForegroundColor Green