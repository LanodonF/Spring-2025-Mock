param(
    [string]$AllowedIPs = "" # Comma-separated list of local computer IPs
)

# Backup current firewall configuration
netsh advfirewall export "C:\FirewallBackup.wfw"

# Turn off firewall to clear rules safely
netsh advfirewall set allprofiles state off

# Block all inbound and outbound by default
netsh advfirewall set allprofiles firewallpolicy blockinbound,blockoutbound

# Delete all existing rules
netsh advfirewall firewall delete rule name=all

# Allow all traffic to/from each local IP
$ipList = $AllowedIPs -split ","
foreach ($ip in $ipList) {
    netsh advfirewall firewall add rule name="Allow Local Inbound $ip" dir=in action=allow protocol=any remoteip=$ip
    netsh advfirewall firewall add rule name="Allow Local Outbound $ip" dir=out action=allow protocol=any remoteip=$ip
}

# Turn firewall back on
netsh advfirewall set allprofiles state on

Write-Host "traffic to/from these IPs is allowed: $AllowedIPs."
Write-Host "To restore the original firewall configuration, run:"
Write-Host "netsh advfirewall import 'C:\FirewallBackup.wfw'"
