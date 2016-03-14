if(!$script:PSDotFiles) {
    Write-Warning "You appear to be running a PSDotFiles template script directly instead of via the PSDotFiles module."
}

Class Component {
    [String]$Name
    [String]$FriendlyName = ""
    [Availability]$Availability
    [String]$Installed = ""

    Component([String]$Name, [Availability]$Availability) {
        $this.Name = $Name
        $this.Availability = $Availability
    }
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
