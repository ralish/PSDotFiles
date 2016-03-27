if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$Component = [Component]::new("modules", [Availability]::NeverInstall)
$Component.FriendlyName = "Dotfiles modules"

return $Component
