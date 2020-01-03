PSDotFiles
==========

A simple *dotfiles* management framework for Windows built on PowerShell.

Purpose
-------

PSDotFiles aims to provide a simple yet powerful and flexible framework for managing your dotfiles on Windows systems. The design is heavily influenced by [GNU Stow](https://www.gnu.org/software/stow/), which works by symlinking the contents of one or more folders into another folder. In this way, a collection of dotfiles can be easily divided into per-application folders (e.g. `git`, `sublime`, `vim`, etc...).

PSDotFiles implements this basic design but with a PowerShell-centric approach using a simple set of cmdlets.

Requirements
------------

- PowerShell 5.0 (or later)

Installing
----------

### PowerShellGet

The latest release of the module is published to the [PowerShell Gallery](https://www.powershellgallery.com/) for installation via the [PowerShellGet module](https://www.powershellgallery.com/GettingStarted):

```posh
Install-Module -Name PSDotFiles
```

You can find the module listing [here](https://www.powershellgallery.com/packages/PSDotFiles).

### ZIP File

Download the [ZIP file](https://github.com/ralish/PSDotFiles/archive/stable.zip) of the latest release and unpack it to one of the following locations:

- Current user: `C:\Users\<your.account>\Documents\WindowsPowerShell\Modules\PSDotFiles`
- All users: `C:\Program Files\WindowsPowerShell\Modules\PSDotFiles`

### Git Clone

You can also clone the repository into one of the above locations if you'd like the ability to easily update it via Git.

### Did it work?

You can check that PowerShell is able to locate the module by running the following at a PowerShell prompt:

```posh
Get-Module PSDotFiles -ListAvailable
```

Quickstart
----------

The module exports three commands through which all dotfiles management occurs:

```posh
# Enumerates available dotfiles components
Get-DotFiles

# Installs one or more dotfiles components
Install-DotFiles

# Removes one or more dotfiles components
Remove-DotFiles
```

All commands have built-in help and examples which can be accessed with `Get-Help <command>`.

Only `Install-DotFiles` and `Remove-DotFiles`  will modify your system by creating or removing the appropriate symlinks.

Both `Install-DotFiles` and `Remove-DotFiles` support PowerShell's standard `-WhatIf` and `-Confirm` parameters.

Folder Structure
----------------

PSDotFiles expects a dotfiles folder to be structured as multiple folders each containing the files and folders comprising a particular application's configuration. These top-level folders are referred to by PSDotFiles as **components**. The files and folders in each component's folder should be relative to a well-known top-level folder (e.g. your profile folder, which is the default target in PSDotFiles). The actual list of well-known folders are those in the [`Environment.SpecialFolder`](https://docs.microsoft.com/en-us/dotnet/api/system.environment.specialfolder) enumeration.

A simple dotfiles folder structure might look like this:

```fundamental
dotfiles
| --- clink
   | --- clink_inputrc
   | --- settings
| --- conemu
   | --- ConEmu.xml
| --- git
   | --- .gitattributes
   | --- .gitconfig
   | --- .gitignore
| --- posh
   | --- Modules
      | --- MyModule
         | --- MyModule.psm1
   | --- profile.ps1
| --- vim
   | --- .vimrc
```

Configuring
-----------

Before you can use PSDotFiles you should set the `$DotFilesPath` variable to the location of your dotfiles folder. For example:

```posh
$DotFilesPath = "C:\Users\<your.account>\dotfiles"
```

So that you don't have to enter this into every new PowerShell session it's a good idea to add this to your PowerShell profile:

- All PowerShell hosts (including the ISE): `$HOME\Documents\WindowsPowerShell\profile.ps1`
- Only the **Microsoft.PowerShell** shell: `$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`

If you're unsure which to use, just choose the first.

Troubleshooting
---------------

Encountering unexpected behaviour or other problems? You may wish to run the problematic command with the `-Verbose` parameter for more details. You can also add the `-Debug` parameter for even more details on the command processing.

If you think you've found a bug please consider [opening an issue](https://github.com/ralish/PSDotFiles/issues) so that I can look into it and hopefully get it fixed!

License
-------

All content is licensed under the terms of [The MIT License](LICENSE).
