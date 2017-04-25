Function Get-DotFiles {
    <#
        .SYNOPSIS
        Enumerates dotfiles components
        .DESCRIPTION
        Enumerates the available dotfiles components, where each component is represented by a top-level folder in the folder specified by the $DotFilesPath variable or the -Path parameter.

        For each component a Component object is constructed and returned which contains the component's basic details, availability, installation state, and other configuration settings.
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of available components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.
        .EXAMPLE
        PS C:\>Get-DotFiles

        Enumerates all available dotfiles components and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>Get-DotFiles -Autodetect

        Enumerates all available dotfiles components, attempting automatic detection of those that lack a metadata file, and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>$DotFiles = Get-DotFiles

        Enumerates all available dotfiles components and saves the returned collection of Component objects to the $DotFiles variable. This allows easy inspection and custom formatting of the Component objects.
        .LINK
        https://github.com/ralish/PSDotFiles
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
    Param(
        [Parameter(Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(Mandatory=$false)]
            [Switch]$Autodetect
    )

    Initialize-PSDotFiles @PSBoundParameters

    [Component[]]$Components = @()
    $Directories = Get-ChildItem -Path $script:DotFilesPath -Directory

    foreach ($Directory in $Directories) {
        $Component = Get-DotFilesComponent -Directory $Directory

        if ($Component.Availability -in ('Available', 'AlwaysInstall')) {
            [Boolean[]]$Results = @()
            $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $Component.SourcePath -Simulate -Silent
            $Component.State = Get-ComponentInstallResult -Results $Results
        }

        $Components += $Component
    }

    return $Components
}

Function Install-DotFiles {
    <#
        .SYNOPSIS
        Installs dotfiles components
        .DESCRIPTION
        Installs all available dotfiles components, or the nominated subset provided via a collection of Component objects as previously returned by the Get-DotFiles cmdlet.

        For each installed component a Component object is returned which contains the component's basic details, availability, installation state, and other configuration settings.
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This parameter is only used when not providing a collection of Component objects as the input, as in this case, the path of each Component is already provided in the object.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of available components without any metadata.

        This parameter is only used when not providing a collection of Component objects as the input, as in this case, the availability of each Component is already provided in the object.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.
        .PARAMETER Components
        A collection of Component objects to be installed as previously returned by Get-DotFiles. The collection may be a filtered set of Components to ensure only a desired subset is installed.

        Note that only the Component objects with an appropriate Availability state will be installed.
        .EXAMPLE
        PS C:\>Install-DotFiles

        Installs all available dotfiles components and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>Install-DotFiles -Autodetect

        Installs all available dotfiles components, attempting automatic detection of those that lack a metadata file, and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>$Components = Get-DotFiles | ? { $_.Name -eq 'git' -or $_.Name -eq 'vim' }
        PS C:\>Install-DotFiles -Components $Components

        Installs only the 'git' and 'vim' dotfiles components, as provided by a filtered set of the components returned by Get-DotFiles, and stored in the $Components variable.
        .LINK
        https://github.com/ralish/PSDotFiles
    #>

    [CmdletBinding(DefaultParameterSetName='Retrieve',SupportsShouldProcess=$true,ConfirmImpact='Low')]
    Param(
        [Parameter(ParameterSetName='Retrieve',Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(ParameterSetName='Retrieve',Mandatory=$false)]
            [Switch]$Autodetect,
        [Parameter(ParameterSetName='Provided',Position=0,Mandatory=$false)]
            [Component[]]$Components
    )

    if (!(Test-IsAdministrator)) {
        if ($PSBoundParameters.ContainsKey('WhatIf')) {
            Write-Warning -Message 'Not running with Administrator privileges but ignoring due to -WhatIf.'
        } else {
            throw 'Unable to run Install-DotFiles as not running with Administrator privileges.'
        }
    }

    if ($PSCmdlet.ParameterSetName -eq 'Retrieve') {
        $Components = Get-DotFiles @PSBoundParameters | Where-Object { $_.Availability -in ('Available', 'AlwaysInstall') }
    } else {
        $UnfilteredComponents = $Components
        $Components = $UnfilteredComponents | Where-Object { $_.Availability -in ('Available', 'AlwaysInstall') }
    }

    foreach ($Component in $Components) {
        $Name = $Component.Name

        if ($PSCmdlet.ShouldProcess($Name, 'Install-DotFilesComponent')) {
            Write-Verbose -Message ('[{0}] Installing ...' -f $Name)
        } else {
            Write-Verbose -Message ('[{0}] Simulating install ...' -f $Name)
            $Simulate = $true
        }

        Write-Debug -Message ('[{0}] Source directory is: {1}' -f $Name, $Component.SourcePath)
        Write-Debug -Message ('[{0}] Installation path is: {1}' -f $Name, $Component.InstallPath)

        [Boolean[]]$Results = @()
        if (!$Simulate) {
            $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $Component.SourcePath
        } else {
            $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $Component.SourcePath -Simulate
        }

        $Component.State = Get-ComponentInstallResult -Results $Results
    }

    return $Components
}

Function Remove-DotFiles {
    <#
        .SYNOPSIS
        Removes dotfiles components
        .DESCRIPTION
        Removes all installed dotfiles components, or the nominated subset provided via a collection of Component objects as previously returned by the Get-DotFiles cmdlet.

        For each removed component a Component object is returned which contains the component's basic details, availability, installation state, and other configuration settings.
        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This parameter is only used when not providing a collection of Component objects as the input, as in this case, the path of each Component is already provided in the object.

        This overrides any default specified in $DotFilesPath.
        .PARAMETER Autodetect
        Toggles automatic detection of available components without any metadata.

        This parameter is only used when not providing a collection of Component objects as the input, as in this case, the availability of each Component is already provided in the object.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.
        .PARAMETER Components
        A collection of Component objects to be removed as previously returned by Get-DotFiles. The collection may be a filtered set of Components to ensure only a desired subset is removed.

        Note that only the Component objects with an appropriate Installed state will be removed.
        .EXAMPLE
        PS C:\>Remove-DotFiles

        Removes all installed dotfiles components and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>Remove-DotFiles -Autodetect

        Removes all available dotfiles components, attempting automatic detection of those that lack a metadata file, and returns a collection of Component objects representing the status of each.
        .EXAMPLE
        PS C:\>$Components = Get-DotFiles | ? { $_.Name -eq 'git' -or $_.Name -eq 'vim' }
        PS C:\>Remove-DotFiles -Components $Components

        Removes only the 'git' and 'vim' dotfiles components, as provided by a filtered set of the components returned by Get-DotFiles, and stored in the $Components variable.
        .LINK
        https://github.com/ralish/PSDotFiles
    #>

    [CmdletBinding(DefaultParameterSetName='Retrieve',SupportsShouldProcess=$true,ConfirmImpact='Low')]
    Param(
        [Parameter(ParameterSetName='Retrieve',Position=0,Mandatory=$false)]
            [String]$Path,
        [Parameter(ParameterSetName='Retrieve',Mandatory=$false)]
            [Switch]$Autodetect,
        [Parameter(ParameterSetName='Provided',Position=0,Mandatory=$false)]
            [Component[]]$Components
    )

    if ($PSCmdlet.ParameterSetName -eq 'Retrieve') {
        $Components = Get-DotFiles @PSBoundParameters | Where-Object { $_.State -in ('Installed', 'PartialInstall') }
    } else {
        $UnfilteredComponents = $Components
        $Components = $UnfilteredComponents | Where-Object { $_.State -in ('Installed', 'PartialInstall') }
    }

    foreach ($Component in $Components) {
        $Name = $Component.Name

        if ($PSCmdlet.ShouldProcess($Name, 'Remove-DotFilesComponent')) {
            Write-Verbose -Message ('[{0}] Removing ...' -f $Name)
        } else {
            Write-Verbose -Message ('[{0}] Simulating removal ...' -f $Name)
            $Simulate = $true
        }

        Write-Debug -Message ('[{0}] Source directory is: {1}' -f $Name, $Component.SourcePath)
        Write-Debug -Message ('[{0}] Installation path is: {1}' -f $Name, $Component.InstallPath)

        [Boolean[]]$Results = @()
        if (!$Simulate) {
            $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $Component.SourcePath
        } else {
            $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $Component.SourcePath -Simulate
        }

        $Component.State = Get-ComponentInstallResult -Results $Results -Removal
    }

    return $Components
}

Function Initialize-PSDotFiles {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
            [String]$Path,
        [Parameter(Mandatory=$false)]
            [Switch]$Autodetect
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
    Write-Verbose -Message ('Using dotfiles directory: {0}' -f $script:DotFilesPath)

    $script:GlobalMetadataPath = Join-Path -Path $PSScriptRoot -ChildPath 'metadata'
    Write-Debug -Message ('Using global metadata directory: {0}' -f $script:GlobalMetadataPath)

    $script:DotFilesMetadataPath = Join-Path -Path $script:DotFilesPath -ChildPath 'metadata'
    Write-Debug -Message ('Using dotfiles metadata directory: {0}' -f $script:DotFilesMetadataPath)

    if ($PSBoundParameters.ContainsKey('Autodetect')) {
        $script:DotFilesAutodetect = $Autodetect
    } elseif (Test-Path -Path Variable:\DotFilesAutodetect) {
        $script:DotFilesAutodetect = $global:DotFilesAutodetect
    } else {
        $script:DotFilesAutodetect = $false
    }
    Write-Debug -Message ('Automatic component detection state: {0}' -f $script:DotFilesAutodetect)

    Write-Debug -Message 'Refreshing cache of installed programs ...'
    $script:InstalledPrograms = Get-InstalledPrograms
}

Function Find-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [String]$Name,
        [Parameter(Mandatory=$false)]
            [String]$Pattern,
        [Parameter(Mandatory=$false)]
            [Switch]$CaseSensitive,
        [Parameter(Mandatory=$false)]
            [Switch]$RegularExpression
    )

    if (!$PSBoundParameters.ContainsKey('Pattern')) {
        $Pattern = '*{0}*' -f $Name
    }

    $MatchingParameters = @{'Property'='DisplayName'
                            'Value'=$Pattern}
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

Function Get-ComponentInstallResult {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
            [Boolean[]]$Results,
        [Parameter(Mandatory=$false)]
            [Switch]$Removal
    )

    if ($Results.Count) {
        $TotalResults = $Results.Count
        $SuccessCount = ($Results | Where-Object { $_ -eq $true  } | Measure-Object).Count
        $FailureCount = ($Results | Where-Object { $_ -eq $false } | Measure-Object).Count

        if ($SuccessCount -eq $TotalResults) {
            if (!$Removal) {
                return [InstallState]::Installed
            } else {
                return [InstallState]::NotInstalled
            }
        } elseif ($FailureCount -eq $TotalResults) {
            if (!$Removal) {
                return [InstallState]::NotInstalled
            } else {
                return [InstallState]::Installed
            }
        } else {
            return [InstallState]::PartialInstall
        }
    }
    return [InstallState]::Unknown
}

Function Get-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [IO.DirectoryInfo]$Directory
    )

    $Name               = $Directory.Name
    $MetadataFile       = '{0}.xml' -f $Name
    $GlobalMetadataFile = Join-Path -Path $script:GlobalMetadataPath -ChildPath $MetadataFile
    $CustomMetadataFile = Join-Path -Path $script:DotFilesMetadataPath -ChildPath $MetadataFile

    $GlobalMetadataPresent = Test-Path -Path $GlobalMetadataFile -PathType Leaf
    $CustomMetadataPresent = Test-Path -Path $CustomMetadataFile -PathType Leaf

    if ($GlobalMetadataPresent -or $CustomMetadataPresent) {
        if ($GlobalMetadataPresent) {
            Write-Debug -Message ('[{0}] Loading global metadata for component ...' -f $Name)
            $Metadata = [Xml](Get-Content -Path $GlobalMetadataFile)
            $Component = Initialize-DotFilesComponent -Name $Name -Metadata $Metadata
        }

        if ($CustomMetadataPresent) {
            $Metadata = [Xml](Get-Content -Path $CustomMetadataFile)
            if ($GlobalMetadataPresent) {
                Write-Debug -Message ('[{0}] Loading custom metadata overrides for component ...' -f $Name)
                $Component = Initialize-DotFilesComponent -Component $Component -Metadata $Metadata
            } else {
                Write-Debug -Message ('[{0}] Loading custom metadata for component ...' -f $Name)
                $Component = Initialize-DotFilesComponent -Name $Name -Metadata $Metadata
            }
        }
    } elseif ($script:DotFilesAutodetect) {
        Write-Debug -Message ('[{0}] Running automatic detection for component ...' -f $Name)
        $Component = Initialize-DotFilesComponent -Name $Name
    } else {
        Write-Debug -Message ('[{0}] No metadata & automatic detection disabled.' -f $Name)
        $Component = [Component]::new($Name, $script:DotFilesPath)
        $Component.Availability = [Availability]::NoLogic
    }

    $Component.PSObject.TypeNames.Insert(0, 'PSDotFiles.Component')

    return $Component
}

Function Get-InstalledPrograms {
    [CmdletBinding()]
    Param()

    $NativeRegPath = '\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    $Wow6432RegPath = '\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    $InstalledPrograms = @(
        # Native applications installed system wide
        if (Test-Path -Path ('HKLM:{0}' -f $NativeRegPath)) { Get-ChildItem -Path ('HKLM:{0}' -f $NativeRegPath) }
        # Native applications installed under the current user
        if (Test-Path -Path ('HKCU:{0}' -f $NativeRegPath)) { Get-ChildItem -Path ('HKCU:{0}' -f $NativeRegPath) }
        # 32-bit applications installed system wide on 64-bit Windows
        if (Test-Path -Path ('HKLM:{0}' -f $Wow6432RegPath)) { Get-ChildItem -Path ('HKLM:{0}' -f $Wow6432RegPath) }
        # 32-bit applications installed under the current user on 64-bit Windows
        if (Test-Path -Path ('HKCU:{0}' -f $Wow6432RegPath)) { Get-ChildItem -Path ('HKCU:{0}' -f $Wow6432RegPath) }
    ) | # Get the properties of each uninstall key
        ForEach-Object { Get-ItemProperty -Path $_.PSPath } |
        # Filter out all the uninteresting entries
        Where-Object { $_.DisplayName -and
           !$_.SystemComponent -and
           !$_.ReleaseType -and
           !$_.ParentKeyName -and
           ($_.UninstallString -or $_.NoRemove) }

    Write-Debug -Message ('Registry scan found {0} installed programs.' -f ($InstalledPrograms | Measure-Object).Count)

    return $InstalledPrograms
}

Function Get-SymlinkTarget {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [IO.FileSystemInfo]$Symlink
    )

    if ($Symlink.LinkType -eq 'SymbolicLink') {
        $Absolute = [IO.Path]::IsPathRooted($Symlink.Target[0])
        if ($Absolute) {
            return $Symlink.Target[0]
        } else {
            return (Resolve-Path -Path (Join-Path -Path (Split-Path -Path $Symlink -Parent) -ChildPath $Symlink.Target[0])).Path
        }
    }

    return $false
}

Function Initialize-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='New',Mandatory=$true)]
            [String]$Name,
        [Parameter(ParameterSetName='Override',Mandatory=$true)]
            [Component]$Component,
        [Parameter(ParameterSetName='New',Mandatory=$false)]
        [Parameter(ParameterSetName='Override',Mandatory=$true)]
            [Xml]$Metadata
    )

    # Create the component if we're not overriding
    if ($PSCmdlet.ParameterSetName -eq 'New') {
        $Component = [Component]::new($Name, $script:DotFilesPath)
    } else {
        $Name = $Component.Name
    }

    # Minimal check for a sane metadata XML file
    if ($PSBoundParameters.ContainsKey('Metadata')) {
        if (!$Metadata.Component) {
            $Component.Availability = [Availability]::DetectionFailure
            Write-Error -Message ('[{0}] No <Component> element in metadata file.' -f $Name)
            return $Component
        }
    }

    # Set the friendly name if one was provided
    if ($Metadata.Component.FriendlyName) {
        $Component.FriendlyName = $Metadata.Component.Friendlyname
    }

    # Configure and perform component detection
    if ($Metadata.Component.Detection.Method -eq 'Automatic' -or
        ($PSCmdlet.ParameterSetName -eq 'New' -and !$Metadata.Component.Detection.Method)) {
        $Parameters = @{'Name'=$Name}

        if (!$Metadata.Component.Detection.MatchRegEx -or
             $Metadata.Component.Detection.MatchRegEx -eq 'False') {
            $Parameters += @{'RegularExpression'=$false}
        } elseif ($Metadata.Component.Detection.MatchRegEx -eq 'True') {
            $Parameters += @{'RegularExpression'=$true}
        } else {
            Write-Error -Message ('[{0}] Invalid MatchRegEx setting for automatic component detection: {1}' -f $Name, $Metadata.Component.Detection.MatchRegEx)
        }

        if (!$Metadata.Component.Detection.MatchCase -or
             $Metadata.Component.Detection.MatchCase -eq 'False') {
            $Parameters += @{'CaseSensitive'=$false}
        } elseif ($Metadata.Component.Detection.MatchCase -eq 'True') {
            $Parameters += @{'CaseSensitive'=$true}
        } else {
            Write-Error -Message ('[{0}] Invalid MatchCase setting for automatic component detection: {1}' -f $Name, $Metadata.Component.Detection.MatchCase)
        }

        if ($Metadata.Component.Detection.MatchPattern) {
            $MatchPattern = $Metadata.Component.Detection.MatchPattern
            $Parameters += @{'Pattern'=$MatchPattern}
        }

        $MatchingPrograms = Find-DotFilesComponent @Parameters
        if ($MatchingPrograms) {
            $NumMatchingPrograms = ($MatchingPrograms | Measure-Object).Count
            if ($NumMatchingPrograms -eq 1) {
                $Component.Availability = [Availability]::Available
                $Component.UninstallKey = $MatchingPrograms.PSPath
                if (!$Component.FriendlyName -and
                     $MatchingPrograms.DisplayName) {
                    $Component.FriendlyName = $MatchingPrograms.DisplayName
                }
            } else {
                Write-Error -Message ('[{0}] Automatic detection found {1} matching programs.' -f $Name, $NumMatchingPrograms)
            }
        } else {
            $Component.Availability = [Availability]::Unavailable
        }
    } elseif ($Metadata.Component.Detection.Method -eq 'FindInPath') {
        if ($Metadata.Component.Detection.FindInPath) {
            $FindBinary = $Metadata.Component.Detection.FindInPath
        } else {
            $FindBinary = $Component.Name
        }

        if (Get-Command -Name $FindBinary -ErrorAction SilentlyContinue) {
            $Component.Availability = [Availability]::Available
        } else {
            $Component.Availability = [Availability]::Unavailable
        }
    } elseif ($Metadata.Component.Detection.Method -eq 'PathExists') {
        if ($Metadata.Component.Detection.PathExists) {
            if (Test-Path -Path $Metadata.Component.Detection.PathExists) {
                $Component.Availability = [Availability]::Available
            } else {
                $Component.Availability = [Availability]::Unavailable
            }
        } else {
            Write-Error -Message ('[{0}] No absolute path specified for testing component availability.' -f $Name)
        }
    } elseif ($Metadata.Component.Detection.Method -eq 'Static') {
        if ($Metadata.Component.Detection.Availability) {
            $Availability = $Metadata.Component.Detection.Availability
            $Component.Availability = [Availability]::$Availability
        } else {
            Write-Error -Message ('[{0}] No component availability state specified for static detection.' -f $Name)
        }
    } elseif ($Metadata.Component.Detection.Method) {
        Write-Error -Message ('[{0}] Invalid component detection method specified: {1}' -f $Name, $Metadata.Component.Detection.Method)
    }

    # If the component isn't available don't bother determining the install path
    if ($Component.Availability -notin ('Available', 'AlwaysInstall')) {
        return $Component
    }

    # Configure component installation path
    if ($PSCmdlet.ParameterSetName -eq 'New' -and
        !$Metadata.Component.InstallPath.SpecialFolder -and
        !$Metadata.Component.InstallPath.Destination) {
        $Component.InstallPath = [Environment]::GetFolderPath('UserProfile')
    } elseif ($Metadata.Component.InstallPath.SpecialFolder -or
              $Metadata.Component.InstallPath.Destination) {
        $SpecialFolder = $Metadata.Component.InstallPath.SpecialFolder
        $Destination = $Metadata.Component.InstallPath.Destination

        if ($SpecialFolder -and $Destination) {
            if (!([IO.Path]::IsPathRooted($Destination))) {
                $InstallPath = Join-Path -Path ([Environment]::GetFolderPath($SpecialFolder)) -ChildPath $Destination
                if (Test-Path -Path $InstallPath -PathType Container -IsValid) {
                    $Component.InstallPath = $InstallPath
                } else {
                    Write-Error -Message ('[{0}] The destination path for symlinking is invalid: {1}' -f $Name, $InstallPath)
                }
            } else {
                Write-Error -Message ('[{0}] The destination path for symlinking is not a relative path: {1}' -f $Name, $Destination)
            }
        } elseif (!$SpecialFolder -and $Destination) {
            if ([IO.Path]::IsPathRooted($Destination)) {
                if (Test-Path -Path $Destination -PathType Container -IsValid) {
                    $Component.InstallPath = $Destination
                } else {
                    Write-Error -Message ('[{0}] The destination path for symlinking is invalid: {1}' -f $Name, $Destination)
                }
            } else {
                Write-Error -Message ('[{0}] The destination path for symlinking is not an absolute path: {1}' -f $Name, $Destination)
            }
        } elseif ($SpecialFolder -and !$Destination) {
            $Component.InstallPath = [Environment]::GetFolderPath($SpecialFolder)
        } else {
            $Component.InstallPath = [Environment]::GetFolderPath('UserProfile')
        }
    }

    # Configure component symlink hiding
    if ($Metadata.Component.InstallPath.HideSymlinks) {
        $HideSymlinks = $Metadata.Component.InstallPath.HideSymlinks
        if ($HideSymlinks -eq 'True') {
            $Component.HideSymlinks = $true
        } elseif ($HideSymlinks -notin ('True', 'False')) {
            Write-Error -Message ('[{0}] Invalid HideSymlinks setting: {1}' -f $Name, $HideSymlinks)
        }
    }

    # Configure component ignore paths
    if ($Metadata.Component.IgnorePaths.Path) {
        foreach ($Path in $Metadata.Component.IgnorePaths.Path) {
            $Component.IgnorePaths += $Path
        }
    }

    return $Component
}

Function Install-DotFilesComponentDirectory {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [Component]$Component,
        [Parameter(Mandatory=$true)]
            [IO.DirectoryInfo[]]$Directories,
        [Parameter(Mandatory=$false)]
            [Switch]$Simulate,
        [Parameter(Mandatory=$false)]
            [Switch]$Silent
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($Directory in $Directories) {
        if ($Directory.FullName -eq $SourcePath.FullName) {
            $TargetDirectory = $InstallPath
        } else {
            $SourceDirectoryRelative = $Directory.FullName.Substring($SourcePath.FullName.Length + 1)
            $TargetDirectory = Join-Path -Path $InstallPath -ChildPath $SourceDirectoryRelative
            if ($SourceDirectoryRelative -in $Component.IgnorePaths) {
                if (!$Silent) {
                    Write-Verbose -Message ('[{0}] Ignoring directory path: {1}' -f $Name, $SourceDirectoryRelative)
                }
                continue
            }
        }

        if (Test-Path -Path $TargetDirectory) {
            $ExistingTarget = Get-Item -Path $TargetDirectory -Force
            if ($ExistingTarget -isnot [IO.DirectoryInfo]) {
                if (!$Silent) {
                    Write-Error -Message ('[{0}] Expected a directory but found a file with the same name: {1}' -f $Name, $TargetDirectory)
                }
                $Results += $false
            } elseif ($ExistingTarget.LinkType -eq 'SymbolicLink') {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($Directory.FullName -eq $SymlinkTarget)) {
                    if (!$Silent) {
                        Write-Error -Message ('[{0}] Symlink already exists but points to unexpected target: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
                    }
                    $Results += $false
                } else {
                    if (!$Silent) {
                        Write-Debug -Message ('[{0}] Symlink already exists and points to expected target: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
                    }
                    $Results += $true
                }
            } else {
                $NextFiles = Get-ChildItem -Path $Directory.FullName -File -Force
                if ($NextFiles) {
                    if (!$Simulate -and !$Silent) {
                        $Results += Install-DotFilesComponentFile -Component $Component -Files $NextFiles
                    } elseif (!$Simulate -and $Silent) {
                        $Results += Install-DotFilesComponentFile -Component $Component -Files $NextFiles -Silent
                    } elseif ($Simulate -and !$Silent) {
                        $Results += Install-DotFilesComponentFile -Component $Component -Files $NextFiles -Simulate
                    } else {
                        $Results += Install-DotFilesComponentFile -Component $Component -Files $NextFiles -Simulate -Silent
                    }
                }

                $NextDirectories = Get-ChildItem -Path $Directory.FullName -Directory -Force
                if ($NextDirectories) {
                    if (!$Simulate -and !$Silent) {
                        $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories
                    } elseif (!$Simulate -and $Silent) {
                        $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -Silent
                    } elseif ($Simulate -and !$Silent) {
                        $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -Simulate
                    } else {
                        $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -Simulate -Silent
                    }
                }
            }
        } else {
            if (!$Silent) {
                Write-Verbose -Message ('[{0}] Linking directory: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $Directory.FullName)
                if ($Simulate) {
                    New-Item -ItemType SymbolicLink -Path $TargetDirectory -Value $Directory.FullName -WhatIf
                } else {
                    $Symlink = New-Item -ItemType SymbolicLink -Path $TargetDirectory -Value $Directory.FullName
                    if ($Component.HideSymlinks) {
                        if (!$Silent) {
                            Write-Debug -Message ('[{0}] Setting attributes to hide directory symlink: "{1}"' -f $Name, $TargetDirectory)
                        }
                        $Attributes = Set-SymlinkAttributes -Symlink $Symlink
                        if (!$Attributes) {
                            Write-Error -Message ('[{0}] Unable to set Hidden and System attributes on directory symlink: "{1}"' -f $Name, $TargetDirectory)
                        }
                    }
                }
            }
            $Results += $true
        }
    }

    return $Results
}

Function Install-DotFilesComponentFile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [Component]$Component,
        [Parameter(Mandatory=$true)]
            [IO.FileInfo[]]$Files,
        [Parameter(Mandatory=$false)]
            [Switch]$Simulate,
        [Parameter(Mandatory=$false)]
            [Switch]$Silent
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($File in $Files) {
        $SourceFileRelative = $File.FullName.Substring($SourcePath.FullName.Length + 1)
        $TargetFile = Join-Path -Path $Component.InstallPath -ChildPath $SourceFileRelative

        if ($SourceFileRelative -in $Component.IgnorePaths) {
            if (!$Silent) {
                Write-Verbose -Message ('[{0}] Ignoring file path: {1}' -f $Name, $SourceFileRelative)
            }
            continue
        }

        if (Test-Path -Path $TargetFile) {
            $ExistingTarget = Get-Item -Path $TargetFile -Force
            if ($ExistingTarget -isnot [IO.FileInfo]) {
                if (!$Silent) {
                    Write-Error -Message ('[{0}] Expected a file but found a directory with the same name: {1}' -f $Name, $TargetFile)
                }
                $Results += $false
            } elseif ($ExistingTarget.LinkType -ne 'SymbolicLink') {
                if (!$Silent) {
                    Write-Error -Message ('[{0}] Unable to create symlink as a file with the same name already exists: {1}' -f $Name, $TargetFile)
                }
                $Results += $false
            } else {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($File.FullName -eq $SymlinkTarget)) {
                    if (!$Silent) {
                        Write-Error -Message ('[{0}] Symlink already exists but points to unexpected target: "{1}" -> "{2}"' -f $Name, $TargetFile, $SymlinkTarget)
                    }
                    $Results += $false
                } else {
                    if (!$Silent) {
                        Write-Debug -Message ('[{0}] Symlink already exists and points to expected target: "{1}" -> "{2}"' -f $Name, $TargetFile, $SymlinkTarget)
                    }
                    $Results += $true
                }
            }
        } else {
            if (!$Silent) {
                Write-Verbose -Message ('[{0}] Linking file: "{1}" -> "{2}"' -f $Name, $TargetFile, $File.FullName)
                if ($Simulate) {
                    New-Item -ItemType SymbolicLink -Path $TargetFile -value $File.FullName -WhatIf
                } else {
                    $Symlink = New-Item -ItemType SymbolicLink -Path $TargetFile -Value $File.FullName
                    if ($Component.HideSymlinks) {
                        if (!$Silent) {
                            Write-Debug -Message ('[{0}] Setting attributes to hide file symlink: "{1}"' -f $Name, $TargetFile)
                        }
                        $Attributes = Set-SymlinkAttributes -Symlink $Symlink
                        if (!$Attributes) {
                            Write-Error -Message ('[{0}] Unable to set Hidden and System attributes on file symlink: "{1}"' -f $Name, $TargetFile)
                        }
                    }
                }
            }
            $Results += $true
        }
    }

    return $Results
}

Function Remove-DotFilesComponentDirectory {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [Component]$Component,
        [Parameter(Mandatory=$true)]
            [IO.DirectoryInfo[]]$Directories,
        [Parameter(Mandatory=$false)]
            [Switch]$Simulate,
        [Parameter(Mandatory=$false)]
            [Switch]$Silent
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($Directory in $Directories) {
        if ($Directory.FullName -eq $SourcePath.FullName) {
            $TargetDirectory = $InstallPath
        } else {
            $SourceDirectoryRelative = $Directory.FullName.Substring($SourcePath.FullName.Length + 1)
            $TargetDirectory = Join-Path -Path $InstallPath -ChildPath $SourceDirectoryRelative
            if ($SourceDirectoryRelative -in $Component.IgnorePaths) {
                if (!$Silent) {
                    Write-Verbose -Message ('[{0}] Ignoring directory path: {1}' -f $Name, $SourceDirectoryRelative)
                }
                continue
            }
        }

        if (Test-Path -Path $TargetDirectory) {
            $ExistingTarget = Get-Item -Path $TargetDirectory -Force
            if ($ExistingTarget -isnot [IO.DirectoryInfo]) {
                if (!$Silent) {
                    Write-Warning -Message ('[{0}] Expected a directory but found a file with the same name: {1}' -f $Name, $TargetDirectory)
                }
            } elseif ($ExistingTarget.LinkType -eq 'SymbolicLink') {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($Directory.FullName -eq $SymlinkTarget)) {
                    if (!$Silent) {
                        Write-Error -Message ('[{0}] Symlink already exists but points to unexpected target: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
                    }
                    $Results += $false
                } else {
                    if (!$Silent) {
                        Write-Verbose -Message ('[{0}] Removing directory symlink: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $Directory.FullName)
                        if ($Simulate) {
                            Write-Warning -Message ('Will remove directory symlink using native rmdir: {0}' -f $TargetDirectory)
                        } else {
                            $Attributes = Set-SymlinkAttributes -Symlink $ExistingTarget -Remove
                            if (!$Attributes) {
                                Write-Error -Message ('[{0}] Unable to remove Hidden and System attributes on directory symlink: "{1}"' -f $Name, $TargetDirectory)
                            }

                            # Remove-Item doesn't correctly handle deleting directory symbolic links
                            # See: https://github.com/PowerShell/PowerShell/issues/621
                            [IO.Directory]::Delete($TargetDirectory)
                        }
                    }
                    $Results += $true
                }
            } else {
                $NextFiles = Get-ChildItem -Path $Directory.FullName -File -Force
                if ($NextFiles) {
                    if (!$Simulate -and !$Silent) {
                        $Results += Remove-DotFilesComponentFile -Component $Component -Files $NextFiles
                    } elseif (!$Simulate -and $Silent) {
                        $Results += Remove-DotFilesComponentFile -Component $Component -Files $NextFiles -Silent
                    } elseif ($Simulate -and !$Silent) {
                        $Results += Remove-DotFilesComponentFile -Component $Component -Files $NextFiles -Simulate
                    } else {
                        $Results += Remove-DotFilesComponentFile -Component $Component -Files $NextFiles -Simulate -Silent
                    }
                }

                $NextDirectories = Get-ChildItem -Path $Directory.FullName -Directory -Force
                if ($NextDirectories) {
                    if (!$Simulate -and !$Silent) {
                        $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories
                    } elseif (!$Simulate -and $Silent) {
                        $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -Silent
                    } elseif ($Simulate -and !$Silent) {
                        $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -Simulate
                    } else {
                        $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -Simulate -Silent
                    }
                }
            }
        } else {
            if (!$Silent) {
                Write-Warning -Message ('[{0}] Expected a directory but found nothing: {1}' -f $Name, $TargetDirectory)
            }
        }
    }

    return $Results
}

Function Remove-DotFilesComponentFile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [Component]$Component,
        [Parameter(Mandatory=$true)]
            [IO.FileInfo[]]$Files,
        [Parameter(Mandatory=$false)]
            [Switch]$Simulate,
        [Parameter(Mandatory=$false)]
            [Switch]$Silent
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($File in $Files) {
        $SourceFileRelative = $File.FullName.Substring($SourcePath.FullName.Length + 1)
        $TargetFile = Join-Path -Path $Component.InstallPath -ChildPath $SourceFileRelative

        if ($SourceFileRelative -in $Component.IgnorePaths) {
            if (!$Silent) {
                Write-Verbose -Message ('[{0}] Ignoring file path: {1}' -f $Name, $SourceFileRelative)
            }
            continue
        }

        if (Test-Path -Path $TargetFile) {
            $ExistingTarget = Get-Item -Path $TargetFile -Force
            if ($ExistingTarget -isnot [IO.FileInfo]) {
                if (!$Silent) {
                    Write-Warning -Message ('[{0}] Expected a file but found a directory with the same name: {1}' -f $Name, $TargetFile)
                }
            } elseif ($ExistingTarget.LinkType -ne 'SymbolicLink') {
                if (!$Silent) {
                    Write-Warning -Message ('[{0}] Found a file instead of a symbolic link so not removing: {1}' -f $Name, $TargetFile)
                }
            } else {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($File.FullName -eq $SymlinkTarget)) {
                    if (!$Silent) {
                        Write-Error -Message ('[{0}] Symlink already exists but points to unexpected target: "{1}" -> "{2}"' -f $Name, $TargetFile, $SymlinkTarget)
                    }
                    $Results += $false
                } else {
                    if (!$Silent) {
                        Write-Verbose -Message ('[{0}] Removing file symlink: "{1}" -> "{2}"' -f $Name, $TargetFile, $File.FullName)
                        if ($Simulate){
                            Remove-Item -Path $TargetFile -WhatIf
                        } else {
                            Remove-Item -Path $TargetFile -Force
                        }
                    }
                    $Results += $true
                }
            }
        } else {
            if (!$Silent) {
                Write-Warning -Message ('[{0}] Expected a file but found nothing: {1}' -f $Name, $TargetFile)
            }
        }
    }

    return $Results
}

Function Set-SymlinkAttributes {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [IO.FileSystemInfo]$Symlink,
        [Parameter(Mandatory=$false)]
            [Switch]$Remove
    )

    if ($Symlink.LinkType -ne 'SymbolicLink') {
        return $false
    }

    $HiddenAttribute = [IO.FileAttributes]::Hidden
    $SystemAttribute = [IO.FileAttributes]::System

    if (!$Remove) {
        $Symlink.Attributes = ($Symlink.Attributes -bor $HiddenAttribute)
        $Symlink.Attributes = ($Symlink.Attributes -bor $SystemAttribute)
    } else {
        if ($CurrentAttributes -band $SystemAttribute) {
            $Symlink.Attributes = ($CurrentAttributes -bxor $SystemAttribute)
        }
        if ($CurrentAttributes -band $HiddenAttribute) {
            $Symlink.Attributes = ($CurrentAttributes -bxor $HiddenAttribute)
        }
    }

    return $true
}

Function Test-DotFilesPath {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
            [String]$Path
    )

    if (Test-Path -Path $Path) {
        $PathItem = Get-Item -Path $Path -Force
        if ($PathItem -is [IO.DirectoryInfo]) {
            $PathLink = Get-SymlinkTarget -Symlink $PathItem
            if ($PathLink) {
                return (Test-DotFilesPath -Path $PathLink)
            }
            return $PathItem
        }
    }

    return $false
}

Function Test-IsAdministrator {
    [CmdletBinding()]
    Param()

    $User = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($User.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        return $true
    }

    return $false
}

Enum Availability {
    # The component was detected
    Available
    # The component was not detected
    Unavailable
    # The component will be ignored
    #
    # This is distinct from "Unavailable" as it indicates the component is not
    # available on the underlying platform.
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

Enum InstallState {
    # The component is installed
    Installed
    # The component is not installed
    NotInstalled
    # The component is partially installed
    #
    # After Get-DotFiles this typically means either:
    #  - Additional files have been added since it was last installed
    #  - A previous installation attempt was only partially successful
    #
    # After Install-DotFiles or Remove-DotFiles this typically means errors were
    # encountered during the installation or removal operation (or simulation).
    PartialInstall
    # The install state of the component can't be determined
    #
    # This can occur when attempting to install a component that has no files or
    # folders (because they're all ignored via the metadata or there are none).
    Unknown
    # The install state of the component has yet to be determined
    NotEvaluated
}

Class Component {
    # REQUIRED: This should match the corresponding dotfiles directory
    [String]$Name
    # REQUIRED: The availability state per the Availability enumeration
    [Availability]$Availability = [Availability]::DetectionFailure

    # OPTIONAL: Friendly name if one was provided or could be located
    [String]$FriendlyName
    # OPTIONAL: Hides newly created symlinks per the <HideSymlinks> element
    [Boolean]$HideSymlinks

    # INTERNAL: This will be set automatically based on the component name
    [IO.DirectoryInfo]$SourcePath
    # INTERNAL: Uninstall Registry key (populated by Find-DotFilesComponent)
    [String]$UninstallKey
    # INTERNAL: Determined by the <SpecialFolder> and <Destination> elements
    [String]$InstallPath
    # INTERNAL: Automatically set based on the <Path> elements in <IgnorePaths>
    [String[]]$IgnorePaths
    # INTERNAL: This will be set automatically during detection and installation
    [InstallState]$State = [InstallState]::NotEvaluated

    Component([String]$Name, [IO.DirectoryInfo]$DotFilesPath) {
        $this.Name = $Name
        $this.SourcePath = (Get-Item -Path (Resolve-Path -Path (Join-Path -Path $DotFilesPath -ChildPath $Name)))
    }
}
