Function Get-DotFiles {
    <#
        .SYNOPSIS
        Enumerates the available dotfiles components
        .DESCRIPTION
        .PARAMETER Autodetect
        Toggles automatic detection of enumerated components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled ($false).
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Summary
        Return the results of the detection in summary form.
        .EXAMPLE
        .INPUTS
        .OUTPUTS
        .NOTES
        .LINK
        https://github.com/ralish/PSDotFiles
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(Mandatory=$false)]
            [Switch]$Autodetect,
        [Parameter(Mandatory=$false)]
            [Switch]$Summary
    )

    Initialize-PSDotFiles @PSBoundParameters

    $DotFiles = Get-ChildItem -Path $script:DotFilesPath -Directory
    $Components = @()
    foreach ($Component in $DotFiles) {
        $Components += Get-DotFilesComponent -Directory $Component
    }

    if ($Summary) {
        $ComponentSummary = [PSCustomObject]@{
            Available = @()
            Unavailable = @()
            Ignored = @()
            AlwaysInstall = @()
            NeverInstall = @()
            DetectionFailure = @()
            NoLogic = @()
        }

        foreach ($Component in $Components) {
            switch ($Component.Availability) {
                "Available"             { $ComponentSummary.Available += $Component }
                "Unavailable"           { $ComponentSummary.Unavailable += $Component }
                "Ignored"               { $ComponentSummary.Ignored += $Component }
                "AlwaysInstall"         { $ComponentSummary.AlwaysInstall += $Component }
                "NeverInstall"          { $ComponentSummary.NeverInstall += $Component }
                "DetectionFailure"      { $ComponentSummary.DetectionFailure += $Component }
                "NoLogic"               { $ComponentSummary.NoLogic += $Component }
                default                 { Write-Error ("Unknown availability state `"" + $Component.Availability + "`" in component: " + $Component.Name) }
            }
        }

        return $ComponentSummary
    } else {
        return $Components
    }
}

Function Install-DotFiles {
    <#
        .SYNOPSIS
        Installs the selected dotfiles components
        .DESCRIPTION
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of enumerated components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled ($false).
        .EXAMPLE
        .INPUTS
        .OUTPUTS
        .NOTES
        .LINK
        https://github.com/ralish/PSDotFiles
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(Mandatory=$false)]
            [Switch]$Autodetect
    )

    Initialize-PSDotFiles @PSBoundParameters
}

Function Remove-DotFiles {
    <#
        .SYNOPSIS
        Removes the selected dotfiles components
        .DESCRIPTION
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of enumerated components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled ($false).
        .EXAMPLE
        .INPUTS
        .OUTPUTS
        .NOTES
        .LINK
        https://github.com/ralish/PSDotFiles
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(Mandatory=$false)]
            [Switch]$Autodetect
    )

    Initialize-PSDotFiles @PSBoundParameters
}

Function Initialize-PSDotFiles {
    # This function is intentionally *not* an advanced function so that unknown
    # parameters passed into it via @PSBoundParameters won't cause it to fail.
    # Do not insert a CmdletBinding() or any Parameter[] attributes or it will
    # be designated an advanced function (implicitly in the latter case). The
    # only alternative is to explicitly define all possible parameters which
    # could be passed into this function via @PSBoundParameters, most of which
    # won't ever actually be used here.
    Param(
        [Switch]$Autodetect,
        [String]$Path
    )

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
    Write-Verbose "Using dotfiles directory: $script:DotFilesPath"

    $script:DotFilesMetadataPath = Join-Path $script:DotFilesPath "metadata"
    Write-Debug "Using dotfiles metadata directory: $script:DotFilesMetadataPath"

    if ($PSBoundParameters.ContainsKey("Autodetect")) {
        $script:DotFilesAutodetect = $Autodetect
    } elseif (Get-Variable -Name DotFilesAutodetect -Scope Global -ErrorAction SilentlyContinue | Out-Null) {
        $script:DotFilesAutodetect = $global:DotFilesAutodetect
    } else {
        $script:DotFilesAutodetect = $false
    }
    Write-Debug "Automatic component detection state: $script:DotFilesAutodetect"

    $script:InstalledPrograms = Get-InstalledPrograms
    Write-Debug "Refreshing cache of installed programs..."
}

Function Get-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.IO.DirectoryInfo]$Directory
    )

    $Name             = $Directory.Name
    $ScriptName       = $Name + ".ps1"
    $GlobalScriptPath = Join-Path $script:GlobalMetadataPath $ScriptName
    $CustomScriptPath = Join-Path $script:DotFilesMetadataPath $ScriptName

    if (Test-Path -Path $CustomScriptPath -PathType Leaf) {
        Write-Debug "Loading custom metadata for component: $Name"
        $Component = . $CustomScriptPath
    } elseif (Test-Path -Path $GlobalScriptPath -PathType Leaf) {
        Write-Debug "Loading global metadata for component: $Name"
        $Component = . $GlobalScriptPath
    } elseif ($script:DotFilesAutodetect) {
        Write-Debug "Running automatic detection for component: $Name"
        $Component = Find-DotFilesComponent -Name $Name
    } else {
        Write-Debug "No metadata & automatic detection disabled for: $Name"
        $Component = [Component]::new($Name, [Availability]::NoLogic)
    }
    $Component.PSObject.TypeNames.Insert(0, "PSDotFiles.Component")
    return $Component
}

Function Find-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [String]$Name,
        [Parameter(Mandatory=$false)]
            [String]$Pattern = "*$Name*",
        [Parameter(Mandatory=$false)]
            [Switch]$CaseSensitive,
        [Parameter(Mandatory=$false)]
            [Switch]$RegularExpression
    )

    $MatchingParameters = @{'Property'='DisplayName';'Value'=$Pattern}
    if (!$CaseSensitive -and !$RegularExpression) {
        $MatchingParameters += @{'ILike'=$true}
    } elseif (!$CaseSensitive -and $RegularExpression) {
        $MatchingParameters += @{'IMatch'=$true}
    } elseif ($CaseSensitive -and !$RegularExpression) {
        $MatchingParameters += @{'CLike'=$true}
    } else {
        $MatchingParameters += @{'CMatch'=$true}
    }

    $MatchingPrograms = $script:InstalledPrograms | Where-Object @MatchingParameters
    if ($MatchingPrograms) {
        $Component = [Component]::new($Name, [Availability]::Available)
        if ($MatchingPrograms.DisplayName) {
            $Component.FriendlyName = $MatchingPrograms.DisplayName
        }
        return $Component
    }
    return [Component]::new($Name, [Availability]::Unavailable)
}

Function Get-InstalledPrograms {
    [CmdletBinding()]
    Param()

    $NativeRegPath = "\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    $Wow6432RegPath = "\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

    $InstalledPrograms = @(
        # Native applications installed system wide
        Get-ChildItem "HKLM:$NativeRegPath"
        # Native applications installed under the current user
        Get-ChildItem "HKCU:$NativeRegPath"
        # 32-bit applications installed system wide on 64-bit Windows
        if (Test-Path -Path "HKLM:$Wow6432RegPath") { Get-ChildItem "HKLM:$Wow6432RegPath" }
        # 32-bit applications installed under the current user on 64-bit Windows
        if (Test-Path -Path "HKCU:$Wow6432RegPath") { Get-ChildItem "HKCU:$Wow6432RegPath" }
    ) | # Get the properties of each uninstall key
        % { Get-ItemProperty $_.PSPath } |
        # Filter out all of the uninteresting entries
        ? { $_.DisplayName -and
           !$_.SystemComponent -and
           !$_.ReleaseType -and
           !$_.ParentKeyName -and
           ($_.UninstallString -or $_.NoRemove) }

    return $InstalledPrograms
}

Function Test-DotFilesPath {
    [CmdletBinding()]
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

$script:PSDotFiles = $true

$script:GlobalMetadataPath = Join-Path $PSScriptRoot "metadata"
Write-Debug "Using global metadata directory: $script:GlobalMetadataPath"
. (Join-Path $script:GlobalMetadataPath "templates\common.ps1")
