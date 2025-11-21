
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

# ---------- Define commands and mark DC-only where necessary ----------
# Each item is hashtable: @{ Cmd = '...'; DCOnly = $true|$false; Label = 'Friendly name' }
$commands = @(
    @{Cmd='auditpol /set /subcategory:"Validación de credenciales" /success:enable /failure:enable'; DCOnly=$false; Label='Validación de credenciales'},
    @{Cmd='auditpol /set /subcategory:"Servicio de autenticación Kerberos" /success:disable /failure:disable'; DCOnly=$false; Label='Servicio de autenticación Kerberos'},
    @{Cmd='auditpol /set /subcategory:"Operaciones de vales de servicio Kerberos" /success:disable /failure:disable'; DCOnly=$false; Label='Operaciones de vales de servicio Kerberos'},
    @{Cmd='auditpol /set /subcategory:"Otros eventos de inicio de sesión de cuentas" /success:enable /failure:enable'; DCOnly=$false; Label='Otros eventos de inicio de sesión de cuentas'},
    @{Cmd='auditpol /set /subcategory:"Administración de grupos de aplicaciones" /success:enable /failure:enable'; DCOnly=$false; Label='Administración de grupos de aplicaciones'},
    @{Cmd='auditpol /set /subcategory:"Administración de cuentas de equipo" /success:enable /failure:enable'; DCOnly=$false; Label='Administración de cuentas de equipo'},
    @{Cmd='auditpol /set /subcategory:"Administración de grupos de distribución" /success:enable /failure:enable'; DCOnly=$false; Label='Administración de grupos de distribución'},
    @{Cmd='auditpol /set /subcategory:"Otros eventos de administración de cuentas" /success:enable /failure:enable'; DCOnly=$false; Label='Otros eventos de administración de cuentas'},
    @{Cmd='auditpol /set /subcategory:"Administración de grupos de seguridad" /success:enable /failure:enable'; DCOnly=$false; Label='Administración de grupos de seguridad'},
    @{Cmd='auditpol /set /subcategory:"Administración de cuentas de usuario" /success:enable /failure:enable'; DCOnly=$false; Label='Administración de cuentas de usuario'},

    @{Cmd='auditpol /set /subcategory:"Actividad DPAPI" /success:disable /failure:disable'; DCOnly=$false; Label='Actividad DPAPI'},
    @{Cmd='auditpol /set /subcategory:"Eventos Plug and Play" /success:enable /failure:disable'; DCOnly=$false; Label='Eventos Plug and Play'},
    @{Cmd='auditpol /set /subcategory:"Creación del proceso" /success:enable /failure:enable'; DCOnly=$false; Label='Creación del proceso'},
    @{Cmd='auditpol /set /subcategory:"Finalización del proceso" /success:enable /failure:enable'; DCOnly=$false; Label='Finalización del proceso'},
    @{Cmd='auditpol /set /subcategory:"Eventos de RPC" /success:enable /failure:enable'; DCOnly=$false; Label='Eventos de RPC'},
    @{Cmd='auditpol /set /subcategory:"Eventos de ajuste de derecho de token" /success:enable /failure:disable'; DCOnly=$false; Label='Eventos de ajuste de derecho de token'},

    @{Cmd='auditpol /set /subcategory:"Replicación de servicio de directorio detallada" /success:disable /failure:disable'; DCOnly=$true; Label='Replicación de servicio de directorio detallada'},
    @{Cmd='auditpol /set /subcategory:"Acceso del servicio de directorio" /success:disable /failure:disable'; DCOnly=$false; Label='Acceso del servicio de directorio'},
    @{Cmd='auditpol /set /subcategory:"Cambios de servicio de directorio" /success:enable /failure:enable'; DCOnly=$false; Label='Cambios de servicio de directorio'},
    @{Cmd='auditpol /set /subcategory:"Replicación de servicio de directorio" /success:enable /failure:disable'; DCOnly=$true; Label='Replicación de servicio de directorio'},

    @{Cmd='auditpol /set /subcategory:"Bloqueo de cuenta" /success:enable /failure:disable'; DCOnly=$false; Label='Bloqueo de cuenta'},
    @{Cmd='auditpol /set /subcategory:"Notificaciones de usuario o dispositivo" /success:disable /failure:disable'; DCOnly=$false; Label='Notificaciones de usuario o dispositivo'},
    @{Cmd='auditpol /set /subcategory:"Pertenencia a grupos" /success:enable /failure:disable'; DCOnly=$false; Label='Pertenencia a grupos'},
    @{Cmd='auditpol /set /subcategory:"Modo extendido de IPSec" /success:disable /failure:disable'; DCOnly=$false; Label='Modo extendido de IPSec'},
    @{Cmd='auditpol /set /subcategory:"Modo principal de IPSec" /success:disable /failure:disable'; DCOnly=$false; Label='Modo principal de IPSec'},
    @{Cmd='auditpol /set /subcategory:"Modo rápido de IPSec" /success:disable /failure:disable'; DCOnly=$false; Label='Modo rápido de IPSec'},

    @{Cmd='auditpol /set /subcategory:"Cerrar sesión" /success:enable /failure:disable'; DCOnly=$false; Label='Cerrar sesión'},
    @{Cmd='auditpol /set /subcategory:"Inicio de sesión" /success:enable /failure:enable'; DCOnly=$false; Label='Inicio de sesión'},
    @{Cmd='auditpol /set /subcategory:"Servidor de directivas de redes" /success:enable /failure:enable'; DCOnly=$false; Label='Servidor de directivas de redes'},
    @{Cmd='auditpol /set /subcategory:"Otros eventos de inicio y cierre de sesión" /success:enable /failure:enable'; DCOnly=$false; Label='Otros eventos de inicio y cierre de sesión'},
    @{Cmd='auditpol /set /subcategory:"Inicio de sesión especial" /success:enable /failure:enable'; DCOnly=$false; Label='Inicio de sesión especial'},

    @{Cmd='auditpol /set /subcategory:"Aplicación generada" /success:enable /failure:enable'; DCOnly=$false; Label='Aplicación generada'},
    @{Cmd='auditpol /set /subcategory:"Servicios de certificación" /success:enable /failure:enable'; DCOnly=$false; Label='Servicios de certificación'},

    @{Cmd='auditpol /set /subcategory:"Recurso compartido de archivos detallado" /success:enable /failure:enable'; DCOnly=$false; Label='Recurso compartido de archivos detallado'},
    @{Cmd='auditpol /set /subcategory:"Recurso compartido de archivos" /success:enable /failure:enable'; DCOnly=$false; Label='Recurso compartido de archivos'},
    @{Cmd='auditpol /set /subcategory:"Sistema de archivos" /success:enable /failure:enable'; DCOnly=$false; Label='Sistema de archivos'},

    @{Cmd='auditpol /set /subcategory:"Conexión de plataforma de filtrado" /success:enable /failure:disable'; DCOnly=$false; Label='Conexión de plataforma de filtrado'},
    @{Cmd='auditpol /set /subcategory:"Colocación de paquetes de plataforma de filtrado" /success:disable /failure:disable'; DCOnly=$false; Label='Colocación de paquetes de plataforma de filtrado'},
    @{Cmd='auditpol /set /subcategory:"Manipulación de identificadores" /success:disable /failure:disable'; DCOnly=$false; Label='Manipulación de identificadores'},
    @{Cmd='auditpol /set /subcategory:"Objeto de kernel" /success:enable /failure:enable'; DCOnly=$false; Label='Objeto de kernel'},
    @{Cmd='auditpol /set /subcategory:"Otros eventos de acceso a objetos" /success:disable /failure:disable'; DCOnly=$false; Label='Otros eventos de acceso a objetos'},
    @{Cmd='auditpol /set /subcategory:"Registro" /success:enable /failure:disable'; DCOnly=$false; Label='Registro'},
    @{Cmd='auditpol /set /subcategory:"Almacenamiento extraíble" /success:enable /failure:enable'; DCOnly=$false; Label='Almacenamiento extraíble'},
    @{Cmd='auditpol /set /subcategory:"SAM" /success:enable /failure:disable'; DCOnly=$false; Label='SAM'},
    @{Cmd='auditpol /set /subcategory:"Almacenamiento provisional de directiva central" /success:disable /failure:disable'; DCOnly=$false; Label='Almacenamiento provisional de directiva central'},

    @{Cmd='auditpol /set /subcategory:"Cambio en la directiva de auditoría" /success:enable /failure:enable'; DCOnly=$false; Label='Cambio en la directiva de auditoría'},
    @{Cmd='auditpol /set /subcategory:"Cambio de la directiva de autenticación" /success:enable /failure:enable'; DCOnly=$false; Label='Cambio de la directiva de autenticación'},
    @{Cmd='auditpol /set /subcategory:"Cambio de la directiva de autorización" /success:enable /failure:enable'; DCOnly=$false; Label='Cambio de la directiva de autorización'},
    @{Cmd='auditpol /set /subcategory:"Cambio de la directiva de plataforma de filtrado" /success:enable /failure:disable'; DCOnly=$false; Label='Cambio de la directiva de plataforma de filtrado'},
    @{Cmd='auditpol /set /subcategory:"Cambio de la directiva del nivel de reglas de MPSSVC" /success:disable /failure:disable'; DCOnly=$false; Label='Cambio de la directiva del nivel de reglas de MPSSVC'},
    @{Cmd='auditpol /set /subcategory:"Otros eventos de cambio de directivas" /success:disable /failure:disable'; DCOnly=$false; Label='Otros eventos de cambio de directivas'},

    @{Cmd='auditpol /set /subcategory:"Uso de privilegio no confidencial" /success:disable /failure:disable'; DCOnly=$false; Label='Uso de privilegio no confidencial'},
    @{Cmd='auditpol /set /subcategory:"Otros eventos de uso de privilegio" /success:disable /failure:disable'; DCOnly=$false; Label='Otros eventos de uso de privilegio'},
    @{Cmd='auditpol /set /subcategory:"Uso de privilegio confidencial" /success:enable /failure:enable'; DCOnly=$false; Label='Uso de privilegio confidencial'},

    @{Cmd='auditpol /set /subcategory:"Controlador IPSec" /success:enable /failure:disable'; DCOnly=$false; Label='Controlador IPSec'},
    @{Cmd='auditpol /set /subcategory:"Otros eventos de sistema" /success:disable /failure:enable'; DCOnly=$false; Label='Otros eventos de sistema'},
    @{Cmd='auditpol /set /subcategory:"Cambio de estado de seguridad" /success:enable /failure:enable'; DCOnly=$false; Label='Cambio de estado de seguridad'},
    @{Cmd='auditpol /set /subcategory:"Extensión del sistema de seguridad" /success:enable /failure:enable'; DCOnly=$false; Label='Extensión del sistema de seguridad'},
    @{Cmd='auditpol /set /subcategory:"Integridad del sistema" /success:enable /failure:enable'; DCOnly=$false; Label='Integridad del sistema'},
    @{Cmd='auditpol /set /subcategory:"Derechos de acceso" /success:enable /failure:disable'; DCOnly=$false; Label='Derechos de acceso'}
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
        # Run through cmd.exe to use the auditpol executable exactly as expected
        $raw = cmd.exe /c $cmd 2>&1
        # PowerShell marshals cmd.exe return code to $LASTEXITCODE
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
