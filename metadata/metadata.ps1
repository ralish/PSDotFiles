if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$ComponentData = [Component]::new("metadata", [Availability]::NeverInstall)
$ComponentData.FriendlyName = "Dotfiles metadata"

return $ComponentData
