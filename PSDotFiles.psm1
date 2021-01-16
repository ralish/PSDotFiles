# See the help for Set-StrictMode for the full details on what this enables.
Set-StrictMode -Version 2.0

$DefaultGlobalIgnorePaths = @(
    '.stow-local-ignore'
)

Function Get-DotFiles {
    <#
        .SYNOPSIS
        Enumerates dotfiles components

        .DESCRIPTION
        Enumerates the available dotfiles components, where each component is represented by a top-level folder in the folder specified by the $DotFilesPath variable or the -Path parameter.

        For each component a Component object is returned which specifies the component's basic details, availability, installation state, and other configuration settings.

        .PARAMETER AllowNestedSymlinks
        Toggles allowing directory symlinks to destinations outside of the source component path earlier in the path hierarchy.

        This overrides any default specified in $DotFilesAllowNestedSymlinks. If neither is specified the default is disabled.

        .PARAMETER Autodetect
        Toggles automatic detection of available components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.

        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.

        .EXAMPLE
        Get-DotFiles

        Enumerates all available dotfiles components and returns a collection of Component objects representing the status of each.

        .EXAMPLE
        Get-DotFiles -Autodetect

        Enumerates all available dotfiles components, attempting automatic detection of those that lack a metadata file.

        .LINK
        https://github.com/ralish/PSDotFiles
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding(ConfirmImpact = 'Low', SupportsShouldProcess)]
    Param(
        [String]$Path,
        [Switch]$Autodetect,
        [Switch]$AllowNestedSymlinks
    )

    Initialize-PSDotFiles @PSBoundParameters

    return Get-DotFilesInternal @PSBoundParameters
}

Function Install-DotFiles {
    <#
        .SYNOPSIS
        Installs dotfiles components

        .DESCRIPTION
        Installs all available dotfiles components, or the nominated subset provided via a collection of Component objects as previously returned by the Get-DotFiles cmdlet.

        For each installed component a Component object is returned which specifies the component's basic details, availability, installation state, and other configuration settings.

        .PARAMETER AllowNestedSymlinks
        Toggles allowing directory symlinks to destinations outside of the source component path earlier in the path hierarchy.

        This overrides any default specified in $DotFilesAllowNestedSymlinks. If neither is specified the default is disabled.

        .PARAMETER Autodetect
        Toggles automatic detection of available components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.

        .PARAMETER Components
        A collection of Component objects to be installed as previously returned by Get-DotFiles.

        Note that only the Component objects with an appropriate Availability state will be installed.

        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.

        .EXAMPLE
        Install-DotFiles

        Installs all available dotfiles components and returns a collection of Component objects representing the status of each.

        .EXAMPLE
        Get-DotFiles | ? Name -in git, vim | Install-DotFiles

        Installs only the git and vim dotfiles components, as provided by a filtered set of the components returned by Get-DotFiles.

        .LINK
        https://github.com/ralish/PSDotFiles
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding(DefaultParameterSetName = 'Retrieve', ConfirmImpact = 'Low', SupportsShouldProcess)]
    Param(
        [Parameter(ParameterSetName = 'Retrieve')]
        [String]$Path,

        [Parameter(ParameterSetName = 'Retrieve')]
        [Switch]$Autodetect,

        [Parameter(ParameterSetName = 'Pipeline', Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [Component[]]$Components,

        [Switch]$AllowNestedSymlinks
    )

    Begin {
        Initialize-PSDotFiles @PSBoundParameters

        if (!($IsAdministrator -or $IsWin10DevMode)) {
            if ($WhatIfPreference) {
                Write-Warning -Message 'Missing privileges to create symlinks but ignoring due to -WhatIf.'
            } else {
                Write-Warning -Message 'We appear to be running under a user account without permission to create symlinks.'
                Write-Warning -Message 'To fix this perform one of the following:'
                Write-Warning -Message '- Run as an elevated user (ie. with Administrator privileges)'
                Write-Warning -Message "- If you're on Windows 10 Creators Update or newer enable Developer Mode"
                throw 'Unable to run Install-DotFiles as missing privileges to create symlinks.'
            }
        }

        $Processed = [Collections.Generic.List[Component]]::new()
        if ($PSCmdlet.ParameterSetName -eq 'Retrieve') {
            [Component[]]$Components = Get-DotFilesInternal @PSBoundParameters
        }
    }

    Process {
        [Component[]]$ToInstall = $Components | Where-Object { $_.Availability -in ([Availability]::Available, [Availability]::AlwaysInstall) }

        foreach ($Component in $ToInstall) {
            $Name = $Component.Name
            $Results = [Collections.Generic.List[Boolean]]::new()

            $Parameters = @{
                Component         = $Component
                SourceDirectories = $Component.SourcePath
            }

            if (!($PSCmdlet.ShouldProcess($Name, 'Install'))) {
                $Parameters['Simulate'] = $true
            }

            Write-Debug -Message ('[{0}] Source directory is: {1}' -f $Name, $Component.SourcePath)
            Write-Debug -Message ('[{0}] Installation path is: {1}' -f $Name, $Component.InstallPath)
            $Result = Install-DotFilesComponentDirectory @Parameters
            $Results.AddRange($Result)
            $Component.State = Get-ComponentInstallResult -Results $Results
            $Processed.Add($Component)
        }
    }

    End {
        return $Processed
    }
}

Function Remove-DotFiles {
    <#
        .SYNOPSIS
        Removes dotfiles components

        .DESCRIPTION
        Removes all installed dotfiles components, or the nominated subset provided via a collection of Component objects as previously returned by the Get-DotFiles cmdlet.

        For each removed component a Component object is returned which specifies the component's basic details, availability, installation state, and other configuration settings.

        .PARAMETER AllowNestedSymlinks
        Toggles allowing directory symlinks to destinations outside of the source component path earlier in the path hierarchy.

        This overrides any default specified in $DotFilesAllowNestedSymlinks. If neither is specified the default is disabled.

        .PARAMETER Autodetect
        Toggles automatic detection of available components without any metadata.

        This overrides any default specified in $DotFilesAutodetect. If neither is specified the default is disabled.

        .PARAMETER Components
        A collection of Component objects to be removed as previously returned by Get-DotFiles.

        Note that only the Component objects with an appropriate Installed state will be removed.

        .PARAMETER Path
        Use the specified directory as the dotfiles directory.

        This overrides any default specified in $DotFilesPath.

        .EXAMPLE
        Remove-DotFiles

        Removes all installed dotfiles components and returns a collection of Component objects representing the status of each.

        .EXAMPLE
        Get-DotFiles | ? Name -in git, vim | Remove-DotFiles

        Removes only the git and vim dotfiles components, as provided by a filtered set of the components returned by Get-DotFiles.

        .LINK
        https://github.com/ralish/PSDotFiles
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding(DefaultParameterSetName = 'Retrieve', ConfirmImpact = 'Low', SupportsShouldProcess)]
    Param(
        [Parameter(ParameterSetName = 'Retrieve')]
        [String]$Path,

        [Parameter(ParameterSetName = 'Retrieve')]
        [Switch]$Autodetect,

        [Parameter(ParameterSetName = 'Pipeline', Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [Component[]]$Components,

        [Switch]$AllowNestedSymlinks
    )

    Begin {
        Initialize-PSDotFiles @PSBoundParameters

        $Processed = [Collections.Generic.List[Component]]::new()
        if ($PSCmdlet.ParameterSetName -eq 'Retrieve') {
            [Component[]]$Components = Get-DotFilesInternal @PSBoundParameters
        }
    }

    Process {
        [Component[]]$ToInstall = $Components | Where-Object { $_.State -in ([InstallState]::Installed, [InstallState]::PartialInstall) }

        foreach ($Component in $ToInstall) {
            $Name = $Component.Name
            $Results = [Collections.Generic.List[Boolean]]::new()

            $Parameters = @{
                Component         = $Component
                SourceDirectories = $Component.SourcePath
            }

            if (!($PSCmdlet.ShouldProcess($Name, 'Remove'))) {
                $Parameters['Simulate'] = $true
            }

            Write-Debug -Message ('[{0}] Source directory is: {1}' -f $Name, $Component.SourcePath)
            Write-Debug -Message ('[{0}] Installation path is: {1}' -f $Name, $Component.InstallPath)
            $Result = Remove-DotFilesComponentDirectory @Parameters
            $Results.AddRange($Result)
            $Component.State = Get-ComponentInstallResult -Results $Results -Removal
            $Processed.Add($Component)
        }
    }

    End {
        return $Processed
    }
}

Function Get-DotFilesInternal {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [String]$Path,
        [Switch]$Autodetect,
        [Switch]$AllowNestedSymlinks
    )

    $Components = [Collections.Generic.List[Component]]::new()
    $Directories = Get-ChildItem -Path $DotFilesPath -Directory
    foreach ($Directory in $Directories) {
        $Component = Get-DotFilesComponent -Directory $Directory

        if ($Component.Availability -in ([Availability]::Available, [Availability]::AlwaysInstall)) {
            $Results = [Collections.Generic.List[Boolean]]::new()
            $Result = Install-DotFilesComponentDirectory -Component $Component -SourceDirectories $Component.SourcePath -Verify
            $Results.AddRange($Result)
            $Component.State = Get-ComponentInstallResult -Results $Results
        }

        $Components.Add($Component)
    }

    if (!$Components) {
        Write-Warning -Message 'Get-DotFiles returned no results. Are you sure your $DotFilesPath is set correctly?'
    }

    return $Components
}

Function Initialize-PSDotFiles {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [String]$Path,
        [Switch]$Autodetect,
        [Switch]$AllowNestedSymlinks
    )

    if ($PSBoundParameters.ContainsKey('Path')) {
        $Script:DotFilesPath = Test-DotFilesPath -Path $Path
        if (!$Script:DotFilesPath) {
            throw "The provided dotfiles path is either not a directory or it can't be accessed."
        }
    } elseif (Get-Variable -Name 'DotFilesPath' -Scope Global -ErrorAction Ignore) {
        $Script:DotFilesPath = Test-DotFilesPath -Path $Global:DotFilesPath
        if (!$Script:DotFilesPath) {
            throw "The default dotfiles path (`$DotFilesPath) is either not a directory or it can't be accessed."
        }
    } else {
        throw 'No dotfiles path was provided and the default path ($DotFilesPath) has not been configured.'
    }
    Write-Verbose -Message ('dotfiles directory: {0}' -f $DotFilesPath)

    if (Get-Variable -Name 'DotFilesSkipMetadataSchemaChecks' -Scope Global -ErrorAction Ignore) {
        $Script:SkipMetadataSchemaChecks = $Global:DotFilesSkipMetadataSchemaChecks
    } else {
        $Script:SkipMetadataSchemaChecks = $false
    }

    if (!$SkipMetadataSchemaChecks) {
        $MetadataSchemaPath = Join-Path -Path $PSScriptRoot -ChildPath 'Metadata.xsd'
        $Script:MetadataSchema = New-Object -TypeName Xml.Schema.XmlSchemaSet
        $null = $MetadataSchema.Add($null, (Get-Item -Path $MetadataSchemaPath))
        $MetadataSchema.Compile() # Implied on the first validation but do so now to ensure it's sane.
        Write-Debug -Message ('Metadata schema: {0}' -f $MetadataSchemaPath)
    } else {
        Write-Warning -Message 'Skipping validation of metadata files against XML schema.'
    }

    $Script:GlobalMetadataPath = Join-Path -Path $PSScriptRoot -ChildPath 'metadata'
    Write-Debug -Message ('Global metadata: {0}' -f $GlobalMetadataPath)

    $Script:DotFilesMetadataPath = Join-Path -Path $DotFilesPath -ChildPath 'metadata'
    Write-Debug -Message ('Dotfiles metadata: {0}' -f $DotFilesMetadataPath)

    if ($PSBoundParameters.ContainsKey('Autodetect')) {
        $Script:DotFilesAutodetect = $Autodetect
    } elseif (Get-Variable -Name 'DotFilesAutodetect' -Scope Global -ErrorAction Ignore) {
        $Script:DotFilesAutodetect = $Global:DotFilesAutodetect
    } else {
        $Script:DotFilesAutodetect = $false
    }
    Write-Verbose -Message ('Automatic component detection: {0}' -f $DotFilesAutodetect)

    if ($PSBoundParameters.ContainsKey('AllowNestedSymlinks')) {
        $Script:AllowNestedSymlinks = $AllowNestedSymlinks
    } elseif (Get-Variable -Name 'DotFilesAllowNestedSymlinks' -Scope Global -ErrorAction Ignore) {
        $Script:AllowNestedSymlinks = $Global:DotFilesAllowNestedSymlinks
    } else {
        $Script:AllowNestedSymlinks = $false
    }
    Write-Verbose -Message ('Nested symlinks permitted: {0}' -f $AllowNestedSymlinks)

    if (Get-Variable -Name 'DotFilesGlobalIgnorePaths' -Scope Global -ErrorAction Ignore) {
        $Script:GlobalIgnorePaths = $Global:DotFilesGlobalIgnorePaths
    } else {
        $Script:GlobalIgnorePaths = $DefaultGlobalIgnorePaths
    }
    Write-Verbose -Message ('Global ignore paths: {0}' -f [String]::Join(', ', $GlobalIgnorePaths))

    # Cache these results for usage later
    $Script:IsAdministrator = Test-IsAdministrator
    $Script:IsAppxCompatNeeded = Test-IsAppxCompatNeeded
    $Script:IsMkLinkNeeded = Test-IsMkLinkNeeded
    $Script:IsWin10DevMode = Test-IsWin10DevMode
    $Script:RefreshInstalledPrograms = $true
}

Function Initialize-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName = 'New', Mandatory)]
        [String]$Name,

        [Parameter(ParameterSetName = 'Override', Mandatory)]
        [Component]$Component,

        [Parameter(ParameterSetName = 'New')]
        [Parameter(ParameterSetName = 'Override', Mandatory)]
        [Xml]$Metadata
    )

    # Ensures XML methods are always available
    if (!$PSBoundParameters.ContainsKey('Metadata')) {
        $Metadata = New-Object -TypeName Xml.XmlDocument
    }

    # Create the component if we're not overriding
    if ($PSCmdlet.ParameterSetName -eq 'New') {
        $Component = [Component]::new($Name, $DotFilesPath)
    } else {
        $Name = $Component.Name
    }

    # Set the friendly name if one was provided
    if ($Metadata.SelectSingleNode('//Component/FriendlyName')) {
        $Component.FriendlyName = $Metadata.Component.Friendlyname
    }

    # Append any base path to the source path
    if ($Metadata.SelectSingleNode('//Component/BasePath')) {
        $Component.SourcePath = Join-Path -Path $Component.SourcePath -ChildPath $Metadata.Component.BasePath
    }

    # Configure ignore paths
    if ($Metadata.SelectSingleNode('//Component/IgnorePaths')) {
        foreach ($Path in $Metadata.Component.IgnorePaths.IgnorePath) {
            $Component.IgnorePaths += $Path
        }
    }

    # Configure additional paths
    if ($Metadata.SelectSingleNode('//Component/AdditionalPaths')) {
        foreach ($Path in $Metadata.Component.AdditionalPaths.AdditionalPath) {
            $Component.AdditionalPaths[$Path.source] += @($Path.TargetPath.symlink)
        }
    }

    # Configure rename paths
    if ($Metadata.SelectSingleNode('//Component/RenamePaths')) {
        foreach ($Path in $Metadata.Component.RenamePaths.RenamePath) {
            $Component.RenamePaths[$Path.source] = $Path.symlink
        }
    }

    # Configure symlink hiding
    if ($Metadata.SelectSingleNode('//Component/InstallPath/HideSymlinks')) {
        if ($Metadata.Component.InstallPath.HideSymlinks -eq 'true') {
            $Component.HideSymlinks = $true
        }
    }

    # Determine the detection method
    if ($Metadata.SelectSingleNode('//Component/Detection')) {
        $DetectionMethod = $Metadata.Component.Detection.Method
    } elseif ($PSCmdlet.ParameterSetName -eq 'New') {
        $DetectionMethod = 'Automatic'
    } else {
        $DetectionMethod = $false
    }

    # Run component detection
    if ($DetectionMethod -eq 'Automatic') {
        $Parameters = @{
            Name              = $Name
            RegularExpression = $false
            CaseSensitive     = $false
        }

        if ($Metadata.SelectSingleNode('//Component/Detection/MatchRegEx')) {
            if ($Metadata.Component.Detection.MatchRegEx -eq 'true') {
                $Parameters['RegularExpression'] = $true
            }
        }

        if ($Metadata.SelectSingleNode('//Component/Detection/MatchCase')) {
            if ($Metadata.Component.Detection.MatchCase -eq 'true') {
                $Parameters['CaseSensitive'] = $true
            }
        }

        if ($Metadata.SelectSingleNode('//Component/Detection/MatchPattern')) {
            $Parameters['Pattern'] = $Metadata.Component.Detection.MatchPattern
        }

        $MatchingPrograms = Find-DotFilesComponent @Parameters
        if ($MatchingPrograms) {
            $NumMatchingPrograms = ($MatchingPrograms | Measure-Object).Count
            if ($NumMatchingPrograms -ge 1) {
                if ($NumMatchingPrograms -gt 1) {
                    Write-Warning -Message ('[{0}] Automatic detection found {1} matching programs.' -f $Name, $NumMatchingPrograms)
                }

                $Component.Availability = [Availability]::Available

                if (!$Component.FriendlyName -and $MatchingPrograms.Name) {
                    $Component.FriendlyName = [String]::Join(', ', ($MatchingPrograms.Name | Where-Object { ![String]::IsNullOrWhiteSpace($_) } | Sort-Object ))
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

    # Configure install path
    if ($Metadata.SelectSingleNode('//Component/InstallPath')) {
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
    }

    return $Component
}

Function Install-DotFilesComponentDirectory {
    [CmdletBinding(DefaultParameterSetName = 'Install')]
    Param(
        [Parameter(Mandatory)]
        [Component]$Component,

        [Parameter(Mandatory)]
        [IO.DirectoryInfo[]]$SourceDirectories,

        [Parameter(ParameterSetName = 'Simulate')]
        [Switch]$Simulate,

        [Parameter(ParameterSetName = 'Verify')]
        [Switch]$Verify
    )

    # Beware: This function is called recursively!

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    $Results = [Collections.Generic.List[Boolean]]::new()

    foreach ($SourceDirectory in $SourceDirectories) {
        # Check if we're operating on the top-level directory of a component or have recursed into a
        # subdirectory. If the latter, we need the relative path from the top-level directory so we
        # can adjust the target installation directory appropriately. Further, subdirectories may be
        # ignored by an <IgnorePaths> configuration, so also check this before proceeding further.
        if ($SourceDirectory.FullName -eq $SourcePath.FullName) {
            $ComponentRootDir = $true
            $TargetDirectory = $InstallPath

            # We need to check the source directory does actually exist. There are some edge cases
            # where this may not be the case, with a common case being an invalid BasePath setting.
            $SourceDirectory = Get-Item -Path $SourcePath.FullName -Force -ErrorAction Ignore
            if ($SourceDirectory -isnot [IO.DirectoryInfo]) {
                $Results.Add($false)
                if ($PSCmdlet.ParameterSetName -ne 'Install') {
                    Write-Error -Message ('[{0}] Unable to retrieve source directory: {1}' -f $Name, $SourcePath.FullName)
                }
                continue
            }
        } else {
            $ComponentRootDir = $false
            $SourceDirectoryRelative = $SourceDirectory.FullName.Substring($SourcePath.FullName.Length + 1)

            if ($SourceDirectoryRelative -in $GlobalIgnorePaths -or
                $SourceDirectoryRelative -in $Component.IgnorePaths) {
                Write-Debug -Message ('[{0}] Ignoring directory: {1}' -f $Name, $SourceDirectoryRelative)
                continue
            }

            $TargetDirectory = Join-Path -Path $InstallPath -ChildPath $SourceDirectoryRelative
        }

        # We've got the directory source and target paths and have confirmed the source path is not
        # ignored. Start by trying to retrieve any item which may already exist at the target path.
        try {
            $ExistingTarget = Get-Item -Path $TargetDirectory -Force -ErrorAction Stop
        } catch {
            # Missing directory on a verification means the component is not/partially installed
            if ($Verify) {
                $Results.Add($false)
                continue
            }

            # Missing directory on a simulation means this directory will be symlinked on install
            if ($Simulate) {
                Write-Verbose -Message ('[{0}] Will symlink directory: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SourceDirectory.FullName)
                $Results.Add($true)
                continue
            }

            # When operating on the top-level directory of a component we need to check that the
            # parent directory of the target path actually exists. If not, we'll create it.
            if ($ComponentRootDir) {
                $TargetParentDirectory = Split-Path -Path $TargetDirectory -Parent

                if (!(Test-Path -Path $TargetParentDirectory -PathType Container)) {
                    Write-Verbose -Message ('[{0}] Creating parent directory for target symlink: {1}' -f $Name, $TargetParentDirectory)
                    $null = New-Item -Path $TargetParentDirectory -ItemType Directory
                }
            }

            # Nothing exists at the target path so we can create the directory symlink
            Write-Verbose -Message ('[{0}] Symlinking directory: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SourceDirectory.FullName)
            $Symlink = New-Symlink -Path $TargetDirectory -Target $SourceDirectory.FullName

            # Set the hidden and system attributes if requested
            if ($Component.HideSymlinks) {
                $Attributes = Set-SymlinkAttributes -Symlink $Symlink
                if (!$Attributes) {
                    $Results.Add($false)
                    Write-Error -Message ('[{0}] Unable to set Hidden and System attributes on directory symlink: "{1}"' -f $Name, $TargetDirectory)
                    continue
                }
            }

            $Results.Add($true)
            continue
        }

        # We found an item but it's not a directory! The user will need to fix this conflict.
        if ($ExistingTarget -isnot [IO.DirectoryInfo]) {
            $Results.Add($false)
            if ($PSCmdlet.ParameterSetName -ne 'Install') {
                Write-Error -Message ('[{0}] Expected a directory but found a file: {1}' -f $Name, $TargetDirectory)
            }
            continue
        }

        # We found a symbolic link. Either:
        # - It points where we expect -> nothing to do
        # - It points somewhere else -> recurse into it (AllowNestedSymlinks)
        # - It points somewhere unexpected -> unable to symlink this path element
        if ($ExistingTarget.LinkType -eq 'SymbolicLink') {
            $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget
            if ($SourceDirectory.FullName -eq $SymlinkTarget) {
                $Results.Add($true)
                Write-Debug -Message ('[{0}] Valid directory symlink: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
                continue
            } elseif ($AllowNestedSymlinks) {
                Write-Verbose -Message ('[{0}] Recursing into existing symlink with target: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
            } else {
                $Results.Add($false)
                if ($PSCmdlet.ParameterSetName -ne 'Install') {
                    Write-Error -Message ('[{0}] Found a directory symlink to an unexpected target: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
                }
                continue
            }
        }

        # We found a regular directory or a directory symlink to an unexpected target. As we
        # can't create a directory symlink recurse into the source path and attempt to symlink
        # each file into the target.
        $NextFiles = Get-ChildItem -Path $SourceDirectory.FullName -File -Force
        if ($NextFiles) {
            if ($Verify) {
                $Result = Install-DotFilesComponentFile -Component $Component -SourceFiles $NextFiles -Verify
            } elseif ($Simulate) {
                $Result = Install-DotFilesComponentFile -Component $Component -SourceFiles $NextFiles -Simulate
            } else {
                $Result = Install-DotFilesComponentFile -Component $Component -SourceFiles $NextFiles
            }

            $Results.AddRange($Result)
        }

        # As above, but now symlink each of the directories
        $NextDirectories = Get-ChildItem -Path $SourceDirectory.FullName -Directory -Force
        if ($NextDirectories) {
            if ($Verify) {
                $Result = Install-DotFilesComponentDirectory -Component $Component -SourceDirectories $NextDirectories -Verify
            } elseif ($Simulate) {
                $Result = Install-DotFilesComponentDirectory -Component $Component -SourceDirectories $NextDirectories -Simulate
            } else {
                $Result = Install-DotFilesComponentDirectory -Component $Component -SourceDirectories $NextDirectories
            }

            $Results.AddRange($Result)
        }

        # Warn if there were no items in the source path and we couldn't symlink the directory
        if (!$NextFiles -and !$NextDirectories) {
            Write-Warning -Message ('[{0}] Unable to symlink empty directory as target exists: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
        }
    }

    return , $Results
}

Function Install-DotFilesComponentFile {
    [CmdletBinding(DefaultParameterSetName = 'Install')]
    Param(
        [Parameter(Mandatory)]
        [Component]$Component,

        [Parameter(Mandatory)]
        [IO.FileInfo[]]$SourceFiles,

        [Parameter(ParameterSetName = 'Simulate')]
        [Switch]$Simulate,

        [Parameter(ParameterSetName = 'Verify')]
        [Switch]$Verify
    )

    # Beware: This function is called recursively!

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    $Results = [Collections.Generic.List[Boolean]]::new()

    foreach ($SourceFile in $SourceFiles) {
        # We always need to determine the relative path of files from the top-level directory of the
        # component so we can adjust the target installation path appropriately.
        $SourceFileRelative = $SourceFile.FullName.Substring($SourcePath.FullName.Length + 1)

        # Like directories, files may also be ignored by an <IgnorePaths> configuration.
        if ($SourceFileRelative -in $GlobalIgnorePaths -or
            $SourceFileRelative -in $Component.IgnorePaths) {
            Write-Debug -Message ('[{0}] Ignoring file: {1}' -f $Name, $SourceFileRelative)
            continue
        }

        Write-Debug -Message ('[{0}] Processing file: {1}' -f $Name, $SourceFileRelative)
        $TargetFiles = [Collections.Generic.List[String]]::new()

        # Determine additional target symlink paths.
        if ($Component.AdditionalPaths.ContainsKey($SourceFileRelative)) {
            foreach ($AdditionalPath in $Component.AdditionalPaths[$SourceFileRelative]) {
                $TargetFile = Join-Path -Path $InstallPath -ChildPath $AdditionalPath
                Write-Debug -Message ('[{0}] Adding additional path: {1}' -f $Name, $TargetFile)
                $TargetFiles.Add($TargetFile)
            }
        }

        # Determine the target symlink with reference to any defined renamed path.
        if ($Component.RenamePaths.ContainsKey($SourceFileRelative)) {
            $TargetFile = Join-Path -Path $InstallPath -ChildPath $Component.RenamePaths[$SourceFileRelative]
            Write-Debug -Message ('[{0}] Using renamed target path: {1}' -f $Name, $TargetFile)
        } else {
            $TargetFile = Join-Path -Path $InstallPath -ChildPath $SourceFileRelative
            Write-Debug -Message ('[{0}] Using target path: {1}' -f $Name, $TargetFile)
        }
        $TargetFiles.Add($TargetFile)

        foreach ($TargetFile in $TargetFiles) {
            # We've got the file source and target paths and have confirmed the source path is not
            # ignored. Start by trying to retrieve any item which may already exist at the target path.
            try {
                $ExistingTarget = Get-Item -Path $TargetFile -Force -ErrorAction Stop
            } catch {
                # Missing file on a verification means the component is not/partially installed
                if ($Verify) {
                    $Results.Add($false)
                    continue
                }

                # Missing file on a simulation means this file will be symlinked on install
                if ($Simulate) {
                    Write-Verbose -Message ('[{0}] Will symlink file: "{1}" -> "{2}"' -f $Name, $TargetFile, $SourceFile.FullName)
                    $Results.Add($true)
                    continue
                }

                # Nothing exists at the target path so we can create the file symlink
                Write-Verbose -Message ('[{0}] Symlinking file: "{1}" -> "{2}"' -f $Name, $TargetFile, $SourceFile.FullName)
                $Symlink = New-Symlink -Path $TargetFile -Target $SourceFile.FullName

                # Set the hidden and system attributes if requested
                if ($Component.HideSymlinks) {
                    $Attributes = Set-SymlinkAttributes -Symlink $Symlink
                    if (!$Attributes) {
                        $Results.Add($true)
                        Write-Error -Message ('[{0}] Unable to set Hidden and System attributes on file symlink: "{1}"' -f $Name, $TargetFile)
                        continue
                    }
                }

                $Results.Add($true)
                continue
            }

            # We found an item but it's not a file! The user will need to fix this conflict.
            if ($ExistingTarget -isnot [IO.FileInfo]) {
                $Results.Add($false)
                if ($PSCmdlet.ParameterSetName -ne 'Install') {
                    Write-Error -Message ('[{0}] Expected a file but found a directory: {1}' -f $Name, $TargetFile)
                }
                continue
            }

            # We found a file. We can't replace it so this is another conflict for the user.
            if ($ExistingTarget.LinkType -ne 'SymbolicLink') {
                $Results.Add($false)
                if ($PSCmdlet.ParameterSetName -ne 'Install') {
                    Write-Error -Message ('[{0}] Unable to create symlink as a file already exists: {1}' -f $Name, $TargetFile)
                }
                continue
            }

            # We found a symbolic link. Either it points where we expect it to and all is well, or
            # it points somewhere unexpected, and the user will need to investigate why that is.
            $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget
            if ($SourceFile.FullName -eq $SymlinkTarget) {
                $Results.Add($true)
                Write-Debug -Message ('[{0}] Valid file symlink: "{1}" -> "{2}"' -f $Name, $TargetFile, $SymlinkTarget)
            } else {
                $Results.Add($false)
                if ($PSCmdlet.ParameterSetName -ne 'Install') {
                    Write-Error -Message ('[{0}] Found a file symlink to an unexpected target: "{1}" -> "{2}"' -f $Name, $TargetFile, $SymlinkTarget)
                }
            }
        }
    }

    return , $Results
}

Function Remove-DotFilesComponentDirectory {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [Component]$Component,

        [Parameter(Mandatory)]
        [IO.DirectoryInfo[]]$SourceDirectories,

        [Switch]$Simulate
    )

    # Beware: This function is called recursively!

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    $Results = [Collections.Generic.List[Boolean]]::new()

    foreach ($SourceDirectory in $SourceDirectories) {
        # Check if we're operating on the top-level directory of a component or have recursed into a
        # subdirectory. If the latter, we need the relative path from the top-level directory so we
        # can adjust the target installation directory appropriately. Further, subdirectories may be
        # ignored by an <IgnorePaths> configuration, so also check this before proceeding further.
        if ($SourceDirectory.FullName -eq $SourcePath.FullName) {
            $TargetDirectory = $InstallPath

            # We need to check the source directory does actually exist. There are some edge cases
            # where this may not be the case, with a common case being an invalid BasePath setting.
            $SourceDirectory = Get-Item -Path $SourcePath.FullName -Force -ErrorAction Ignore
            if ($SourceDirectory -isnot [IO.DirectoryInfo]) {
                $Results.Add($false)
                Write-Error -Message ('[{0}] Unable to retrieve source directory: {1}' -f $Name, $SourcePath.FullName)
                continue
            }
        } else {
            $SourceDirectoryRelative = $SourceDirectory.FullName.Substring($SourcePath.FullName.Length + 1)

            if ($SourceDirectoryRelative -in $GlobalIgnorePaths -or
                $SourceDirectoryRelative -in $Component.IgnorePaths) {
                Write-Debug -Message ('[{0}] Ignoring directory: {1}' -f $Name, $SourceDirectoryRelative)
                continue
            }

            $TargetDirectory = Join-Path -Path $InstallPath -ChildPath $SourceDirectoryRelative
        }

        # We've got the directory source and target paths and have confirmed the source path is not
        # ignored. Start by trying to retrieve any item which may already exist at the target path.
        try {
            $ExistingTarget = Get-Item -Path $TargetDirectory -Force -ErrorAction Stop
        } catch {
            if (!$Simulate) {
                Write-Warning -Message ('[{0}] Expected a directory but found nothing: {1}' -f $Name, $TargetDirectory)
            }
            continue
        }

        # We found an item but it's not a directory! This is unexpected, but as we're removing a
        # component it's not an error. It will break if the user attempts to install it though.
        if ($ExistingTarget -isnot [IO.DirectoryInfo]) {
            if (!$Simulate) {
                Write-Warning -Message ('[{0}] Expected a directory but found a file: {1}' -f $Name, $TargetDirectory)
            }
            continue
        }

        # We found a symbolic link. Either:
        # - It points where we expect -> remove it
        # - It points somewhere else -> recurse into it (AllowNestedSymlinks)
        # - It points somewhere unexpected -> unable to remove this path element
        if ($ExistingTarget.LinkType -eq 'SymbolicLink') {
            $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

            # The symlink points somewhere other than the expected target. If nested symlinks
            # are permitted we'll recurse into it. Otherwise, this could be completely fine or
            # an error. We won't remove it so just warn the user of this potential issue.
            if ($SourceDirectory.FullName -ne $SymlinkTarget) {
                if ($AllowNestedSymlinks) {
                    if (!$Simulate) {
                        Write-Verbose -Message ('[{0}] Recursing into existing symlink with target: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
                    }
                } else {
                    if (!$Simulate) {
                        Write-Warning -Message ('[{0}] Found a directory symlink to an unexpected target: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SymlinkTarget)
                    }
                    continue
                }
            } else {
                # The symlink points where we expect so we're good to proceed with its removal
                if ($Simulate) {
                    Write-Verbose -Message ('[{0}] Will remove directory symlink: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SourceDirectory.FullName)
                } else {
                    Write-Verbose -Message ('[{0}] Removing directory symlink: "{1}" -> "{2}"' -f $Name, $TargetDirectory, $SourceDirectory.FullName)

                    # Remove-Item doesn't correctly handle deleting directory symbolic links
                    # See: https://github.com/PowerShell/PowerShell/issues/621
                    [IO.Directory]::Delete($TargetDirectory)
                }

                $Results.Add($true)
                continue
            }
        }

        # We found a regular directory or a directory symlink to an unexpected target. As we
        # can't remove the directory recurse into it looking for file symlinks to remove.
        $NextFiles = Get-ChildItem -Path $SourceDirectory.FullName -File -Force
        if ($NextFiles) {
            if ($Simulate) {
                $Result = Remove-DotFilesComponentFile -Component $Component -SourceFiles $NextFiles -Simulate
            } else {
                $Result = Remove-DotFilesComponentFile -Component $Component -SourceFiles $NextFiles
            }

            $Results.AddRange($Result)
        }

        # As above, but now for directory symlinks
        $NextDirectories = Get-ChildItem -Path $SourceDirectory.FullName -Directory -Force
        if ($NextDirectories) {
            if ($Simulate) {
                $Result = Remove-DotFilesComponentDirectory -Component $Component -SourceDirectories $NextDirectories -Simulate
            } else {
                $Result = Remove-DotFilesComponentDirectory -Component $Component -SourceDirectories $NextDirectories
            }

            $Results.AddRange($Result)
        }
    }

    return , $Results
}

Function Remove-DotFilesComponentFile {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [Component]$Component,

        [Parameter(Mandatory)]
        [IO.FileInfo[]]$SourceFiles,

        [Switch]$Simulate
    )

    # Beware: This function is called recursively!

    $Name = $Component.Name
    $SourcePath = $Component.SourcePath
    $InstallPath = $Component.InstallPath
    $Results = [Collections.Generic.List[Boolean]]::new()

    foreach ($SourceFile in $SourceFiles) {
        # We always need to determine the relative path of files from the top-level directory of the
        # component so we can adjust the target installation path appropriately.
        $SourceFileRelative = $SourceFile.FullName.Substring($SourcePath.FullName.Length + 1)

        # Like directories, files may also be ignored by an <IgnorePaths> configuration.
        if ($SourceFileRelative -in $GlobalIgnorePaths -or
            $SourceFileRelative -in $Component.IgnorePaths) {
            Write-Debug -Message ('[{0}] Ignoring file: {1}' -f $Name, $SourceFileRelative)
            continue
        }

        Write-Debug -Message ('[{0}] Processing file: {1}' -f $Name, $SourceFileRelative)
        $TargetFiles = [Collections.Generic.List[String]]::new()

        # Determine additional target symlink paths.
        if ($Component.AdditionalPaths.ContainsKey($SourceFileRelative)) {
            foreach ($AdditionalPath in $Component.AdditionalPaths[$SourceFileRelative]) {
                $TargetFile = Join-Path -Path $InstallPath -ChildPath $AdditionalPath
                Write-Debug -Message ('[{0}] Adding additional path: {1}' -f $Name, $TargetFile)
                $TargetFiles.Add($TargetFile)
            }
        }

        # Determine the target symlink with reference to any defined renamed path.
        if ($Component.RenamePaths.ContainsKey($SourceFileRelative)) {
            $TargetFile = Join-Path -Path $InstallPath -ChildPath $Component.RenamePaths[$SourceFileRelative]
            Write-Debug -Message ('[{0}] Using renamed target path: {1}' -f $Name, $TargetFile)
        } else {
            $TargetFile = Join-Path -Path $InstallPath -ChildPath $SourceFileRelative
            Write-Debug -Message ('[{0}] Using target path: {1}' -f $Name, $TargetFile)
        }
        $TargetFiles.Add($TargetFile)

        foreach ($TargetFile in $TargetFiles) {
            # We've got the file source and target paths and have confirmed the source path is not
            # ignored. Start by trying to retrieve any item which may already exist at the target path.
            try {
                $ExistingTarget = Get-Item -Path $TargetFile -Force -ErrorAction Stop
            } catch {
                if (!$Simulate) {
                    Write-Warning -Message ('[{0}] Expected a file but found nothing: {1}' -f $Name, $TargetFile)
                }
                continue
            }

            # We found an item but it's not a file! This is unexpected, but as we're removing a
            # component it's not an error. It will break if the user attempts to install it though.
            if ($ExistingTarget -isnot [IO.FileInfo]) {
                if (!$Simulate) {
                    Write-Warning -Message ('[{0}] Expected a file but found a directory: {1}' -f $Name, $TargetFile)
                }
                continue
            }

            # We found a file but it's not a symbolic link! Like the above, this is unexpected but
            # as we're removing a component we'll just warn the user (though an install won't work).
            if ($ExistingTarget.LinkType -ne 'SymbolicLink') {
                if (!$Simulate) {
                    Write-Warning -Message ('[{0}] Found a file instead of a symbolic link: {1}' -f $Name, $TargetFile)
                }
                continue
            }

            # We found a symbolic link. Either it points where we expect it to and we'll remove it,
            # or it points somewhere unexpected, and the user will need to investigate why that is.
            $SymlinkTarget = Get-SymlinkTarget -Symlink $ExistingTarget

            # The symlink points to an unexpected target. This could be an error or completely fine.
            # As we won't make any changes warn the user and let them decide what to do.
            if ($SourceFile.FullName -ne $SymlinkTarget) {
                if (!$Simulate) {
                    Write-Warning -Message ('[{0}] Found a file symlink to an unexpected target: "{1}" -> "{2}"' -f $Name, $TargetFile, $SymlinkTarget)
                }
                continue
            }

            # The symlink points where we expect so we're good to proceed with its removal
            if ($Simulate) {
                Write-Verbose -Message ('[{0}] Will remove file symlink: "{1}" -> "{2}"' -f $Name, $TargetFile, $SourceFile.FullName)
            } else {
                Write-Verbose -Message ('[{0}] Removing file symlink: "{1}" -> "{2}"' -f $Name, $TargetFile, $SourceFile.FullName)
                Remove-Item -Path $TargetFile -Force
            }

            $Results.Add($true)
        }
    }

    return , $Results
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

    if ($RefreshInstalledPrograms) {
        Write-Verbose -Message 'Refreshing installed programs ...'
        $Script:InstalledPrograms = Get-InstalledPrograms

        if (Get-Module -Name Appx -ListAvailable) {
            if ($IsAppxCompatNeeded) {
                Write-Verbose -Message 'Loading Appx module in Windows PowerShell session ...'
                Import-Module -Name Appx -UseWindowsPowerShell -WarningAction Ignore -Verbose:$false
            }

            Write-Verbose -Message 'Refreshing installed app packages ...'
            $AppPackages = Get-AppxPackage
            $Script:InstalledPrograms += $AppPackages
            Write-Debug -Message ('Found {0} app packages.' -f ($AppPackages | Measure-Object).Count)
        } else {
            Write-Verbose -Message 'Not retrieving app packages as Appx module not available.'
        }

        $Script:RefreshInstalledPrograms = $false
    }

    $Parameters = @{
        Property = 'Name'
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

    $MatchingPrograms = @($InstalledPrograms | Where-Object @Parameters)

    return , $MatchingPrograms
}

Function Get-ComponentInstallResult {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Collections.Generic.List[Boolean]]$Results,

        [Switch]$Removal
    )

    if ($Results.Count) {
        $TotalResults = $Results.Count
        $SuccessCount = ($Results | Where-Object { $_ -eq $true } | Measure-Object).Count
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
        }

        return [InstallState]::PartialInstall
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

    if (!$SkipMetadataSchemaChecks) {
        $Metadata.Schemas = $MetadataSchema
        try {
            $Metadata.Validate($null)
        } catch {
            Write-Warning -Message ('Unable to validate metadata file: {0}' -f $Path)
            throw $_
        }
    }

    return $Metadata
}

Function Get-DotFilesComponent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [IO.DirectoryInfo]$Directory
    )

    $Name = $Directory.Name
    $MetadataFile = '{0}.xml' -f $Name

    $GlobalMetadataFile = Join-Path -Path $GlobalMetadataPath -ChildPath $MetadataFile
    $GlobalMetadataPresent = Test-Path -Path $GlobalMetadataFile -PathType Leaf

    $CustomMetadataFile = Join-Path -Path $DotFilesMetadataPath -ChildPath $MetadataFile
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

            # TODO: Merge metadata so we can call Initialize-DotFilesComponent once
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param()

    $ComputerNativeRegPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    $ComputerWow64RegPath = 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    $UserRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'

    $UninstallKeys = Get-ChildItem -Path $ComputerNativeRegPath
    if (Test-Path -Path $ComputerWow64RegPath -PathType Container) {
        $UninstallKeys += Get-ChildItem -Path $ComputerWow64RegPath
    }
    if (Test-Path -Path $UserRegPath -PathType Container) {
        $UninstallKeys += Get-ChildItem -Path $UserRegPath
    }

    $InstalledPrograms = [Collections.ArrayList]::new()
    foreach ($UninstallKey in $UninstallKeys) {
        $Program = Get-ItemProperty -Path $UninstallKey.PSPath

        if (!$Program.PSObject.Properties['DisplayName']) {
            continue
        }

        if (!($Program.PSObject.Properties['UninstallString'] -or ($Program.PSObject.Properties['NoRemove'] -and $Program.NoRemove -eq 1))) {
            continue
        }

        if ($Program.PSObject.Properties['ParentKeyName'] -or $Program.PSObject.Properties['ParentDisplayName']) {
            continue
        }

        if ($Program.PSObject.Properties['SystemComponent'] -and $Program.SystemComponent -eq 1) {
            continue
        }

        if ($Program.PSObject.Properties['ReleaseType']) {
            continue
        }

        $InstalledProgram = [PSCustomObject]@{
            Name = $Program.DisplayName
        }

        $null = $InstalledPrograms.Add($InstalledProgram)
    }

    Write-Debug -Message ('Found {0} installed programs.' -f ($InstalledPrograms | Measure-Object).Count)
    return , $InstalledPrograms
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

    # The type of the Target property differs by PowerShell version:
    # -  <7: A String[] with a single element
    # - >=7: A String
    if ($Symlink.Target -is [Array]) {
        $Target = $Symlink.Target[0]
    } else {
        $Target = $Symlink.Target
    }

    $IsAbsolute = [IO.Path]::IsPathRooted($Target)
    if ($IsAbsolute) {
        return $Target
    }

    return (Resolve-Path -Path (Join-Path -Path (Split-Path -Path $Symlink -Parent) -ChildPath $Target)).Path
}

Function New-Symlink {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(Mandatory)]
        [String]$Target
    )

    if (!($IsAdministrator -or $IsWin10DevMode)) {
        throw 'Missing symbolic link creation privileges.'
    }

    if (!$IsMkLinkNeeded) {
        try {
            $Symlink = New-Item -ItemType SymbolicLink -Path $Path -Value $Target -ErrorAction Stop
        } catch {
            throw $_
        }
    } else {
        $TargetItem = Get-Item -Path $Target
        $QuotedPath = '"{0}"' -f $Path
        $QuotedTarget = '"{0}"' -f $Target

        if ($TargetItem -is [IO.FileInfo]) {
            Start-Process -FilePath cmd.exe -ArgumentList @('/D', '/C', 'mklink', $QuotedPath, $QuotedTarget, '>nul') -NoNewWindow -Wait
        } elseif ($TargetItem -is [IO.DirectoryInfo]) {
            Start-Process -FilePath cmd.exe -ArgumentList @('/D', '/C', 'mklink', '/D', $QuotedPath, $QuotedTarget, '>nul') -NoNewWindow -Wait
        } else {
            throw ('Symlink target is not a file or directory: {0}' -f $Target)
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Warning -Message ('mklink returned unexpected exit code: {0}' -f $LASTEXITCODE)
        }

        try {
            $Symlink = Get-Item -Path $Path -ErrorAction Stop
        } catch {
            throw ('Expected symlink from mklink invocation not found: {0}' -f $Path)
        }
    }

    return $Symlink
}

Function Set-SymlinkAttributes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
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

    try {
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
    } catch {
        return $false
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

Function Test-IsAppxCompatNeeded {
    [CmdletBinding()]
    Param()

    # PowerShell 7.1 introduced a breaking change which results in the Appx module failing to load.
    # The workaround is to import the module using Windows Powershell compatibility. This does have
    # side-effects as it means objects are serialised as they're returned to the PowerShell session.
    # Fortunately, our usage of the module should mean none of these effects will have any impact.
    #
    # See: https://github.com/PowerShell/PowerShell/issues/13138
    $AffectedVersion = [Version]::new(7, 1)
    if ($PSVersionTable.PSVersion -ge $AffectedVersion) {
        return $true
    }

    return $false
}

Function Test-IsMkLinkNeeded {
    [CmdletBinding()]
    Param()

    # The support for creating symlinks without Administrator privileges depends on passing a new
    # flag to the CreateSymbolicLink() API call. PowerShell didn't become aware of this flag until
    # the PowerShell Core 6.2 release. Prior versions will fail to create symlinks on calling the
    # New-Item command as the necessary flag won't be set.
    #
    # The workaround is to call mklink which is a built-in cmd command. It's *much* slower, as each
    # symlink to create requires a separate process launch. That's still preferable though to not
    # working at all. Currently no Windows version ships with a PowerShell release with the support.
    #
    # See: https://github.com/PowerShell/PowerShell/pull/8534
    if (!$IsAdministrator) {
        $MinPoshVersion = [Version]::new(6, 2)
        if ($PSVersionTable.PSVersion -lt $MinPoshVersion) {
            return $true
        }
    }

    return $false
}

Function Test-IsWin10DevMode {
    [CmdletBinding()]
    Param()

    # Windows 10 Creators Update introduced support for creating symlinks without Administrator
    # privileges. The underlying support was introduced in Windows Insider Preview Build 14972.
    $BuildNumber = [Int](Get-CimInstance -ClassName Win32_OperatingSystem -Verbose:$false).BuildNumber
    if ($BuildNumber -lt 14972) {
        return $false
    }

    # Check if Developer Mode is enabled which permits unprivileged users to create symlinks
    $DevModeKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    if (Test-Path -Path $DevModeKey -PathType Container) {
        $DevMode = Get-ItemProperty -Path $DevModeKey

        if ($DevMode.PSObject.Properties['AllowDevelopmentWithoutDevLicense']) {
            if ($DevMode.AllowDevelopmentWithoutDevLicense -eq 1) {
                return $true
            }
        }
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
    # - Additional files have been added since it was last installed
    # - A previous installation attempt was only partially successful
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
    # The directory name within the dotfiles directory
    [String]$Name

    # Source directory derived from $DotFilesPath and $Name
    [IO.DirectoryInfo]$SourcePath

    # Friendly name if one was provided or could be determined
    [String]$FriendlyName

    # The availability state per the Availability enumeration
    [Availability]$Availability = [Availability]::DetectionFailure

    # The install state per the InstallState enumeration
    [InstallState]$State = [InstallState]::NotEvaluated

    # Installation directory
    # Note: Influenced by the <SpecialFolder> and <Destination> elements
    [String]$InstallPath

    # Hides newly created symlinks per the <HideSymlinks> element
    [Boolean]$HideSymlinks

    # Source paths to be ignored
    # Note: Set by <Path> elements under <IgnorePaths>
    [String[]]$IgnorePaths

    # Source paths with additional target symlink paths
    # Note: Set by <AdditionalPath> elements under <AdditionalPaths>
    [Hashtable]$AdditionalPaths = @{ }

    # Source paths with renamed target symlink paths
    # Note: Set by <RenamePath> elements under <RenamePaths>
    [Hashtable]$RenamePaths = @{ }

    Component ([String]$Name, [IO.DirectoryInfo]$DotFilesPath) {
        $this.Name = $Name
        $this.SourcePath = Get-Item -Path (Resolve-Path -Path (Join-Path -Path $DotFilesPath -ChildPath $Name))
    }

    [String] ToString() {
        return 'PSDotFiles: {0}' -f $this.Name
    }
}
