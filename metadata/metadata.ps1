if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$Component = [Component]::new("metadata", [Availability]::NeverInstall)
$Component.FriendlyName = "Dotfiles metadata"

return $Component
