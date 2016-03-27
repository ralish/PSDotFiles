if(!$script:PSDotFiles) {
    . (Join-Path $PSScriptRoot 'templates\common.ps1')
}

$Component = Find-DotFilesComponent -Name "git" -Pattern "^Git " -CaseSensitive -RegularExpression
$Component.FriendlyName = "Git"

return $Component
