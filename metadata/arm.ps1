if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$Component = [Component]::new("arm", [Availability]::Ignored)
$Component.FriendlyName = "Anonymizing Relay Monitor"

return $Component
