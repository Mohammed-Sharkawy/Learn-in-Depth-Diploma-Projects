# =============================================================================
# Multi-Server Sysmon Deployment Script (Encrypted Credentials)
# =============================================================================

$credPath = "C:\AdminTools\sysmon-cred.xml"
if (-not (Test-Path $credPath)) {
    Write-Error "Credential file not found at $credPath. Run the one-time setup first."
    exit 1
}
$cred = Import-Clixml -Path $credPath

$targets = Get-Content "C:\Sysmon\Targets.txt" | Where-Object { $_.Trim() -ne "" }

$sourcePath = "C:\Sysmon"

# Validate source files exist locally
if (-not (Test-Path "$sourcePath\Sysmon64.exe")) {
    Write-Error "Sysmon64.exe not found in $sourcePath. Aborting."
    exit 1
}
if (-not (Test-Path "$sourcePath\sysmonconfig-export.xml")) {
    Write-Error "sysmonconfig-export.xml not found in $sourcePath. Aborting."
    exit 1
}

$results = @()

foreach ($target in $targets) {
    $session = $null
    $status = "Success"
    $details = "Sysmon installed successfully"

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Processing: $target" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    try {
        # --- Connect ---
        $session = New-PSSession -ComputerName $target -Credential $cred -ErrorAction Stop
        Write-Host "[+] Connected to $target" -ForegroundColor Green

        # --- Create directory ---
        Invoke-Command -Session $session -ScriptBlock {
            New-Item -ItemType Directory -Path "C:\sysmon" -Force | Out-Null
        } -ErrorAction Stop
        Write-Host "[+] Destination directory ready" -ForegroundColor Green

        # --- Copy files ---
        Copy-Item "$sourcePath\*.*" -ToSession $session -Destination "C:\sysmon" -Recurse -Force -ErrorAction Stop
        Write-Host "[+] Files copied successfully" -ForegroundColor Green

        # --- Install Sysmon (fixed to handle false stderr output) ---
        $installResult = Invoke-Command -Session $session -ScriptBlock {
            # Method 1: Redirect stderr to stdout, suppress display
            & "C:\sysmon\Sysmon64.exe" -accepteula -i "C:\sysmon\sysmonconfig-export.xml" 2>&1 | Out-Null
            
            # Real verification: check the service state
            $svc = Get-Service -Name Sysmon64 -ErrorAction SilentlyContinue
            if (-not $svc) {
                return @{ Success = $false; Message = "Service not found after install" }
            }
            if ($svc.Status -ne 'Running') {
                Start-Service -Name Sysmon64
            }
            return @{ Success = $true; Message = "Service is $($svc.Status)" }
        } -ErrorAction Stop

        if (-not $installResult.Success) {
            throw $installResult.Message
        }

        Write-Host "[+] Sysmon installed and verified successfully ($($installResult.Message))" -ForegroundColor Green

    }
    catch {
        $status = "Failed"
        $details = $_.Exception.Message
        Write-Host "[!] FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        if ($session) {
            Remove-PSSession $session -ErrorAction SilentlyContinue
            Write-Host "[+] Session closed" -ForegroundColor Gray
        }

        $results += [PSCustomObject]@{
            Target     = $target
            Status     = $status
            Details    = $details
            Timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
}

# =============================================================================
# Final Report
# =============================================================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

$results | Format-Table -AutoSize

$reportPath = "C:\AdminTools\Sysmon_Deploy_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$results | Export-Csv -Path $reportPath -NoTypeInformation -Force
Write-Host "Report saved to: $reportPath" -ForegroundColor Green