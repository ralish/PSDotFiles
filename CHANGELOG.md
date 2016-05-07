Changelog
=========

## v0.4.4

- Add support for new detection method: `PathExists`
- Rename the `<FindBinary>` element to `<FindInPath>` for consistency
- Clean-up comments for the detection methods in the sample XML file
- Remove redundant check for valid known component detection method

## v0.4.3

- Add support for new detection method: `FindInPath`
- Remove the list view definition for the `PSDotFiles.Component` type

## v0.4.2

- Support the case where `$DotFilesPath` or `-Path` is itself a symlink
- Add a proper changelog for tracking version changes

## v0.4.1

- Added check in `Install-DotFiles` for Administrator privileges
- Numerous minor documentation improvements

## v0.4

- Initial stable release