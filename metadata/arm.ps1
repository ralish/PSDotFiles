if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$ComponentData = [Component]::new("arm", [Availability]::Ignored)
$ComponentData.FriendlyName = "Anonymizing Relay Monitor"

return $ComponentData
