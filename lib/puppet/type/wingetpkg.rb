Puppet::Type.newtype(:wingetpkg) do

  desc 'WinGet is an Installer for the WinGet Windows Package Manager.'

  feature :versionable, "Package manager interrogate and return software version.", :methods => [:version]

  ensurable

  newparam(:name, :namevar => true) do
    desc 'The name of the software package.'
  end

  newparam(:fastupgrade) do
    desc 'Fast upgrade to "latest" version.'
    defaultto :yes
    newvalues(:yes, :no)
  end

  newproperty(:version, :required_features => :versionable) do
    desc 'version of a package that should be installed'
    validate do |value|
      fail("Invalid version #{value}") unless value =~ /^[0-9A-Za-z\.-]+$/
    end
  end

end
