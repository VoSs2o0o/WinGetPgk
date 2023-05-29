# WinGet

This Module contains a Resource and Provider to install Software via Winget.

## Usage

Simply use the Resource like this:

   wingetpkg {'Microsoft.PowerToys':
      ensure => present,
      version => 'latest',
   }

The title of the Resource is the id of the Winget package

## Setup

Of course you will need Windows for that, and an installed and working Winget-Command.
Maybe you can install it on older Versions, but Winget is includes in Windows since
Windows 10 1709 (Build 16299). You can download and install it manually via 
[Github Releases]https://github.com/microsoft/winget-cli/releases).
 
## Reference

The following Options exists:

ensure => :present, :installed, :absent
version => <version> or 'latest'

Optional:

fastupgrade => (default: 'yes') 
Use this Param with 'no' to turn of the Upgrade-Command of WinGet. This makes sence for example for 
the "Visual C Redistibutables", which creates dublicates on update. Also Some Packages reports
an incompatible installer for upgrade. With this Option you have a workaround.

   wingetpkg {'Microsoft.VCRedist.2013.x64':
      ensure => present,
      version => 'latest',
      fastupgrade: 'no'
   }


## Limitations

Please keep in mind that winget is not really stable, but usable. I have seen a lot of problem 
related to winget as i have developed this Module.

