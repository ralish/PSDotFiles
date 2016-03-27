if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$ComponentData = [Component]::new("posh", [Availability]::AlwaysInstall)
$ComponentData.FriendlyName = "Windows PowerShell"

return $ComponentData
