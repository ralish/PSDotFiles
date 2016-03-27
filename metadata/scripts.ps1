if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$Component = [Component]::new("scripts", [Availability]::Ignored)
$Component.FriendlyName = "Dotfiles scripts"

return $Component
