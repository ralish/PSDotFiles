Changelog
=========

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
