#Requires -RunAsAdministrator
# Installs OpenSSH Server, starts it, and opens TCP 22 to Hamachi (25.0.0.0/8) only.
 
$ErrorActionPreference = 'Stop'
 
# 1. Install OpenSSH Server if it isn't already
$cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*'
if ($cap.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' | Out-Null
}
 
# 2. Start on boot and start now
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd
 
# 3. Firewall rule: port 22, Hamachi range only (replace 25.0.0.0/8 with a single 25.x.x.x IP to lock it to one person)
Remove-NetFirewallRule -Name 'sshd-hamachi' -ErrorAction SilentlyContinue
New-NetFirewallRule -Name 'sshd-hamachi' -DisplayName 'SSH via Hamachi' `
    -Direction Inbound -Protocol TCP -LocalPort 22 `
    -RemoteAddress 25.0.0.0/8 -Action Allow -Profile Any | Out-Null
 
# 4. Optional: make PowerShell the default SSH shell (comment out to keep cmd)
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
    -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
    -PropertyType String -Force | Out-Null
 
# 5. Show result
Get-Service sshd | Select-Object Name, Status, StartType
Write-Host "SSH ready on port 22 (Hamachi only)." -ForegroundColor Green
 
