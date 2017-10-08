# See the help for Set-StrictMode for the full details on what this enables.
Set-StrictMode -Version 2.0

Function Get-DotFiles {
    <#
    .SYNOPSIS
    Enumerates dotfiles components

    .DESCRIPTION
    Enumerates the available dotfiles components, where each component is represented by a top-level folder in the folder specified by the $DotFilesPath variable or the -Path parameter.

    For each component a Component object is returned which specifies the component's basic details, availability, installation state, and other configuration settings.

    .PARAMETER Path
    Use the specified directory as the dotfiles directory.

    This overrides any default specified in $DotFilesPath.

    .PARAMETER Autodetect
    Toggles automatic detection of available components without any metadata.

    This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.

    .EXAMPLE
    Get-DotFiles

    Enumerates all available dotfiles components and returns a collection of Component objects representing the status of each.

    .EXAMPLE
    Get-DotFiles -Autodetect

    Enumerates all available dotfiles components, attempting automatic detection of those that lack a metadata file.
    #>

    [CmdletBinding(ConfirmImpact='Low',SupportsShouldProcess)]
    Param(
        [String]$Path,
        [Switch]$Autodetect
    )

    Initialize-PSDotFiles @PSBoundParameters

    [Component[]]$Components = @()
    $Directories = Get-ChildItem -Path $script:DotFilesPath -Directory

    foreach ($Directory in $Directories) {
        $Component = Get-DotFilesComponent -Directory $Directory

        if ($Component.Availability -in ('Available', 'AlwaysInstall')) {
            [Boolean[]]$Results = @()
            $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $Component.SourcePath -Simulate
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

    For each installed component a Component object is returned which specifies the component's basic details, availability, installation state, and other configuration settings.

    .PARAMETER Path
    Use the specified directory as the dotfiles directory.

    This overrides any default specified in $DotFilesPath.

    .PARAMETER Autodetect
    Toggles automatic detection of available components without any metadata.

    This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.

    .PARAMETER Components
    A collection of Component objects to be installed as previously returned by Get-DotFiles.

    Note that only the Component objects with an appropriate Availability state will be installed.

    .EXAMPLE
    Install-DotFiles

    Installs all available dotfiles components and returns a collection of Component objects representing the status of each.

    .EXAMPLE
    $Components = Get-DotFiles | ? { $_.Name -eq 'git' -or $_.Name -eq 'vim' }; Install-DotFiles -Components $Components

    Installs only the 'git' and 'vim' dotfiles components, as provided by a filtered set of the components returned by Get-DotFiles.
    #>

    [CmdletBinding(DefaultParameterSetName='Retrieve',ConfirmImpact='Low',SupportsShouldProcess)]
    Param(
        [Parameter(ParameterSetName='Retrieve')]
        [String]$Path,

        [Parameter(ParameterSetName='Retrieve')]
        [Switch]$Autodetect,

        [Parameter(ParameterSetName='Provided')]
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

    For each removed component a Component object is returned which specifies the component's basic details, availability, installation state, and other configuration settings.

    .PARAMETER Path
    Use the specified directory as the dotfiles directory.

    This overrides any default specified in $DotFilesPath.

    .PARAMETER Autodetect
    Toggles automatic detection of available components without any metadata.

    This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.

    .PARAMETER Components
    A collection of Component objects to be removed as previously returned by Get-DotFiles.

    Note that only the Component objects with an appropriate Installed state will be removed.

    .EXAMPLE
    Remove-DotFiles

    Removes all installed dotfiles components and returns a collection of Component objects representing the status of each.

    .EXAMPLE
    $Components = Get-DotFiles | ? { $_.Name -eq 'git' -or $_.Name -eq 'vim' }; Remove-DotFiles -Components $Components

    Removes only the 'git' and 'vim' dotfiles components, as provided by a filtered set of the components returned by Get-DotFiles.
    #>

    [CmdletBinding(DefaultParameterSetName='Retrieve',ConfirmImpact='Low',SupportsShouldProcess)]
    Param(
        [Parameter(ParameterSetName='Retrieve')]
        [String]$Path,

        [Parameter(ParameterSetName='Retrieve')]
        [Switch]$Autodetect,

        [Parameter(ParameterSetName='Provided')]
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
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [String]$Path,
        [Switch]$Autodetect
    )

    if ($Path) {
        $script:DotFilesPath = Test-DotFilesPath -Path $Path
        if (!$script:DotFilesPath) {
            throw "The provided dotfiles path is either not a directory or it can't be accessed."
        }
    } elseif (Test-Path -Path 'Variable:\DotFilesPath') {
        $script:DotFilesPath = Test-DotFilesPath -Path $global:DotFilesPath
        if (!$script:DotFilesPath) {
            throw "The default dotfiles path (`$DotFilesPath) is either not a directory or it can't be accessed."
        }
    } else {
        throw "No dotfiles path was provided and the default dotfiles path (`$DotFilesPath) has not been configured."
    }
    Write-Verbose -Message ('Using dotfiles directory: {0}' -f $DotFilesPath)

    $MetadataSchemaPath = Join-Path -Path $PSScriptRoot -ChildPath 'Metadata.xsd'
    $script:MetadataSchema = New-Object -TypeName Xml.Schema.XmlSchemaSet
    $null = $MetadataSchema.Add($null, (Get-Item -Path $MetadataSchemaPath))
    $MetadataSchema.Compile() # Implied on the first validation but do so now to ensure it's sane.
    Write-Debug -Message ('Using metadata schema: {0}' -f $MetadataSchemaPath)

    $script:GlobalMetadataPath = Join-Path -Path $PSScriptRoot -ChildPath 'metadata'
    Write-Debug -Message ('Using global metadata directory: {0}' -f $GlobalMetadataPath)

    $script:DotFilesMetadataPath = Join-Path -Path $DotFilesPath -ChildPath 'metadata'
    Write-Debug -Message ('Using dotfiles metadata directory: {0}' -f $DotFilesMetadataPath)

    if ($PSBoundParameters.ContainsKey('Autodetect')) {
        $script:DotFilesAutodetect = $Autodetect
    } elseif (Test-Path -Path 'Variable:\DotFilesAutodetect') {
        $script:DotFilesAutodetect = $global:DotFilesAutodetect
    } else {
        $script:DotFilesAutodetect = $false
    }
    Write-Verbose -Message ('Automatic component detection: {0}' -f $DotFilesAutodetect)

    # TODO: Only retrieve installed programs if we absolutely have to.
    $script:InstalledPrograms = Get-InstalledPrograms
}

Function Initialize-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='New',Mandatory)]
        [String]$Name,

        [Parameter(ParameterSetName='Override',Mandatory)]
        [Component]$Component,

        [Parameter(ParameterSetName='New')]
        [Parameter(ParameterSetName='Override',Mandatory)]
        [Xml]$Metadata
    )

    # Create the component if we're not overriding
    if ($PSCmdlet.ParameterSetName -eq 'New') {
        $Component = [Component]::new($Name, $DotFilesPath)
    } else {
        $Name = $Component.Name
    }

    # Set the friendly name if one was provided
    if ($Metadata -and $Metadata.SelectSingleNode('//Component/FriendlyName')) {
        $Component.FriendlyName = $Metadata.Component.Friendlyname
    }

    # Determine the detection method
    if ($Metadata -and $Metadata.SelectSingleNode('//Component/Detection')) {
        $DetectionMethod = $Metadata.Component.Detection.Method
    } elseif ($PSCmdlet.ParameterSetName -eq 'New') {
        $DetectionMethod = 'Automatic'
    } else {
        $DetectionMethod = $false
    }

    # Run component detection
    if ($DetectionMethod -eq 'Automatic') {
        $Parameters = @{
            'Name'=$Name
            'RegularExpression'=$false
            'CaseSensitive'=$false
        }

        if ($Metadata) {
            if ($Metadata.SelectSingleNode('//Component/Detection/MatchRegEx')) {
                if ($Metadata.Component.Detection.MatchRegEx -eq 'true') {
                    $Parameters['RegularExpression']=$true
                }
            }

            if ($Metadata.SelectSingleNode('//Component/Detection/MatchCase')) {
                if ($Metadata.Component.Detection.MatchCase -eq 'true') {
                    $Parameters['CaseSensitive']=$true
                }
            }

            if ($Metadata.SelectSingleNode('//Component/Detection/MatchPattern')) {
                $Parameters['Pattern']=$Metadata.Component.Detection.MatchPattern
            }
        }

        $MatchingPrograms = Find-DotFilesComponent @Parameters
        if ($MatchingPrograms) {
            $NumMatchingPrograms = ($MatchingPrograms | Measure-Object).Count
            if ($NumMatchingPrograms -eq 1) {
                $Component.Availability = [Availability]::Available
                $Component.UninstallKey = $MatchingPrograms.Uninstall
                if (!$Component.FriendlyName -and $MatchingPrograms.DisplayName) {
                    $Component.FriendlyName = $MatchingPrograms.DisplayName
                }
            } else {
                Write-Error -Message ('[{0}] Automatic detection found {1} matching programs.' -f $Name, $NumMatchingPrograms)
            }
        } else {
            $Component.Availability = [Availability]::Unavailable
        }
    } elseif ($DetectionMethod -eq 'FindInPath') {
        if ($Metadata.SelectSingleNode('//Component/Detection/FindInPath')) {
            $FindBinary = $Metadata.Component.Detection.FindInPath
        } else {
            $FindBinary = $Component.Name
        }

        if (Get-Command -Name $FindBinary -ErrorAction Ignore) {
            $Component.Availability = [Availability]::Available
        } else {
            $Component.Availability = [Availability]::Unavailable
        }
    } elseif ($DetectionMethod -eq 'PathExists') {
        if (Test-Path -Path $Metadata.Component.Detection.PathExists) {
            $Component.Availability = [Availability]::Available
        } else {
            $Component.Availability = [Availability]::Unavailable
        }
    } elseif ($DetectionMethod -eq 'Static') {
        $Availability = $Metadata.Component.Detection.Availability
        $Component.Availability = [Availability]::$Availability
    }

    # If the component isn't available we're done
    if ($Component.Availability -notin ([Availability]::Available, [Availability]::AlwaysInstall)) {
        return $Component
    }

    # Set the default installation path initially
    if ($PSCmdlet.ParameterSetName -eq 'New') {
        $Component.InstallPath = [Environment]::GetFolderPath('UserProfile')
    }

    # Configure installation settings
    if ($Metadata -and $Metadata.SelectSingleNode('//Component/InstallPath')) {
        $SpecialFolder = $false
        $Destination = $false

        # Are we installing to a special folder?
        if ($Metadata.SelectSingleNode('//Component/InstallPath/SpecialFolder')) {
            $SpecialFolder = $Metadata.Component.InstallPath.SpecialFolder
        }

        # Are we installing to a custom destination?
        if ($Metadata.SelectSingleNode('//Component/InstallPath/Destination')) {
            $Destination = $Metadata.Component.InstallPath.Destination
        }

        # Determine the installation path
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
        }

        # Configure symlink hiding
        if ($Metadata.SelectSingleNode('//Component/InstallPath/HideSymlinks')) {
            if ($Metadata.Component.InstallPath.HideSymlinks -eq 'true') {
                $Component.HideSymlinks = $true
            }
        }
    }

    # Configure ignore paths
    if ($Metadata -and $Metadata.SelectSingleNode('//Component/IgnorePaths')) {
        foreach ($Path in $Metadata.Component.IgnorePaths.Path) {
            $Component.IgnorePaths += $Path
        }
    }

    return $Component
}

Function Install-DotFilesComponentDirectory {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [Component]$Component,

        [Parameter(Mandatory)]
        [IO.DirectoryInfo[]]$Directories,

        [Switch]$Simulate
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($Directory in $Directories) {
        # Check the source directory isn't ignored & determine the target directory
        if ($Directory.FullName -eq $SourcePath.FullName) {
            $TargetDirectory = $InstallPath
        } else {
            $SourceDirectoryRelative = $Directory.FullName.Substring($SourcePath.FullName.Length + 1)
            if ($SourceDirectoryRelative -in $Component.IgnorePaths) {
                if (!$Simulate) {
                    Write-Verbose -Message ('[{0}] Ignoring directory path: {1}' -f $Name, $SourceDirectoryRelative)
                }
                continue
            }
            $TargetDirectory = Join-Path -Path $InstallPath -ChildPath $SourceDirectoryRelative
        }

        # TODO
        if (Test-Path -Path $TargetDirectory) {
            $ExistingTarget = Get-Item -Path $TargetDirectory -Force
            if ($ExistingTarget -isnot [IO.DirectoryInfo]) {
                if (!$Simulate) {
                    Write-Error -Message ('[{0}] Expected a directory but found a file with the same name: {1}' -f $Name, $TargetDirectory)
                }
                $Results += $false
            } elseif ($ExistingTarget.LinkType -eq 'SymbolicLink') {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($Directory.FullName -eq $SymlinkTarget)) {
                    if (!$Simulate) {
                        Write-Error -Message ('[{0}] Symlink already exists but points to unexpected target: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
                    }
                    $Results += $false
                } else {
                    Write-Debug -Message ('[{0}] Symlink already exists and points to expected target: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
                    $Results += $true
                }
            } else {
                $NextFiles = Get-ChildItem -Path $Directory.FullName -File -Force
                if ($NextFiles) {
                    if ($Simulate) {
                        $Results += Install-DotFilesComponentFile -Component $Component -Files $NextFiles -Simulate
                    } else {
                        $Results += Install-DotFilesComponentFile -Component $Component -Files $NextFiles
                    }
                }

                $NextDirectories = Get-ChildItem -Path $Directory.FullName -Directory -Force
                if ($NextDirectories) {
                    if ($Simulate) {
                        $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -Simulate
                    } else {
                        $Results += Install-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories
                    }
                }
            }
        } else {
            if (!$Simulate) {
                Write-Verbose -Message ('[{0}] Linking directory: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $Directory.FullName)
                if ($Simulate) {
                    New-Item -ItemType SymbolicLink -Path $TargetDirectory -Value $Directory.FullName -WhatIf
                } else {
                    $Symlink = New-Item -ItemType SymbolicLink -Path $TargetDirectory -Value $Directory.FullName
                    if ($Component.HideSymlinks) {
                        if (!$Simulate) {
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
        [Parameter(Mandatory)]
        [Component]$Component,

        [Parameter(Mandatory)]
        [IO.FileInfo[]]$Files,

        [Switch]$Simulate
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($File in $Files) {
        # Check the source file isn't ignored & determine the target file
        $SourceFileRelative = $File.FullName.Substring($SourcePath.FullName.Length + 1)
        if ($SourceFileRelative -in $Component.IgnorePaths) {
            if (!$Simulate) {
                Write-Verbose -Message ('[{0}] Ignoring file path: {1}' -f $Name, $SourceFileRelative)
            }
            continue
        }
        $TargetFile = Join-Path -Path $Component.InstallPath -ChildPath $SourceFileRelative

        # TODO
        if (Test-Path -Path $TargetFile) {
            $ExistingTarget = Get-Item -Path $TargetFile -Force
            if ($ExistingTarget -isnot [IO.FileInfo]) {
                if (!$Simulate) {
                    Write-Error -Message ('[{0}] Expected a file but found a directory with the same name: {1}' -f $Name, $TargetFile)
                }
                $Results += $false
            } elseif ($ExistingTarget.LinkType -eq 'SymbolicLink') {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($File.FullName -eq $SymlinkTarget)) {
                    if (!$Simulate) {
                        Write-Error -Message ('[{0}] Symlink already exists but points to unexpected target: "{1}" -> "{2}"' -f $Name, $TargetFile, $SymlinkTarget)
                    }
                    $Results += $false
                } else {
                    Write-Debug -Message ('[{0}] Symlink already exists and points to expected target: "{1}" -> "{2}"' -f $Name, $TargetFile, $SymlinkTarget)
                    $Results += $true
                }
            } else {
                if (!$Simulate) {
                    Write-Error -Message ('[{0}] Unable to create symlink as a file with the same name already exists: {1}' -f $Name, $TargetFile)
                }
                $Results += $false
            }
        } else {
            if (!$Simulate) {
                Write-Verbose -Message ('[{0}] Linking file: "{1}" -> "{2}"' -f $Name, $TargetFile, $File.FullName)
                if ($Simulate) {
                    New-Item -ItemType SymbolicLink -Path $TargetFile -value $File.FullName -WhatIf
                } else {
                    $Symlink = New-Item -ItemType SymbolicLink -Path $TargetFile -Value $File.FullName
                    if ($Component.HideSymlinks) {
                        if (!$Simulate) {
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
        [Parameter(Mandatory)]
        [Component]$Component,

        [Parameter(Mandatory)]
        [IO.DirectoryInfo[]]$Directories,

        [Switch]$Simulate
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($Directory in $Directories) {
        # TODO
        if ($Directory.FullName -eq $SourcePath.FullName) {
            $TargetDirectory = $InstallPath
        } else {
            $SourceDirectoryRelative = $Directory.FullName.Substring($SourcePath.FullName.Length + 1)
            if ($SourceDirectoryRelative -in $Component.IgnorePaths) {
                if (!$Simulate) {
                    Write-Verbose -Message ('[{0}] Ignoring directory path: {1}' -f $Name, $SourceDirectoryRelative)
                }
                continue
            }
            $TargetDirectory = Join-Path -Path $InstallPath -ChildPath $SourceDirectoryRelative
        }

        # TODO
        if (Test-Path -Path $TargetDirectory) {
            $ExistingTarget = Get-Item -Path $TargetDirectory -Force
            if ($ExistingTarget -isnot [IO.DirectoryInfo]) {
                if (!$Simulate) {
                    Write-Warning -Message ('[{0}] Expected a directory but found a file with the same name: {1}' -f $Name, $TargetDirectory)
                }
            } elseif ($ExistingTarget.LinkType -eq 'SymbolicLink') {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($Directory.FullName -eq $SymlinkTarget)) {
                    if (!$Simulate) {
                        Write-Error -Message ('[{0}] Symlink already exists but points to unexpected target: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
                    }
                    $Results += $false
                } else {
                    if (!$Simulate) {
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
                    if ($Simulate) {
                        $Results += Remove-DotFilesComponentFile -Component $Component -Files $NextFiles -Simulate
                    } else {
                        $Results += Remove-DotFilesComponentFile -Component $Component -Files $NextFiles
                    }
                }

                $NextDirectories = Get-ChildItem -Path $Directory.FullName -Directory -Force
                if ($NextDirectories) {
                    if ($Simulate) {
                        $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories -Simulate
                    } else {
                        $Results += Remove-DotFilesComponentDirectory -Component $Component -Directories $NextDirectories
                    }
                }
            }
        } else {
            if (!$Simulate) {
                Write-Warning -Message ('[{0}] Expected a directory but found nothing: {1}' -f $Name, $TargetDirectory)
            }
        }
    }

    return $Results
}

Function Remove-DotFilesComponentFile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [Component]$Component,

        [Parameter(Mandatory)]
        [IO.FileInfo[]]$Files,

        [Switch]$Simulate
    )

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    [Boolean[]]$Results = @()

    foreach ($File in $Files) {
        # TODO
        $SourceFileRelative = $File.FullName.Substring($SourcePath.FullName.Length + 1)
        if ($SourceFileRelative -in $Component.IgnorePaths) {
            if (!$Simulate) {
                Write-Verbose -Message ('[{0}] Ignoring file path: {1}' -f $Name, $SourceFileRelative)
            }
            continue
        }
        $TargetFile = Join-Path -Path $Component.InstallPath -ChildPath $SourceFileRelative

        # TODO
        if (Test-Path -Path $TargetFile) {
            $ExistingTarget = Get-Item -Path $TargetFile -Force
            if ($ExistingTarget -isnot [IO.FileInfo]) {
                if (!$Simulate) {
                    Write-Warning -Message ('[{0}] Expected a file but found a directory with the same name: {1}' -f $Name, $TargetFile)
                }
            } elseif ($ExistingTarget.LinkType -eq 'SymbolicLink') {
                $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

                if (!($File.FullName -eq $SymlinkTarget)) {
                    if (!$Simulate) {
                        Write-Error -Message ('[{0}] Symlink already exists but points to unexpected target: "{1}" -> "{2}"' -f $Name, $TargetFile, $SymlinkTarget)
                    }
                    $Results += $false
                } else {
                    if (!$Simulate) {
                        Write-Verbose -Message ('[{0}] Removing file symlink: "{1}" -> "{2}"' -f $Name, $TargetFile, $File.FullName)
                        if ($Simulate){
                            Remove-Item -Path $TargetFile -WhatIf
                        } else {
                            Remove-Item -Path $TargetFile -Force
                        }
                    }
                    $Results += $true
                }
            } else {
                if (!$Simulate) {
                    Write-Warning -Message ('[{0}] Found a file instead of a symbolic link so not removing: {1}' -f $Name, $TargetFile)
                }
            }
        } else {
            if (!$Simulate) {
                Write-Warning -Message ('[{0}] Expected a file but found nothing: {1}' -f $Name, $TargetFile)
            }
        }
    }

    return $Results
}

Function Find-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name,

        [String]$Pattern,
        [Switch]$CaseSensitive,
        [Switch]$RegularExpression
    )

    $Parameters = @{
        'Property'='Name'
    }

    if ($Pattern) {
        $Parameters['Value'] = $Pattern
    } else {
        $Parameters['Value'] = '*{0}*' -f $Name
    }

    if ($CaseSensitive -and $RegularExpression) {
        $Parameters['CMatch'] = $true
    } elseif ($CaseSensitive -and !$RegularExpression) {
        $Parameters['CLike'] = $true
    } elseif (!$CaseSensitive -and $RegularExpression) {
        $Parameters['IMatch'] = $true
    } else {
        $Parameters['ILike'] = $true
    }

    $MatchingPrograms = $script:InstalledPrograms | Where-Object @Parameters
    if ($MatchingPrograms) {
        return $MatchingPrograms
    }

    return $false
}

Function Get-ComponentInstallResult {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Boolean[]]$Results,

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

Function Get-ComponentMetadata {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Path
    )

    try {
        $Metadata = [Xml](Get-Content -Path $Path)
    } catch {
        Write-Warning -Message ('Unable to load metadata file: {0}' -f $Path)
        throw $_
    }

    $Metadata.Schemas = $MetadataSchema
    try {
        $Metadata.Validate($null)
    } catch {
        Write-Warning -Message ('Unable to validate metadata file: {0}' -f $Path)
        throw $_
    }

    return $Metadata
}

Function Get-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [IO.DirectoryInfo]$Directory
    )

    $Name               = $Directory.Name
    $MetadataFile       = '{0}.xml' -f $Name
    $GlobalMetadataFile = Join-Path -Path $GlobalMetadataPath -ChildPath $MetadataFile
    $CustomMetadataFile = Join-Path -Path $DotFilesMetadataPath -ChildPath $MetadataFile

    $GlobalMetadataPresent = Test-Path -Path $GlobalMetadataFile -PathType Leaf
    $CustomMetadataPresent = Test-Path -Path $CustomMetadataFile -PathType Leaf

    if ($GlobalMetadataPresent -or $CustomMetadataPresent) {
        if ($GlobalMetadataPresent) {
            Write-Debug -Message ('[{0}] Loading global metadata ...' -f $Name)
            $Metadata = Get-ComponentMetadata -Path $GlobalMetadataFile
            $Component = Initialize-DotFilesComponent -Name $Name -Metadata $Metadata
        }

        if ($CustomMetadataPresent) {
            Write-Debug -Message ('[{0}] Loading custom metadata ...' -f $Name)
            $Metadata = Get-ComponentMetadata -Path $CustomMetadataFile

            if ($GlobalMetadataPresent) {
                $Component = Initialize-DotFilesComponent -Component $Component -Metadata $Metadata
            } else {
                $Component = Initialize-DotFilesComponent -Name $Name -Metadata $Metadata
            }
        }
    } elseif ($DotFilesAutodetect) {
        Write-Debug -Message ('[{0}] Running automatic detection ...' -f $Name)
        $Component = Initialize-DotFilesComponent -Name $Name
    } else {
        Write-Debug -Message ('[{0}] No metadata & automatic detection disabled.' -f $Name)
        $Component = [Component]::new($Name, $DotFilesPath)
        $Component.Availability = [Availability]::NoLogic
    }

    $Component.PSObject.TypeNames.Insert(0, 'PSDotFiles.Component')
    return $Component
}

Function Get-InstalledPrograms {
    [CmdletBinding()]
    Param()

    $Hives = @('HKLM', 'HKCU')
    $NativeRegPath = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
    $Wow6432RegPath = 'Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    $UninstallKeys = @()
    foreach ($Hive in $Hives) {
        $HiveNativeRegPath = '{0}:\{1}' -f $Hive, $NativeRegPath
        $UninstallKeys += Get-ChildItem -Path $HiveNativeRegPath

        $HiveWow6432RegPath = '{0}:\{1}' -f $Hive, $Wow6432RegPath
        if (Test-Path -Path $HiveWow6432RegPath -PathType Container) {
            $UninstallKeys += Get-ChildItem -Path $HiveWow6432RegPath
        }
    }

    $InstalledPrograms = @()
    foreach ($UninstallKey in $UninstallKeys) {
        $Program = Get-ItemProperty -Path $UninstallKey.PSPath
        if ($Program.PSObject.Properties['DisplayName'] -and
            !$Program.PSObject.Properties['SystemComponent'] -and
            !$Program.PSObject.Properties['ReleaseType'] -and
            !$Program.PSObject.Properties['ParentKeyName'] -and
            ($Program.PSObject.Properties['UninstallString'] -or
             $Program.PSObject.Properties['NoRemove'])) {
            $InstalledProgram = [PSCustomObject]@{
                Name = $Program.DisplayName
                Publisher = $null
                InstallDate = $null
                EstimatedSize = $null
                Version = $null
                Location = $null
                Uninstall = $null
            }

            if ($Program.PSObject.Properties['Publisher']) {
                $InstalledProgram.Publisher = $Program.Publisher
            }

            if ($Program.PSObject.Properties['InstallDate']) {
                $InstalledProgram.InstallDate = $Program.InstallDate
            }

            if ($Program.PSObject.Properties['EstimatedSize']) {
                $InstalledProgram.EstimatedSize = $Program.EstimatedSize
            }

            if ($Program.PSObject.Properties['DisplayVersion']) {
                $InstalledProgram.Version = $Program.DisplayVersion
            }

            if ($Program.PSObject.Properties['InstallLocation']) {
                $InstalledProgram.Location = $Program.InstallLocation
            }

            if ($Program.PSObject.Properties['UninstallString']) {
                $InstalledProgram.Uninstall = $Program.UninstallString
            }

            $InstalledPrograms += $InstalledProgram
        }
    }

    Write-Debug -Message ('Registry scan found {0} installed programs.' -f ($InstalledPrograms | Measure-Object).Count)
    return $InstalledPrograms
}

Function Get-SymlinkTarget {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [IO.FileSystemInfo]$Symlink
    )

    if ($Symlink.LinkType -ne 'SymbolicLink') {
        return $false
    }

    $IsAbsolute = [IO.Path]::IsPathRooted($Symlink.Target[0])
    if ($IsAbsolute) {
        return $Symlink.Target[0]
    }

    return (Resolve-Path -Path (Join-Path -Path (Split-Path -Path $Symlink -Parent) -ChildPath $Symlink.Target[0])).Path
}

Function Set-SymlinkAttributes {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [IO.FileSystemInfo]$Symlink,

        [Switch]$Remove
    )

    if ($Symlink.LinkType -ne 'SymbolicLink') {
        return $false
    }

    $Hidden = [IO.FileAttributes]::Hidden
    $System = [IO.FileAttributes]::System

    if ($Remove) {
        if ($Symlink.Attributes -band $System) {
            $Symlink.Attributes = $Symlink.Attributes -bxor $System
        }

        if ($Symlink.Attributes -band $Hidden) {
            $Symlink.Attributes = $Symlink.Attributes -bxor $Hidden
        }
    } else {
        $Symlink.Attributes = $Symlink.Attributes -bor $System
        $Symlink.Attributes = $Symlink.Attributes -bor $Hidden
    }

    return $true
}

Function Test-DotFilesPath {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Path
    )

    try {
        $PathItem = Get-Item -Path $Path -Force -ErrorAction Stop
    } catch {
        return $false
    }

    if ($PathItem -is [IO.DirectoryInfo]) {
        $PathLink = Get-SymlinkTarget -Symlink $PathItem
        if ($PathLink) {
            return (Test-DotFilesPath -Path $PathLink)
        }
        return $PathItem
    }

    return $false
}

Function Test-IsAdministrator {
    [CmdletBinding()]
    Param()

    $User = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($User.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
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
    # folders, or when they're all ignored via the component's metadata file.
    Unknown

    # The install state of the component has yet to be determined
    NotEvaluated
}

Class Component {
    # REQUIRED: The directory name within the dotfiles directory
    [String]$Name

    # REQUIRED: The availability state per the Availability enumeration
    [Availability]$Availability = [Availability]::DetectionFailure

    # OPTIONAL: Friendly name if one was provided or could be determined
    [String]$FriendlyName

    # OPTIONAL: Hides newly created symlinks per the <HideSymlinks> element
    [Boolean]$HideSymlinks

    # INTERNAL: Source directory derived from $DotFilesPath and $Name
    [IO.DirectoryInfo]$SourcePath

    # INTERNAL: Uninstall registry key if located by Find-DotFilesComponent
    [String]$UninstallKey

    # INTERNAL: Installation directory
    #           Influenced by the <SpecialFolder> and <Destination> elements
    [String]$InstallPath

    # INTERNAL: Source paths to be ignored
    #           Set by <Path> elements under <IgnorePaths>
    [String[]]$IgnorePaths

    # INTERNAL: The install state per the InstallState enumeration
    [InstallState]$State = [InstallState]::NotEvaluated

    Component ([String]$Name, [IO.DirectoryInfo]$DotFilesPath) {
        $this.Name = $Name
        $this.SourcePath = Get-Item -Path (Resolve-Path -Path (Join-Path -Path $DotFilesPath -ChildPath $Name))
    }

    [String] ToString() {
        return 'PSDotFiles: {0}' -f $this.Name
    }
}
