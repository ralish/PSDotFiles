if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$ComponentData = [Component]::new("cmd", [Availability]::AlwaysInstall)
$ComponentData.FriendlyName = "Command Prompt"

return $ComponentData
