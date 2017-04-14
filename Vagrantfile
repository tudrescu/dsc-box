# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"
require "json"
require "uri"

require './plugins/vagrant-provision-reboot-plugin'

VAGRANTFILE_API_VERSION = "2"
DEFAULT_BOX = "ubuntu/trusty64"

DEFAULT_CONFIG = "Vagrantparams.yaml"

DEFAULT_SECOND_DISK_NAME = "second.vdi"
DEFAULT_DOMAIN_NAME = ".example.com"

# default main playbook to run by the bootstrap provisioner
DEFAULT_MAIN_PLAYBOOK = "main.yml"

# load custom user preferences -------------------------------------------------
config_file = ENV['CONFIG'] ? ENV['CONFIG'] : DEFAULT_CONFIG
vagrant_dir = File.expand_path(File.dirname(__FILE__))

config_path = vagrant_dir + "/" + config_file
if not File.exist?(config_path)
    abort "Could not find configuration #{config_path}"
end

prefs = YAML::load_file(config_path)

use_proxy = (prefs.has_key?('use_proxy') ? prefs['use_proxy'] : false)
vm_base_box = (prefs.has_key?('vm_base_box') ? prefs['vm_base_box'] : DEFAULT_BOX)
vm_base_box_url = (prefs.has_key?('vm_base_box_url') ? prefs['vm_base_box_url'] : "")
vm_base_box_version = (prefs.has_key?('vm_base_box_version') ? prefs['vm_base_box_version'] : ">= 0")

# install required plugins -----------------------------------------------------
install_vagrant_plugins = prefs.has_key?('install_vagrant_plugins') ? prefs['install_vagrant_plugins'].to_s : "true"
install_vagrant_plugins = ENV['INSTALL_VAGRANT_PLUGINS'] ? ENV['INSTALL_VAGRANT_PLUGINS'].to_s : install_vagrant_plugins

if install_vagrant_plugins == "true"

    required_plugins = %w(vagrant-proxyconf)
    plugins_to_install = required_plugins.select { |plugin| not Vagrant.has_plugin? plugin }
    if not plugins_to_install.empty?
        puts "Installing plugins: #{plugins_to_install.join(' ')}"
        if system "vagrant plugin install #{plugins_to_install.join(' ')}"
           exec "vagrant #{ARGV.join(' ')}"
        else
           abort "Installation of one or more plugins has failed. Aborting"
        end
    end

end

# check if vagrant-proxyconf installed successfully
vagrant_proxyconf_plugin_installed = Vagrant.has_plugin?("vagrant-proxyconf").to_s
puts "Using vagrant-proxyconf plugin : #{vagrant_proxyconf_plugin_installed}"


# Use only half of the available CPU/Memory resources if preferences exceed this threshold
available_vm_cpus = `nproc`.to_i
available_vm_memory = `grep 'MemTotal' /proc/meminfo | sed -e 's/MemTotal://' -e 's/ kB//'`.to_i / 1024

vm_cpus = available_vm_cpus / 2
if prefs.has_key?('vm_cpus')
  vm_cpus = prefs['vm_cpus'].to_i >=  vm_cpus ?  vm_cpus: prefs['vm_cpus']
end

vm_memory = available_vm_memory / 2
if prefs.has_key?('vm_memory')
  vm_memory = prefs['vm_memory'].to_i >=  vm_memory ?  vm_memory: prefs['vm_memory']
end

# configure extra vars ---------------------------------------------------------

extra_vars_hash = {:java_useproxy => use_proxy}

# add ansible extra variables to hash
if prefs.has_key?('ansible_extra_vars')

    # convert array into hash
    h = Hash[*prefs['ansible_extra_vars']]

    if h.is_a?(Hash)
      extra_vars_hash = extra_vars_hash.merge(h)
    end

end

# add extra vars from environment
user_extra_vars = ENV['EXTRA_VARS'] ? ENV['EXTRA_VARS'] : Array.new

unless user_extra_vars.nil? || user_extra_vars.empty?

  h = Hash[user_extra_vars.split(",").map!(&:strip).map {|item| item.split /\s*=\s*/}]
  # puts "Extra Vars: #{h}"

  if h.is_a?(Hash)
     extra_vars_hash = extra_vars_hash.merge(h)
  end

end


# load forwarded ports config --------------------------------------------------
vm_forwarded_ports = {}
if prefs.has_key?('vm_forwarded_ports')

  unless prefs['vm_forwarded_ports'].nil?

      h = Hash[prefs['vm_forwarded_ports'].map {|x| [x['description'], x]}]

      if h.is_a?(Hash)
        vm_forwarded_ports = vm_forwarded_ports.merge(h)
      end

  end

end
# puts "Forwarded Ports : #{vm_forwarded_ports}"

# load synced folders config ---------------------------------------------------
vm_synced_folders = {}
if prefs.has_key?('vm_synced_folders')

  unless prefs['vm_synced_folders'].nil?

      h = Hash[prefs['vm_synced_folders'].map {|x| [x['guest_path'], x]}]

      if h.is_a?(Hash)
        vm_synced_folders = vm_synced_folders.merge(h)
      end

  end

end

# load provisioners config -----------------------------------------------------
vm_provisioners = Array.new
if prefs.has_key?('vm_provisioners')

  unless prefs['vm_provisioners'].nil?

    vm_provisioners = prefs['vm_provisioners']

  end

end


# Extract DN and HTTPS forwarded port for VM Host for passing to provisioner ---
vm_host_name = Socket.gethostbyname(Socket.gethostname).first.downcase
vm_host_name = vm_host_name.sub(/#{Regexp.escape(DEFAULT_DOMAIN_NAME)}/, '')
puts "VM Host: #{vm_host_name}"

service_id, service_props = vm_forwarded_ports.select { |key, value| key.to_s.match(/.*https service/) }.first
https_forwarded_port = service_props.fetch('host', 40443)
# puts "#{https_forwarded_port}"

# add vm hostname infos
vm_host_infos = {:vm_host_name => vm_host_name.to_s,
                 :https_forwarded_port => https_forwarded_port.to_s}

extra_vars_hash = extra_vars_hash.merge(vm_host_infos)


# create a second virtual disk interface ---------------------------------------
add_virtual_disk = (prefs.has_key?('add_virtual_disk') ? prefs['add_virtual_disk'] : false)
virtual_disk_size = (prefs.has_key?('virtual_disk_size') ? prefs['virtual_disk_size'].to_i : 30)

file_to_disk = File.realpath( "." ).to_s + "/" + DEFAULT_SECOND_DISK_NAME
disk_size = virtual_disk_size * 1024


Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  # disable random keypair generation
  config.ssh.insert_key = false

  # set to false, if you do NOT want to check the correct VirtualBox Guest Additions version when booting this box
  if defined?(VagrantVbguest::Middleware)
    config.vbguest.auto_update = (prefs.has_key?('vbguest_auto_update') ? prefs['vbguest_auto_update'] : true)
    puts "Update VirtualBox Guest Additions : " + config.vbguest.auto_update.to_s
  end

  # configure proxyies for Vagrant, can be side stepped with java_useproxy: false in Vagrantparams.yml
  if (use_proxy)

    config_proxy_http = (prefs.has_key?('config_proxy_http') ? prefs['config_proxy_http'] : ENV['http_proxy'])
    config_proxy_https = (prefs.has_key?('config_proxy_https') ? prefs['config_proxy_https'] : ENV['https_proxy'])
    config_no_proxy  = (prefs.has_key?('config_no_proxy') ? prefs['config_no_proxy'] : ENV['no_proxy'])

    # proxy requested but the supplied variables or the enviroment variables are null, abort
    proxy_enviroment_ok = true
    if config_proxy_http.nil? || config_proxy_http.empty?
        puts "ERROR: http_proxy variable not defined or empty!"
        proxy_enviroment_ok = false
    end

    if config_proxy_https.nil? || config_proxy_https.empty?
        puts "ERROR: https_proxy variable not defined or empty!"
        proxy_enviroment_ok = false
    end

    if config_no_proxy.nil? || config_no_proxy.empty?
        puts "ERROR: no_proxy variable not defined or empty!"
        proxy_enviroment_ok = false
    end

    if not proxy_enviroment_ok
        abort "Proxy Enviroment is not configured! Check your ~/.bashrc and #{config_path}"
    end

    # configure proxy plugin if available
    if Vagrant.has_plugin?("vagrant-proxyconf")
       config.proxy.http      = config_proxy_http
       config.proxy.https     = config_proxy_https
       config.proxy.no_proxy  = config_no_proxy
    end

    # turn config_no_proxy into JAVA Networking noProxyHosts Format, i.e. localhost|127.0.0.1|*.domain
    java_noproxy_array = config_no_proxy.split(",", -1).map(&:strip)
    java_noproxy_array.map! { |x| x.start_with?('.') ? "*" + x : x }

    java_no_proxy_value = java_noproxy_array.join('|').to_s
    # puts "No Proxy : #{java_no_proxy_value}"

    http_proxy_url = URI.parse(config_proxy_http)

    # build ansible --extra-vars
    h = {:java_useproxy => use_proxy,
         :proxy_env => {:http_proxy => config_proxy_http,
                        :https_proxy => config_proxy_https,
                        :no_proxy => config_no_proxy},
         :java_proxy_host => http_proxy_url.host.to_s,
         :java_proxy_port => http_proxy_url.port.to_s,
         :java_no_proxy_host => java_no_proxy_value}

    extra_vars_hash = extra_vars_hash.merge(h)

  end

  ansible_extra_vars = JSON.generate(extra_vars_hash).to_s

  puts "-----------" * 5
  puts "Use proxy : " + use_proxy.to_s
  puts "VM Base box : " + vm_base_box.to_s
  puts "Assigned/Prefs/Available VM CPUs : " + vm_cpus.to_s + "/" + prefs['vm_cpus'].to_s + "/" + available_vm_cpus.to_s
  puts "Assigned/Prefs/Available VM Memory : " + vm_memory.to_s + "/" + prefs['vm_memory'].to_s + "/" + available_vm_memory.to_s + " MB"
  puts "Extra settings : " + ansible_extra_vars.to_s
  # puts "Second VDI Size : " + disk_size.to_s
  puts "-----------" * 5


  # configure provider ---------------------------------------------------------
  config.vm.box = vm_base_box
  config.vm.box_check_update = true

  unless vm_base_box_url.empty?
      config.vm.box_url = vm_base_box_url
      config.vm.box_check_update = true
      config.vm.box_version = vm_base_box_version
  end

  # configure port forwarding --------------------------------------------------
  unless vm_forwarded_ports.empty?
      vm_forwarded_ports.each do |description, value|
          # puts "#{description}, Guest : " + value.fetch('guest').to_i.to_s + " -> " + "Host : " + value.fetch('host').to_i.to_s
          config.vm.network :forwarded_port, guest: value.fetch('guest').to_i, host: value.fetch('host').to_i
      end
  end

  # configure synced folders ---------------------------------------------------
  unless vm_synced_folders.empty?
    vm_synced_folders.each do |key, value|
       # puts "Host Path: " + value.fetch('host_path').to_s + ", Guest Path: " + value.fetch('guest_path').to_s
       config.vm.synced_folder value.fetch('host_path').to_s, value.fetch('guest_path').to_s
    end
  end

  # configure shell env --------------------------------------------------------
  config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"

  # customize vm ---------------------------------------------------------------
  config.vm.provider :virtualbox do |vb|

      vb.customize ["modifyvm", :id, "--cpus", vm_cpus, "--memory", vm_memory]

      # create extra disk
      if ARGV[0] == "up" && ! File.exist?(file_to_disk) && add_virtual_disk.to_s == "true"
           vb.customize [
                'createhd',
                '--filename', file_to_disk,
                '--format', 'VDI',
                '--size', disk_size
                ]

           vb.customize [
                'storageattach', :id,
                '--storagectl', 'SATAController',
                '--port', 1, '--device', 0,
                '--type', 'hdd', '--medium',
                file_to_disk
                ]

      end

  end

  # call provisioners ----------------------------------------------------------
  unless vm_provisioners.empty?
      # puts "#{vm_provisioners}"

      vm_provisioners.each do |prov|

          prov_type = prov.fetch('type')
          prov_name = prov.fetch('name')

          puts "Configuring \'#{prov_type}\' type provisioner: \"#{prov_name}\""

          # run ansible based bootstrapping provisioner
          if  prov_type == "bootstrap"

              prov_tags = prov.has_key?('ansible_tags') ? prov.fetch('ansible_tags').join(",") : ""
              prov_main_playbook = prov.has_key?('main_playbook') ? prov.fetch('main_playbook').to_s : DEFAULT_MAIN_PLAYBOOK
              puts "Ansible tags: #{prov_tags}"
              puts "Main Playbook: #{prov_main_playbook}"

              config.vm.provision prov_name, type: "shell" do |s|
                  s.keep_color = true
                  s.path = "bootstrap.sh"
                  s.args = "-p #{use_proxy} -t '#{prov_tags}' -e '#{ansible_extra_vars}' -v #{vagrant_proxyconf_plugin_installed} -m #{prov_main_playbook}"
              end

          # run ansible based provisioner ondemand
          elsif prov_type == "ondemand"

              if ARGV.include? '--provision-with'

                  prov_tags = prov.has_key?('ansible_tags') ? prov.fetch('ansible_tags').join(",") : ""
                  prov_main_playbook = prov.has_key?('main_playbook') ? prov.fetch('main_playbook').to_s : DEFAULT_MAIN_PLAYBOOK

                  config.vm.provision prov_name, run: "never", type: "shell" do |s|
                      s.keep_color = true
                      s.path = "bootstrap.sh"
                      s.args = "-p #{use_proxy} -t '#{prov_tags}' -e '#{ansible_extra_vars}' -v #{vagrant_proxyconf_plugin_installed} -m #{prov_main_playbook}"
                  end

              end

          # run arbitrary shell provisioner
          elsif prov_type == "shell"

                prov_path = prov.fetch('path')
                prov_args = prov.fetch('args', "")

                config.vm.provision prov_name, type: "shell" do |s|
                    s.keep_color = true
                    s.path = prov_path.to_s
                    s.args = prov_args.to_s
                end

          # perform reboot of the VM guest
          elsif prov_type == "unix_reboot"

              config.vm.provision :unix_reboot

          # run provisioner always
          elsif prov_type == "shell_always"

              prov_path = prov.fetch('path')
              prov_args = prov.fetch('args', "")

              config.vm.provision prov_name, run: "always", type: "shell" do |s|
                  s.keep_color = true
                  s.path = prov_path.to_s
                  s.args = prov_args.to_s
              end

          else
              puts "WARN: Provisioner type \"#{prov_type}\" not implemented yet!"
          end

      end

  end


end
