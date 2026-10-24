# ssh-host.ps1  (iex-friendly)
# Meant to be run by the launcher one-liner, which starts it hidden and elevated:
#   irm https://YOUR-URL/ssh-host.ps1 | iex
# Assumes it is ALREADY running as Administrator.
# Output goes to files, since there is no window:
#   C:\Users\Public\Desktop\ssh-info.txt   (username + Hamachi IP + connect command)
#   C:\ProgramData\ssh-setup.log           (detailed log / errors)

$ErrorActionPreference = 'Stop'
$logFile    = Join-Path $env:ProgramData 'ssh-setup.log'
$infoFile   = 'C:\Users\Public\Desktop\ssh-info.txt'
$targetUser = if ($env:SSH_TARGET_USER) { $env:SSH_TARGET_USER } else { $env:USERNAME }

function Write-SshLog($msg) {
    Add-Content -Path $logFile -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg)
}

try {
    Write-SshLog '--- Starting setup ---'

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { throw 'Not running as Administrator. Use the launcher one-liner.' }

    # 1. Install OpenSSH Server if missing
    $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*'
    if ($cap.State -ne 'Installed') {
        Write-SshLog 'Installing OpenSSH Server...'
        Add-WindowsCapability -Online -Name $cap.Name | Out-Null
        Write-SshLog 'Installed.'
    } else {
        Write-SshLog 'OpenSSH Server already installed.'
    }

    # 2. Start now + start automatically on boot
    Set-Service -Name sshd -StartupType Automatic
    if ((Get-Service sshd).Status -ne 'Running') { Start-Service sshd }
    Write-SshLog 'sshd running, startup type Automatic.'

    # 3. Firewall: only allow SSH from the Hamachi range
    Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue |
        Disable-NetFirewallRule

    $ruleName = 'OpenSSH-Hamachi-Only'
    if (-not (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name $ruleName `
            -DisplayName 'OpenSSH Server (Hamachi only)' `
            -Direction Inbound -Protocol TCP -LocalPort 22 `
            -RemoteAddress 25.0.0.0/8 `
            -Action Allow -Profile Any | Out-Null
    }
    Write-SshLog 'Firewall: port 22 allowed from 25.0.0.0/8 only.'

    # 4. Write connection info
    $hamachi = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -like '25.*' } |
        Select-Object -ExpandProperty IPAddress -First 1

    $lines = @('SSH host setup completed.', '', "Windows username : $targetUser")
    if ($hamachi) {
        $lines += "Hamachi IP       : $hamachi"
        $lines += "Connect with     : ssh $targetUser@$hamachi"
    } else {
        $lines += 'Hamachi IP       : NOT FOUND (start Hamachi, then check its 25.x.x.x address)'
    }
    $lines += ''
    $lines += 'The account must have a password set to log in.'
    $lines += 'You can delete this file once you have noted the details.'
    Set-Content -Path $infoFile -Value $lines
    Write-SshLog 'Setup complete. Info file written.'
}
catch {
    Write-SshLog ("ERROR: " + $_.Exception.Message)
    try {
        Set-Content -Path $infoFile -Value @(
            'SSH host setup FAILED.',
            "Error: $($_.Exception.Message)",
            "See log: $logFile"
        )
    } catch { }
}
