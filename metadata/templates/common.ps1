if(!$script:PSDotFiles) {
    Write-Warning "You appear to be running a PSDotFiles template script directly instead of via the PSDotFiles module."
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
    # OPTIONAL: Friendly name if one was provided or could be located
    [String]$FriendlyName = ""
    # REQUIRED: The availability state per the Availability enumeration
    [Availability]$Availability = [Availability]::DetectionFailure
    # IGNORE: This will be set automatically during later install detection
    [String]$Installed = ""
    # OPTIONAL: Uninstall Registry key (typically set by Find-DotFilesComponent)
    [String]$UninstallKey

    Component([String]$Name) {
        $this.Name = $Name
    }

    Component([String]$Name, [Availability]$Availability) {
        $this.Name = $Name
        $this.Availability = $Availability
    }
}
