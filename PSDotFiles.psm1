Function Get-DotFiles {
    <#
        .SYNOPSIS
        Enumerates the available dotfiles components
        .DESCRIPTION
        .PARAMETER Path
        Use the specified directory as the dotfiles directory instead of $DotFilesPath.
        .EXAMPLE
        .INPUTS
        .OUTPUTS
        .NOTES
        .LINK
        https://github.com/ralish/PSDotFiles
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=1,Mandatory=$false)]
            [String]$Path
    )

    Get-DotFilesSettings

    $Components = Get-ChildItem -Path $script:DotFilesPath -Directory
    foreach ($Component in $Components) {
        Get-DotFilesComponent -Component $Component
    }
}

Function Install-DotFiles {
    <#
        .SYNOPSIS
        Installs the selected dotfiles components
        .DESCRIPTION
        .PARAMETER Path
        Use the specified directory as the dotfiles directory instead of $DotFilesPath.
        .EXAMPLE
        .INPUTS
        .OUTPUTS
        .NOTES
        .LINK
        https://github.com/ralish/PSDotFiles
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=1,Mandatory=$false)]
            [String]$Path
    )

    Get-DotFilesSettings
}

Function Remove-DotFiles {
    <#
        .SYNOPSIS
        Removes the selected dotfiles components
        .DESCRIPTION
        .PARAMETER Path
        Use the specified directory as the dotfiles directory instead of $DotFilesPath.
        .EXAMPLE
        .INPUTS
        .OUTPUTS
        .NOTES
        .LINK
        https://github.com/ralish/PSDotFiles
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=1,Mandatory=$false)]
            [String]$Path
    )

    Get-DotFilesSettings
}

Function Get-DotFilesComponent {
    Param(
        [Parameter(Mandatory=$true)]
            [System.IO.DirectoryInfo]$Component
    )

    $Name         = $Component.Name
    $ScriptName   = $Name + ".ps1"
    $ScriptPath   = Join-Path $script:DotFilesMetadataPath $ScriptName

    $Description  = ""
    $Availability = "No Logic"
    $Installed    = "Unknown"

    if (Test-Path -Path $ScriptPath -PathType Leaf) {
        . $ScriptPath

        if (Test-Path Function:\Test-DotFilesComponent) {
            $Availability = Test-DotFilesComponent
        }
    }

    return [PSCustomObject]@{
        Name         = $Name
        Description  = $Description
        Availability = $Availability
        Installed    = $Installed
    }
}

Function Get-DotFilesSettings {
    if ($Path) {
        $script:DotFilesPath = Test-DotFilesPath -Path $Path
        if (!$script:DotFilesPath) {
            throw "The provided dotfiles path is either not a directory or it can't be accessed."
        }
    } elseif ($global:DotFilesPath) {
        $script:DotFilesPath = Test-DotFilesPath -Path $global:DotFilesPath
        if (!$script:DotFilesPath) {
            throw "The default dotfiles path (`$DotFilesPath) is either not a directory or it can't be accessed."
        }
    } else {
        throw "No dotfiles path was provided and the default dotfiles path (`$DotFilesPath) has not been configured."
    }
    Write-Debug "Using dotfiles directory: $script:DotFilesPath"

    $script:DotFilesMetadataPath = Join-Path $script:DotFilesPath "metadata"
    Write-Debug "Using metadata directory: $script:DotFilesMetadataPath"
}

Function Test-DotFilesPath {
    Param(
        [Parameter(Mandatory=$true)]
            [String]$Path
    )

    if (Test-Path -Path $Path) {
        $PathItem = Get-Item -Path $Path
        if ($PathItem -is [System.IO.DirectoryInfo]) {
            return $PathItem.FullName
        }
    }
    return $false
}
