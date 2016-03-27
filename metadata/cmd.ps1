if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$Component = [Component]::new("cmd", [Availability]::AlwaysInstall)
$Component.FriendlyName = "Command Prompt"

return $Component
