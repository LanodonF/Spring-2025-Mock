
Write-output "+----------------+"
Write-Output " Disabling AD GPO"
Write-Output "+----------------+"


$GPOs = get-gpo -ALL

foreach ($GPO in $GPOs) {
    $GPO.GpoStatus = "AllSettingsDisabled"
    Write-Output "GPO $($GPO.DisplayName) status set to AllSettingsDisabled"
}
