require 'puppet/util/execution'

Puppet::Type.type(:wingetpkg).provide(:winget) do

  confine    :osfamily => :windows
  defaultfor :osfamily => :windows


  # commands :wget => 'c:\\Program Files\\WindowsApps\\Microsoft.DesktopAppInstaller_1.20.441.0_x64__8wekyb3d8bbwe\\winget.exe'

  mk_resource_methods
  debug("wingetprovider->init")

  ALL_COL_SPLITS = 6
  BUGGY_COL_SPLITS = 5

  def self.prefetch(resources)
    debug("wingetprovider->self.prefetch")
    packages = instances
    resources.keys.each do |name|
      if (provider = packages.find { |pkg| pkg.name == name })
        resources[name].provider = provider
      end
    end
  end

  def self.instances
    debug("wingetprovider->self.instances")
    packages = self._get_packages

    packages.each do |pkg|
      if pkg[:version].downcase == 'unknown'
        match = pkg[:fullname].match /.+? .*(\d+\.\d+(\.\d+){1,2})/
        if match
          pkg[:version] = match[1]
          pkg[:orgversion] = match[1]
        end
      end
      
      if pkg[:latestver] == "" or pkg[:latestver] == pkg[:version]
        pkg[:version] = "latest"
      end
    end

    return packages.collect { |pkg| new(pkg)}
  end

  def create
    debug("wingetprovider->create")
    notice(">>Install package.")
    if resource[:version] and resource[:version] != "latest" and resource[:version] != "installed"
      self.class._wgetexec('install', '--disable-interactivity', '--silent', '--accept-package-agreements', "--exact", "--id", resource[:name], "--version",  resource[:version])
    else
      self.class._wgetexec('install', '--disable-interactivity', '--silent', '--accept-package-agreements', "--exact", "--id", resource[:name])
    end
    @property_hash[:ensure] = :present
  end

  def version=(value)
    debug("wingetprovider->version=(value)")
    if @property_hash[:ensure] == :present and resource[:version] == 'installed'
      debug("already installed.")
      return
    end
    if _pkg_exists?(resource[:name], value)
      if (@property_hash[:ensure] == :present or @property_hash[:version] == "Unknown") and resource[:version] == "latest" \
          and resource[:fastupgrade] == :yes #fastupgrade, upgdating app
        notice(">>Upgrade package.")
        _do_upgrade
        @property_hash[:version] = value
      else  #do an uninstall, cause sometimes installer incompatible
        if @property_hash[:version] == "Unknown"
          warning("From Unknown -> #{value} not possible, use 'latest' with 'fastupgrade' or do it manually.")
          return
        end
        if @property_hash[:orgversion] == value #check without 'latest'
          return
        end
        notice(">>change package from #{@property_hash[:version]} to #{value}...")
        destroy
        @property_hash[:version] = value
        create
      end
    else
      err("Invalid id #{resource[:name]} or version #{resource[:version]}")
    end
  end


  def destroy
    debug("wingetprovider->destroy")
    notice(">>Uninstall package.")
    self.class._wgetexec('uninstall', '--disable-interactivity', '--accept-source-agreements', "--id",  resource[:name],"--exact")
    @property_hash[:ensure] = :absent
  end

  def exists?
    debug("wingetprovider->exists?")
    if @property_hash[:ensure]
      debug(@property_hash[:ensure] == :present)
    else
      debug("false")
    end
    if @property_hash[:version]
      debug("version: " + @property_hash[:version])
    end
    @property_hash[:ensure] == :present
  end

  private

  def self._get_packages
    debug("wingetprovider->self._get_packages")
    raw_packages = _wgetexec('list','--disable-interactivity', '--accept-source-agreements')

    col_cfg = _get_columnconfig(raw_packages)
    if col_cfg.length < BUGGY_COL_SPLITS
      err("Cannot read results from WinGet!")
    end

    packages = _get_rawpackages(raw_packages, col_cfg)
    if col_cfg.length >= ALL_COL_SPLITS
      #return packages.collect { |package| new(package)}
      return packages
    end

    #due to a bug, read updates separately
    raw_upgrades = _wgetexec('upgrade','--disable-interactivity', '--include-unknown')
    col_upgrade_cfg = _get_columnconfig(raw_upgrades)
    if col_upgrade_cfg == 0
      return packages
    end

    if col_upgrade_cfg.length  < ALL_COL_SPLITS
      err("Cannot read results from WinGet!")
    end

    upgrade_packages = _get_rawpackages(raw_upgrades, col_upgrade_cfg)
    upgrade_packagesh = upgrade_packages.to_h do |package|
      [package[:name], package]
    end

    result = packages.collect do |package|
      if upgrade_packagesh.key?(package[:name])
        package[:latestver] = upgrade_packagesh[package[:name]][:latestver]
      end

      package
    end

    result
  end

  def self._winget_path
    install_location = nil
    regkeyf = 'SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WinGet.exe'
    begin
      Win32::Registry::HKEY_LOCAL_MACHINE.open(regkeyf) do |regkey|
        install_location = regkey["Path"]
      end
    rescue
      install_location = ""
    end
    if install_location == ""
      begin
        Win32::Registry::HKEY_CURRENT_USER.open(regkeyf) do |regkey|
          install_location = regkey["Path"]
        end
      rescue
        fail("Winget install_location not found!")
      end
    end
    debug("Winget install_location: '#{install_location}'")

    File.join(install_location.to_s, "winget.exe")
  end

  def self._wgetexec(*args)
    cmd = [self._winget_path] + args
    debug("Execcmd: " + cmd.to_s)
    output = execute(cmd)

    output = output.force_encoding('UTF-8')
    output.gsub("…", " ")
  end

  def _pkg_exists?(id, version="")
    debug("wingetprovider->pkg_exists?")

    if version != "" and version != "latest"
      pkgresult = self.class._wgetexec("show", "--accept-source-agreements", "--id", id, "--version", version)
    else
      if @property_hash[:ensure] == :present
        return true
      end
      pkgresult = self.class._wgetexec("show", "--accept-source-agreements", "--id", id)
    end
    pkgresult.split("\n") do |line|
      if line.index(id) != nil
        return true
      end
      return false
    end
  end

  def _do_upgrade
    self.class._wgetexec('upgrade', '--disable-interactivity', '--silent', '--accept-package-agreements', "--exact", "--include-unknown", "--id", resource[:name])
  end

  def self._get_columnconfig(cmdresult)
    debug("wingetprovider->_get_columnconfig")

    result = []
    cmdresult.split("\n").collect do |line|
      match = line.match(/(\w+\s+)(\w+\s+)(\w+\s+)([a-zA-Zü]+\s+)(\w+)$/)
      match2 = line.match(/(\w+\s+)(\w+\s+)(\w+\s+)(\w+)$/)
      if match or match2
        match.captures.each do |capture|
          if result.length == 0
            result.append(0)
            result.append(capture.length)
          else
            result.append(result[-1] + capture.length)
          end
        end

        return result
      end
    end
  end

  def self._get_rawpackages(cmdresult, col_cfg)
    debug("wingetprovider->_get_rawpackages")
    skipped_header = false
    result = []
    cmdresult.split("\n").collect do |line|
      if line.start_with?("-") and line.end_with?("-")
        skipped_header = true
        next
      end
      if line.end_with?(".")
        break
      end
      unless skipped_header
        next
      end

      #debug("line: #{line}")
      fullname = line[col_cfg[0]..col_cfg[1]-1].to_s.strip
      name = line[col_cfg[1]..col_cfg[2]-1].to_s.strip
      version = line[col_cfg[2]..col_cfg[3]-1].to_s.strip
      version = version.gsub(">", "")
      version = version.gsub("<", "")
      if col_cfg.length >= ALL_COL_SPLITS
        avail = line[col_cfg[3]..col_cfg[4]-1].to_s.strip
        source = line[col_cfg[4]..col_cfg[5]-1].to_s.strip
      else
        avail = ""
        source = line[col_cfg[3]..col_cfg[4]-1].to_s.strip
      end
      if source == ""
        next
      end

      result.append({:name   => name,
                     :fullname => fullname,
                     :ensure => :present,
                     :version => version,
                     :orgversion => version,
                     :latestver => avail,
                    })
    end
    #debug("end")
    result
  end
end

