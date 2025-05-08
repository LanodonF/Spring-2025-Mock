# TODO:
# - A lot
# - AD DC stuff


# Get IP, Subnet, Gateway, DNS, MAC
Write-Output "Run under $(whoami)"
write-output "Current Date and Time: $(Get-Date)"
Write-Output ""

# Hostname and Domain
Write-Output "=== Hostname and Domain ==="
Write-Output "Hostname: $env:COMPUTERNAME"
Write-Output "Domain: $env:USERDOMAIN"
Write-Output ""

# Network Information
Write-Output "=== Network Information ==="
Get-NetIPConfiguration | ForEach-Object {
    Write-Output "Interface: $($_.InterfaceAlias)"
    Write-Output "  IPv4 Address: $($_.IPv4Address.IPAddress)"
    Write-Output "  Subnet Mask: $($_.IPv4Address.PrefixLength)"
    Write-Output "  Default Gateway: $($_.IPv4DefaultGateway.NextHop)"
    Write-Output "  DNS Servers: $($_.DNSServer.ServerAddresses -join ', ')"
    Write-Output "  MAC Address: $($_.NetAdapter.MacAddress)"
    Write-Output ""
}

# TCP and UDP Connections
Write-Output "=== TCP Connections ==="
Get-NetTCPConnection | ForEach-Object {
    $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        LocalAddress  = $_.LocalAddress
        LocalPort     = $_.LocalPort
        RemoteAddress = $_.RemoteAddress
        RemotePort    = $_.RemotePort
        State         = $_.State
        ProcessId     = $_.OwningProcess
        ProcessName   = $proc.ProcessName
    }
} | Format-Table -AutoSize
Write-Output ""
Write-Output "=== UDP Connections ==="
Get-NetUDPEndpoint | ForEach-Object {
    $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        LocalAddress  = $_.LocalAddress
        LocalPort     = $_.LocalPort
        RemoteAddress = $_.RemoteAddress
        RemotePort    = $_.RemotePort
        ProcessId     = $_.OwningProcess
        ProcessName   = $proc.ProcessName
    }
} | Format-Table -AutoSize
Write-Output ""

# Users and Groups
Write-Output "=== Local Users ==="
Get-LocalUser | Format-Table -AutoSize
Write-Output ""

Write-Output "=== Local Groups ==="
Get-LocalGroup | ForEach-Object {
    Write-Output "Group: $($_.Name)"
    $members = Get-LocalGroupMember -Group $_.Name
    try {
        $members | ForEach-Object {
            Write-Output("    Name: $($_.Name)")
        }
    } catch {
    }
}

# Installed Applications
Write-Output "=== Installed Applications ==="
Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Format-Table -AutoSize
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Format-Table -AutoSize
Write-Output ""

# Optional Features
Write-Output "=== Optional Features ==="
Get-WindowsOptionalFeature -Online | Where-Object {$_.State -eq "Enabled"} | Format-Table -AutoSize
Write-Output ""
