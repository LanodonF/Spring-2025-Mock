$NewPassword = Read-Host "Enter the new password" -AsSecureString

function Is-DomainController {
    $role = (Get-WmiObject Win32_ComputerSystem).DomainRole
    return ($role -eq 4 -or $role -eq 5)
}

# Always attempt to change local user passwords (if any)
$localUsers = Get-LocalUser | Where-Object { $_.Enabled -eq $true -and $_.Name -notin @('Administrator','Guest','DefaultAccount','WDAGUtilityAccount') }
foreach ($user in $localUsers) {
    try {
        $user | Set-LocalUser -Password $NewPassword
        Write-Host "Local password for $($user.Name) changed successfully."
    } catch {
        Write-Error "Failed to change local password for $($user.Name)."
    }
}

# If Domain Controller, also change domain user passwords
if (Is-DomainController) {
    Import-Module ActiveDirectory
    $users = Get-ADUser -Filter {Enabled -eq $true} -Properties SamAccountName
    foreach ($user in $users) {
        if ($user.SamAccountName -eq 'krbtgt') { continue }
        if ($user.SamAccountName -like 'black_team') { continue }
        try {
            Set-ADAccountPassword -Identity $user.SamAccountName -NewPassword $NewPassword -Reset
            Write-Host "Domain password for $($user.SamAccountName) changed successfully."
        } catch {
            Write-Error "Failed to change domain password for $($user.SamAccountName)."
        }
    }
}
