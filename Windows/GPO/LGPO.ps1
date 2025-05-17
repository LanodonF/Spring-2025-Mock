Get-ChildItem "$PSScriptRoot\DOD-Policies" | ForEach-Object {
    $name = $_.Name
    & "$PSScriptRoot\LGPO.exe" /g "$PSScriptRoot\DOD-Policies\$name"
}

net accounts /lockoutthreshold:5

gpupdate
