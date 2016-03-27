if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$Component = [Component]::new("posh", [Availability]::AlwaysInstall)
$Component.FriendlyName = "Windows PowerShell"

return $Component
