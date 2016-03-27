if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$ComponentData = [Component]::new("sh", [Availability]::NeverInstall)
$ComponentData.FriendlyName = "Bourne shell"

return $ComponentData
