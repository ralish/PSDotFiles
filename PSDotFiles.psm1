Function Get-DotFiles {
    <#
        .SYNOPSIS
        Enumerates the available dotfiles components
        .DESCRIPTION
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of enumerated components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled ($false).
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
                default                 { Write-Error ("[" + $Component.Name + "] Unknown availability state: " + $Component.Availability) }
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

    $Components = Get-DotFiles @PSBoundParameters | ? { $_.Availability -in ("Available", "AlwaysInstall") }

    foreach ($Component in $Components) {
        Write-Verbose ("Installing component: " + $Component.Name)
        Install-DotFilesComponent -Component $Component
    }
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

    $script:GlobalMetadataPath = Join-Path $PSScriptRoot "metadata"
    Write-Debug "Using global metadata directory: $script:GlobalMetadataPath"

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

    Write-Debug "Refreshing cache of installed programs..."
    $script:InstalledPrograms = Get-InstalledPrograms
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
        return $MatchingPrograms
    }
    return $false
}

Function Get-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [System.IO.DirectoryInfo]$Directory
    )

    $Name               = $Directory.Name
    $MetadataFile       = $Name + ".xml"
    $GlobalMetadataFile = Join-Path $script:GlobalMetadataPath $MetadataFile
    $CustomMetadataFile = Join-Path $script:DotFilesMetadataPath $MetadataFile

    if (Test-Path -Path $CustomMetadataFile -PathType Leaf) {
        Write-Debug "[$Name] Loading custom metadata for component..."
        $Metadata = [Xml](Get-Content $CustomMetadataFile)
        $Component = Initialize-DotFilesComponent -Name $Name -Metadata $Metadata
    } elseif (Test-Path -Path $GlobalMetadataFile -PathType Leaf) {
        Write-Debug "[$Name] Loading global metadata for component..."
        $Metadata = [Xml](Get-Content $GlobalMetadataFile)
        $Component = Initialize-DotFilesComponent -Name $Name -Metadata $Metadata
    } elseif ($script:DotFilesAutodetect) {
        Write-Debug "[$Name] Running automatic detection for component..."
        $Component = Initialize-DotFilesComponent -Name $Name
    } else {
        Write-Debug "[$Name] No metadata & automatic detection disabled."
        $Component = [Component]::new($Name)
        $Component.Availability = [Availability]::NoLogic
    }

    $Component.PSObject.TypeNames.Insert(0, "PSDotFiles.Component")
    return $Component
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

Function Initialize-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [String]$Name,
        [Parameter(Mandatory=$false)]
            [Xml]$Metadata
    )

    if ($PSBoundParameters.ContainsKey("Metadata")) {
        if (!$Metadata.Component) {
            Write-Error "[$Name] No <Component> element in metadata file."
            return
        }
    }

    $Component = [Component]::new($Name)

    # Set the friendly name if provided
    if ($Metadata.Component.FriendlyName) {
        $Component.FriendlyName = $Metadata.Component.Friendlyname
    }

    # Configure and perform component detection
    if (!$Metadata.Component.Detection.Method -or
         $Metadata.Component.Detection.Method -eq "Automatic") {
        $Parameters = @{'Name'=$Name}

        if (!$Metadata.Component.Detection.MatchRegEx -or
             $Metadata.Component.Detection.MatchRegEx -eq "False") {
            $Parameters += @{'RegularExpression'=$false}
        } elseif ($Metadata.Component.Detection.MatchRegEx -eq "True") {
            $Parameters += @{'RegularExpression'=$true}
        } else {
            Write-Error ("[$Name] Invalid MatchRegEx setting for automatic component detection: " + $Metadata.Component.Detection.MatchRegEx)
        }

        if (!$Metadata.Component.Detection.MatchCase -or
             $Metadata.Component.Detection.MatchCase -eq "False") {
            $Parameters += @{'CaseSensitive'=$false}
        } elseif ($Metadata.Component.Detection.MatchCase -eq "True") {
            $Parameters += @{'CaseSensitive'=$true}
        } else {
            Write-Error ("[$Name] Invalid MatchCase setting for automatic component detection: " + $Metadata.Component.Detection.MatchCase)
        }

        if ($Metadata.Component.Detection.MatchPattern) {
            $MatchPattern = $Metadata.Component.Detection.MatchPattern
            $Parameters += @{'Pattern'=$MatchPattern}
        }

        $MatchingPrograms = Find-DotFilesComponent @Parameters
        if ($MatchingPrograms) {
            $Component.Availability = [Availability]::Available
            $Component.UninstallKey = $MatchingPrograms.PSPath
            if (!$Component.FriendlyName -and
                 $MatchingPrograms.DisplayName) {
                $Component.FriendlyName = $MatchingPrograms.DisplayName
            }
        } else {
            $Component.Availability = [Availability]::Unavailable
        }
    } elseif ($Metadata.Component.Detection.Method -eq "Static") {
        if ($Metadata.Component.Detection.Availability) {
            $Availability = $Metadata.Component.Detection.Availability
            $Component.Availability = [Availability]::$Availability
        } else {
            Write-Error "[$Name] No component availability state specified for static detection."
        }
    } else {
        Write-Error ("[$Name] Invalid component detection method specified: " + $Metadata.Component.Detection.Method)
    }

    # If the component isn't available don't both determining the install path
    if ($Component.Availability -notin ("Available", "AlwaysInstall")) {
        return $Component
    }

    # Configure component installation path
    if (!$Metadata.Component.InstallPath) {
        $Component.InstallPath = [Environment]::GetFolderPath("UserProfile")
    } else {
        $SpecialFolder = $Metadata.Component.InstallPath.SpecialFolder
        $Destination = $Metadata.Component.InstallPath.Destination

        if (!$SpecialFolder -and !$Destination) {
            $Component.InstallPath = [Environment]::GetFolderPath("UserProfile")
        } elseif (!$SpecialFolder -and $Destination) {
            # TODO: Check $Destination is an absolute path
            if (Test-Path -Path $Destination -PathType Container -IsValid) {
                $Component.InstallPath = $Destination
            } else {
                Write-Error "[$Name] The destination path for symlinking is invalid: $Destination"
            }
        } elseif ($SpecialFolder -and !$Destination) {
            $Component.InstallPath = [Environment]::GetFolderPath($SpecialFolder)
        } else {
            # TODO: Check $Destination is a relative path
            $InstallPath = Join-Path ([Environment]::GetFolderPath($SpecialFolder)) $Destination
            if (Test-Path -Path $InstallPath -PathType Container -IsValid) {
                $Component.InstallPath = $InstallPath
            } else {
                Write-Error "[$Name] The destination path for symlinking is invalid: $InstallPath"
            }
        }
    }

    return $Component
}

Function Install-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='Component',Mandatory=$true)]
            [Component]$Component,
        [Parameter(ParameterSetName='Recursive',Mandatory=$true)]
            [String]$ComponentName,
        [Parameter(ParameterSetName='Recursive',Mandatory=$true)]
            [String]$BaseDirectory,
        [Parameter(ParameterSetName='Recursive',Mandatory=$true)]
        [AllowNull()]
            [System.IO.DirectoryInfo[]]$Directories,
        [Parameter(ParameterSetName='Recursive',Mandatory=$true)]
        [AllowNull()]
            [System.IO.FileInfo[]]$Files
    )

    if ($PSCmdlet.ParameterSetName -eq "Component") {
        $BaseDirectory = Join-Path $script:DotFilesPath $Component.Name
        Write-Debug ("[" + $Component.Name + "] Base directory is: $BaseDirectory")

        $Directories = Get-ChildItem $BaseDirectory -Directory -Force
        $Files = Get-ChildItem $BaseDirectory -File -Force
        Install-DotFilesComponent -ComponentName $Component.Name -BaseDirectory $BaseDirectory -Directories $Directories -Files $Files
    } else {
        foreach ($File in $Files) {
            $RelativeFile = $File.FullName.Substring($BaseDirectory.Length + 1)
            $TargetFile = Join-Path $HOME $RelativeFile

            if (Test-Path $TargetFile) {
                $ExistingTarget = Get-Item $TargetFile -Force
                if ($ExistingTarget.LinkType -ne "SymbolicLink") {
                    Write-Error "[$ComponentName] Unable to create symlink as a file or directory with the same name already exists: $TargetFile"
                } else {
                    $ParentDirectory = Split-Path $TargetFile -Parent
                    $ResolvedTarget = (Resolve-Path (Join-Path $ParentDirectory $ExistingTarget.Target[0])).Path
                    if (!($File.FullName -eq $ResolvedTarget)) {
                        Write-Error "[$ComponentName] Symlink already exists but points to unexpected target: `"$TargetFile`" -> `"$ResolvedTarget`""
                    } else {
                        Write-Debug "[$ComponentName] Symlink already exists and points to expected target: `"$TargetFile`" -> `"$ResolvedTarget`""
                    }
                }
            } else {
                Write-Debug ("[$ComponentName] Linking file: `"$TargetFile`" -> `"" + $File.FullName + "`"")
            }
        }

        foreach ($Directory in $Directories) {
            $RelativeDirectory = $Directory.FullName.Substring($BaseDirectory.Length + 1)
            $TargetDirectory = Join-Path $HOME $RelativeDirectory

            if (Test-Path $TargetDirectory) {
                $ExistingTarget = Get-Item $TargetDirectory -Force
                if ($ExistingTarget.LinkType -ne "SymbolicLink") {
                    if ($ExistingTarget -isnot [System.IO.DirectoryInfo]) {
                        Write-Error "[$ComponentName] Expected a directory but found a file with the same name: $TargetDirectory"
                    } else {
                        $NextDirectories = Get-ChildItem $Directory.FullName -Directory -Force
                        $NextFiles = Get-ChildItem $Directory.FullName -File -Force
                        Install-DotFilesComponent -ComponentName $ComponentName -BaseDirectory $BaseDirectory -Directories $NextDirectories -Files $NextFiles
                    }
                } else {
                    $ParentDirectory = Split-Path $TargetDirectory -Parent
                    $ResolvedTarget = (Resolve-Path (Join-Path $ParentDirectory $ExistingTarget.Target[0])).Path
                    if (!($Directory.FullName -eq $ResolvedTarget)) {
                        Write-Error "[$ComponentName] Symlink already exists but points to unexpected target: `"$TargetDirectory`" -> `"$ResolvedTarget`""
                    } else {
                        Write-Debug "[$ComponentName] Symlink already exists and points to expected target: `"$TargetDirectory`" -> `"$ResolvedTarget`""
                    }
                }
            } else {
                Write-Debug ("[$ComponentName] Linking directory: `"$TargetDirectory`" -> `"" + $Directory.FullName + "`"")
            }
        }
    }
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

Enum Availability {
    # The component was detected
    Available
    # The component was not detected
    Unavailable
    # The component will be ignored. This is distinct from "Unavailable"
    # as it indicates the component is not available for the platform.
    Ignored
    # The component will always be installed
    AlwaysInstall
    # The component will never be installed
    NeverInstall
    # A failure occurred during component detection
    DetectionFailure
    # No detection logic was available
    NoLogic
}

Class Component {
    # REQUIRED: This should match the corresponding dotfiles directory
    [String]$Name
    # REQUIRED: The availability state per the Availability enumeration
    [Availability]$Availability = [Availability]::DetectionFailure

    # OPTIONAL: Friendly name if one was provided or could be located
    [String]$FriendlyName

    # INTERNAL: Determined by the <SpecialFolder> and <Destination> elements
    [String]$InstallPath
    # INTERNAL: Uninstall Registry key (populated by Find-DotFilesComponent)
    [String]$UninstallKey
    # INTERNAL: This will be set automatically during later install detection
    [String]$Installed

    Component([String]$Name) {
        $this.Name = $Name
    }
}
