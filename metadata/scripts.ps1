if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$ComponentData = [Component]::new("scripts", [Availability]::Ignored)
$ComponentData.FriendlyName = "Dotfiles scripts"

return $ComponentData
