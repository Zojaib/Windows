$backupfileBefore = "PolAudBeforeChnages.csv"
$backupfileAfter = "PolAudAfterChnages.csv"
$auditPath = "C:\Users\$env:USERNAME\Desktop\"

$backupPathBefore = Join-Path $auditPath $backupfileBefore
$backupPathAfter  = Join-Path $auditPath $backupfileAfter

auditpol /backup /file:$backupPathBefore

# ---------- CSV log setup ----------
$timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $desktop) { $desktop = Join-Path $env:USERPROFILE 'Desktop' } # fallback
$LogFile = Join-Path $desktop "Auditpol_Apply_Results_$timestamp.csv"

# CSV header
$csvHeader = "Timestamp,MachineName,Policy,DCOnly,Executed,Result,Message"
$csvHeader | Out-File -FilePath $LogFile -Encoding UTF8

# ---------- Detect if machine is a Domain Controller ----------
# DomainRole: 0 = Standalone Workstation, 1 = Member Workstation, 2 = Standalone Server,
# 3 = Member Server, 4 = Backup Domain Controller, 5 = Primary Domain Controller
$IsDC = $false
$domainRole = (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole

if ($null -ne $domainRole -and $domainRole -ge 4) { $IsDC = $true }

Write-Host "Machine: $env:COMPUTERNAME    IsDomainController: $IsDC" -ForegroundColor Yellow

# ---------- Define commands----------
# Each item is hashtable: @{ Cmd = '...'; DCOnly = $true|$false; Label = 'Friendly name' }
$commands = @(
    @{Cmd='auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable'; DCOnly=$false; Label='Credential Validation'},
    @{Cmd='auditpol /set /subcategory:"Kerberos Authentication Service" /success:disable /failure:disable'; DCOnly=$false; Label='Kerberos Authentication Service'},
    @{Cmd='auditpol /set /subcategory:"Kerberos Service Ticket Operations" /success:disable /failure:disable'; DCOnly=$false; Label='Kerberos Service Ticket Operations'},
    @{Cmd='auditpol /set /subcategory:"Other Account Logon Events" /success:enable /failure:enable'; DCOnly=$false; Label='Other Account Logon Events'},
    @{Cmd='auditpol /set /subcategory:"Application Group Management" /success:enable /failure:enable'; DCOnly=$false; Label='Application Group Management'},
    @{Cmd='auditpol /set /subcategory:"Computer Account Management" /success:enable /failure:enable'; DCOnly=$false; Label='Computer Account Management'},
    @{Cmd='auditpol /set /subcategory:"Distribution Group Management" /success:enable /failure:enable'; DCOnly=$false; Label='Distribution Group Management'},
    @{Cmd='auditpol /set /subcategory:"Other Account Management Events" /success:enable /failure:enable'; DCOnly=$false; Label='Other Account Management Events'},
    @{Cmd='auditpol /set /subcategory:"Security Group Management" /success:enable /failure:enable'; DCOnly=$false; Label='Security Group Management'},
    @{Cmd='auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable'; DCOnly=$false; Label='User Account Management'},
    @{Cmd='auditpol /set /subcategory:"DPAPI Activity" /success:disable /failure:disable'; DCOnly=$false; Label='DPAPI Activity'},
    @{Cmd='auditpol /set /subcategory:"Plug and Play Events" /success:enable /failure:disable'; DCOnly=$false; Label='Plug and Play Events'},
    @{Cmd='auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable'; DCOnly=$false; Label='Process Creation'},
    @{Cmd='auditpol /set /subcategory:"Process Termination" /success:enable /failure:enable'; DCOnly=$false; Label='Process Termination'},
    @{Cmd='auditpol /set /subcategory:"RPC Events" /success:enable /failure:enable'; DCOnly=$false; Label='RPC Events'},
    @{Cmd='auditpol /set /subcategory:"Token Right Adjusted Events" /success:enable /failure:disable'; DCOnly=$false; Label='Token Right Adjusted Events'},

    # DC-only categories (will be skipped on non-DCs)
    @{Cmd='auditpol /set /subcategory:"Directory Service Replication Detailed" /success:disable /failure:disable'; DCOnly=$true; Label='Directory Service Replication Detailed'},
    @{Cmd='auditpol /set /subcategory:"Directory Service Replication" /success:enable /failure:disable'; DCOnly=$true; Label='Directory Service Replication'},


    @{Cmd='auditpol /set /subcategory:"Directory Service Access" /success:disable /failure:disable'; DCOnly=$false; Label='Directory Service Access'},
    @{Cmd='auditpol /set /subcategory:"Directory Service Changes" /success:enable /failure:enable'; DCOnly=$false; Label='Directory Service Changes'},
    @{Cmd='auditpol /set /subcategory:"Account Lockout" /success:enable /failure:disable'; DCOnly=$false; Label='Account Lockout'},
    @{Cmd='auditpol /set /subcategory:"User / Device Claims" /success:disable /failure:disable'; DCOnly=$false; Label='User / Device Claims'},
    @{Cmd='auditpol /set /subcategory:"Group Membership" /success:enable /failure:disable'; DCOnly=$false; Label='Group Membership'},
    @{Cmd='auditpol /set /subcategory:"IPsec Extended Mode" /success:disable /failure:disable'; DCOnly=$false; Label='IPsec Extended Mode'},
    @{Cmd='auditpol /set /subcategory:"IPsec Main Mode" /success:disable /failure:disable'; DCOnly=$false; Label='IPsec Main Mode'},
    @{Cmd='auditpol /set /subcategory:"IPsec Quick Mode" /success:disable /failure:disable'; DCOnly=$false; Label='IPsec Quick Mode'},
    @{Cmd='auditpol /set /subcategory:"Logoff" /success:enable /failure:disable'; DCOnly=$false; Label='Logoff'},
    @{Cmd='auditpol /set /subcategory:"Logon" /success:enable /failure:enable'; DCOnly=$false; Label='Logon'},
    @{Cmd='auditpol /set /subcategory:"Network Policy Server" /success:enable /failure:enable'; DCOnly=$false; Label='Network Policy Server'},
    @{Cmd='auditpol /set /subcategory:"Other Logon/Logoff Events" /success:enable /failure:enable'; DCOnly=$false; Label='Other Logon/Logoff Events'},
    @{Cmd='auditpol /set /subcategory:"Special Logon" /success:enable /failure:enable'; DCOnly=$false; Label='Special Logon'},
    @{Cmd='auditpol /set /subcategory:"Application Generated" /success:enable /failure:enable'; DCOnly=$false; Label='Application Generated'},
    @{Cmd='auditpol /set /subcategory:"Certification Services" /success:enable /failure:enable'; DCOnly=$false; Label='Certification Services'},

    # File auditing:
    @{Cmd='auditpol /set /subcategory:"Detailed File Share" /success:enable /failure:enable'; DCOnly=$false; Label='Detailed File Share'},
    @{Cmd='auditpol /set /subcategory:"File Share" /success:enable /failure:enable'; DCOnly=$false; Label='File Share'},
    @{Cmd='auditpol /set /subcategory:"File System" /success:enable /failure:enable'; DCOnly=$false; Label='File System'},

    @{Cmd='auditpol /set /subcategory:"Filtering Platform Connection" /success:enable /failure:disable'; DCOnly=$false; Label='Filtering Platform Connection'},
    @{Cmd='auditpol /set /subcategory:"Filtering Platform Packet Drop" /success:disable /failure:disable'; DCOnly=$false; Label='Filtering Platform Packet Drop'},
    @{Cmd='auditpol /set /subcategory:"Handle Manipulation" /success:disable /failure:disable'; DCOnly=$false; Label='Handle Manipulation'},
    @{Cmd='auditpol /set /subcategory:"Kernel Object" /success:enable /failure:enable'; DCOnly=$false; Label='Kernel Object'},
    @{Cmd='auditpol /set /subcategory:"Other Object Access Events" /success:disable /failure:disable'; DCOnly=$false; Label='Other Object Access Events'},
    @{Cmd='auditpol /set /subcategory:"Registry" /success:enable /failure:disable'; DCOnly=$false; Label='Registry'},
    @{Cmd='auditpol /set /subcategory:"Removable Storage" /success:enable /failure:enable'; DCOnly=$false; Label='Removable Storage'},
    @{Cmd='auditpol /set /subcategory:"SAM" /success:enable /failure:disable'; DCOnly=$false; Label='SAM'},
    @{Cmd='auditpol /set /subcategory:"Central Policy Staging" /success:disable /failure:disable'; DCOnly=$false; Label='Central Policy Staging'},
    @{Cmd='auditpol /set /subcategory:"Audit Policy Change" /success:enable /failure:enable'; DCOnly=$false; Label='Audit Policy Change'},
    @{Cmd='auditpol /set /subcategory:"Authentication Policy Change" /success:enable /failure:enable'; DCOnly=$false; Label='Authentication Policy Change'},
    @{Cmd='auditpol /set /subcategory:"Authorization Policy Change" /success:enable /failure:enable'; DCOnly=$false; Label='Authorization Policy Change'},
    @{Cmd='auditpol /set /subcategory:"Filtering Platform Policy Change" /success:enable /failure:disable'; DCOnly=$false; Label='Filtering Platform Policy Change'},
    @{Cmd='auditpol /set /subcategory:"MPSSVC Rule-Level Policy Change" /success:disable /failure:disable'; DCOnly=$false; Label='MPSSVC Rule-Level Policy Change'},
    @{Cmd='auditpol /set /subcategory:"Other Policy Change Events" /success:disable /failure:disable'; DCOnly=$false; Label='Other Policy Change Events'},
    @{Cmd='auditpol /set /subcategory:"Non Sensitive Privilege Use" /success:disable /failure:disable'; DCOnly=$false; Label='Non Sensitive Privilege Use'},
    @{Cmd='auditpol /set /subcategory:"Other Privilege Use Events" /success:disable /failure:disable'; DCOnly=$false; Label='Other Privilege Use Events'},
    @{Cmd='auditpol /set /subcategory:"Sensitive Privilege Use" /success:enable /failure:enable'; DCOnly=$false; Label='Sensitive Privilege Use'},
    @{Cmd='auditpol /set /subcategory:"IPsec Driver" /success:enable /failure:disable'; DCOnly=$false; Label='IPsec Driver'},
    @{Cmd='auditpol /set /subcategory:"Other System Events" /success:disable /failure:enable'; DCOnly=$false; Label='Other System Events'},
    @{Cmd='auditpol /set /subcategory:"Security State Change" /success:enable /failure:enable'; DCOnly=$false; Label='Security State Change'},
    @{Cmd='auditpol /set /subcategory:"Security System Extension" /success:enable /failure:enable'; DCOnly=$false; Label='Security System Extension'},
    @{Cmd='auditpol /set /subcategory:"System Integrity" /success:enable /failure:enable'; DCOnly=$false; Label='System Integrity'},
    @{Cmd='auditpol /set /subcategory:"Access Rights" /success:enable /failure:disable'; DCOnly=$false; Label='Access Rights'}
)

# ---------- Execution loop ----------
$counts = @{Success=0; Failed=0; Skipped=0}
foreach ($entry in $commands) {
    $cmd = $entry.Cmd
    $label = $entry.Label
    $dcOnly = $entry.DCOnly

    $now = (Get-Date).ToString('o')
    Write-Host "`nRunning: $label" -ForegroundColor Cyan
    Write-Host "Command: $cmd" -ForegroundColor DarkCyan

    if ($dcOnly -and -not $IsDC) {
        $msg = "SKIPPED - DC-only policy; machine is not a Domain Controller"
        Write-Host $msg -ForegroundColor Yellow
        $csvLine = "$now,$env:COMPUTERNAME,$label,Yes,No,SKIPPED,$msg"
        $csvLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
        $counts.Skipped++
        continue
    }

    try {
        $raw = cmd.exe /c $cmd 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $msg = "SUCCESS"
            Write-Host $msg -ForegroundColor Green
            $csvLine = "$now,$env:COMPUTERNAME,$label,No,Yes,SUCCESS,$($raw -join ' | ')"
            $csvLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
            $counts.Success++
        } else {
            $msg = "FAILED - ExitCode $LASTEXITCODE"
            Write-Host "$msg`n$raw" -ForegroundColor Red
            $csvLine = "$now,$env:COMPUTERNAME,$label,No,Yes,FAILED,$($raw -join ' | ')"
            $csvLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
            $counts.Failed++
        }
    } catch {
        $err = $_.Exception.Message
        Write-Host "EXCEPTION: $err" -ForegroundColor Red
        $csvLine = "$now,$env:COMPUTERNAME,$label,$($dcOnly -as [string]),Yes,EXCEPTION,$err"
        $csvLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
        $counts.Failed++
    }
}

Start-Sleep -Seconds 2
  if (Test-Path $backupPathAfter) {
      Remove-Item $backupPathAfter -Force
  }
    auditpol /backup /file:$backupPathAfter


# ---------- Open Local Security Policy GUI for CSV import ----------
Write-Host "`nOpening Local Security Policy (secpol.msc)..." -ForegroundColor Yellow
Start-Process "secpol.msc"
Write-Host "Please import the CSV file saved on your Desktop to make the audit policies appear in the GUI." -ForegroundColor Yellow


# ---------- Summary ----------
Write-Host "`n========== Summary ==========" -ForegroundColor Yellow
Write-Host "Success: $($counts.Success)    Failed: $($counts.Failed)    Skipped: $($counts.Skipped)" -ForegroundColor Yellow
Write-Host "CSV log saved to: $LogFile" -ForegroundColor Yellow  
