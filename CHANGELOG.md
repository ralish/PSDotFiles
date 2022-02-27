Changelog
=========

v0.9.7
------

- Explicitly check if the `ToInstall`/`ToRemove` array is empty
- Simplify several `Where-Object` clauses

v0.9.6
------

- Add progress bar support to all commands

v0.9.5
------

- Fix incorrect handling of `$DotFilesAllowNestedSymlinks` preference

v0.9.4
------

- Add workaround for failure to import `Appx` module under PowerShell 7.1
- Fix potentially incorrect verbose output on nested symlinks state
- Miscellaneous code style changes & development tooling updates

v0.9.3
------

- Add documentation on global variables
- Add support for global ignore paths via `$DotFilesGlobalIgnorePaths`
- Switch most arrays to `Collections.Generic.List<T>` types
- Performance optimisations around array use

v0.9.2
------

- Populate most `Component` metadata even when not available
- Handle failure to set symlink attributes when hidden
- Minor documentation updates & miscellaneous fixes

v0.9.1
------

- Republishing with development files excluded to reduce package size
- Updates to module manifest to indicate platform & PowerShell support

v0.9
----

- Handle change of `Target` property type in `FileSystemInfo` under PowerShell 7
- Create symlinks natively via `New-Item` when unprivileged and PowerShell is 6.2+
- Correctly quote paths passed to `mklink` & improved associated error handling
- Update `FriendlyName` in `posh.xml` metadata definition to *Windows PowerShell*
- Use precise Windows build number when testing for unprivileged symlinks support

v0.8
----

- **Breaking Change**: Removed the `UninstallKey` property from the `Component` class
- Added support for enumerating app packages (*AppX*) during automatic component detection
- Treat multiple matches in automatic component detection as a warning (previously was error)
- `Remove-DotFiles`: Fixed stupid oversight introduced in *v0.7* which broke this command

v0.7
----

- Added new `<AdditionalPaths>` metadata element for additional target symlinks paths
- `Get-DotFiles`: Ensure an unpacked `Component` array is returned
- Miscellaneous refactoring & additional debug output

v0.6.1
------

- Correctly handle the case where `Get-DotFiles` returns an empty collection and warn the user

v0.6
----

- **Breaking Change**: The `<Path>` element under `<IgnorePaths>` is now `<IgnorePath>`
- Added new `<BasePath>` metadata element to specify a component subfolder as source path
- Added new `<RenamePaths>` metadata element to rename target symlink path by source file path
- Added global setting to disable XML metadata schema validation: `$DotFilesDisableMetadataSchemaChecks`

v0.5.3
------

- Add support for toggling nested symlink support via parameter: `-AllowNestedSymlinks`

v0.5.2
------

- Add support for handling nested symlinks (i.e. handling of symlinks not related to a component)

v0.5.1
------

- Ensure the parent directory of the target path exists when operating on the top-level directory of a component during an install operation

v0.5
----

- Added pipeline support to `Install-DotFiles` & `Remove-DotFiles` for handling `Component` objects
- Added support for unprivileged symlink creation under Windows 10 Creators Update Developer Mode
- Added schema definition for metadata XML files & perform validation of each metadata file on load
- Enabled Strict Mode set to version 2.0 (latest at time of writing)
- Major refactoring & clean-up of the codebase to conform to best practices
- Numerous documentation updates & improvements

v0.4.5
------

- Now licensed under The MIT License
- Minor changes to the module manifest
- Minor updates to module documentation

v0.4.4
------

- Add support for new detection method: `PathExists`
- Rename the `<FindBinary>` element to `<FindInPath>` for consistency
- Clean-up comments for the detection methods in the sample XML file
- Remove redundant check for valid known component detection method

v0.4.3
------

- Add support for new detection method: `FindInPath`
- Remove the list view definition for the `PSDotFiles.Component` type

v0.4.2
------

- Support the case where `$DotFilesPath` or `-Path` is itself a symlink
- Add a proper changelog for tracking version changes

v0.4.1
------

- Added check in `Install-DotFiles` for Administrator privileges
- Numerous minor documentation improvements

v0.4
----

- Initial stable release
