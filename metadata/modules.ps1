if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$ComponentData = [Component]::new("modules", [Availability]::NeverInstall)
$ComponentData.FriendlyName = "Dotfiles modules"

return $ComponentData
