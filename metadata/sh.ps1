if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$Component = [Component]::new("sh", [Availability]::NeverInstall)
$Component.FriendlyName = "Bourne shell"

return $Component
