# A quick hack to allow rebooting of a Vagrant VM during provisioning.
#
# The code is fragile with respect to internal changes in Vagrant, as there is
# no useful public API that allows a reboot to be engineered.
#
# Originally adapted from:
#          https://gist.github.com/ukabu/6780121
#          https://github.com/exratione/vagrant-provision-reboot
#
# This file should be placed into a folder relative to the Vagrantfile. Then in
# the Vagrantfile, you'll want to do something like the following:
#
# ----------------------------------------------------------------------------
#
# require './plugins/vagrant-provision-reboot-plugin'
#
# Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
#
#   # Run your pre-reboot provisioning block.
#   #config.vm.provision :shell do |s|
#   #  ...
#   #end
#
#   # Run a reboot of a *NIX guest.
#   config.vm.provision :unix_reboot
#
#   # Run your post-reboot provisioning block.
#   #config.vm.provision :shell do |s|
#   #  ...
#   #end
#
# ----------------------------------------------------------------------------
#
# The provisioner takes care of remounting the synced folders.
#
# This will work for the VirtualBox provider. For other providers, a
# 'remount_synched_folders' action must be added to the provider implementation.

require 'vagrant'

# Monkey-patch the VirtualBox provider to be able to remap synced folders after
# reboot. This is the tricky part.
#
# This involves pulling out some code fragments from the existing SyncedFolders
# class - which is unpleasant, but there are no usefully exposed methods such
# that we can run only what we need to.
module VagrantPlugins
  module ProviderVirtualBox
    module Action

      class RemountSyncedFolders < SyncedFolders

        def initialize(app, env)
          super(app, env)
        end

        def call(env)
          @env = env
          @app.call(env)

          # Copied out of /lib/vagrant/action/builtin/synced_folders.rb in
          # Vagrant 1.4.3, and surprisingly still working in 1.6.1.
          #
          # This is going to be fragile with respect to future changes, but
          # that's just the way the cookie crumbles.
          #
          # We can't just run the whole SyncedFolders.call() method because
          # it undertakes a lot more setup and will error out if invoked twice
          # during "vagrant up" or "vagrant provision".
          folders = synced_folders(env[:machine])
          folders.each do |impl_name, fs|
            plugins[impl_name.to_sym][0].new.enable(env[:machine], fs, impl_opts(impl_name, env))
          end
        end
      end

      def self.action_remount_synced_folders
        Vagrant::Action::Builder.new.tap do |b|
          b.use RemountSyncedFolders
        end
      end

    end
  end
end

# Define the plugin.
class RebootPlugin < Vagrant.plugin('2')
  name 'Reboot Plugin'

  # This plugin provides a provisioner called unix_reboot.
  provisioner 'unix_reboot' do

    # Create a provisioner.
    class RebootProvisioner < Vagrant.plugin('2', :provisioner)
      # Initialization, define internal state. Nothing needed.
      def initialize(machine, config)
        super(machine, config)
      end

      # Configuration changes to be done. Nothing needed here either.
      def configure(root_config)
        super(root_config)
      end

      # Run the provisioning.
      def provision
        command = 'shutdown -r now'
        @machine.ui.info("Issuing command: #{command}")
        @machine.communicate.sudo(command) do |type, data|
          if type == :stderr
            @machine.ui.error(data);
          end
        end

        begin
          sleep 15
        end until @machine.communicate.ready?

        # Now the machine is up again, perform the necessary tasks.
        @machine.ui.info("Launching remount_synced_folders action...")
        @machine.action('remount_synced_folders')
      end

      # Nothing needs to be done on cleanup.
      def cleanup
        super
      end
    end
    RebootProvisioner

  end

  # This plugin provides a provisioner called windows_reboot.
  provisioner 'windows_reboot' do

    # Create a provisioner.
    class RebootProvisioner < Vagrant.plugin('2', :provisioner)
      # Initialization, define internal state. Nothing needed.
      def initialize(machine, config)
        super(machine, config)
      end

      # Configuration changes to be done. Nothing needed here either.
      def configure(root_config)
        super(root_config)
      end

      # Run the provisioning.
      def provision
        command = 'shutdown -t 0 -r -f'
        @machine.ui.info("Issuing command: #{command}")
        @machine.communicate.execute(command) do |type, data|
          if type == :stderr
            @machine.ui.error(data);
          end
        end

        begin
          sleep 15
        end until @machine.communicate.ready?

        # Now the machine is up again, perform the necessary tasks.
        @machine.ui.info("Launching remount_synced_folders action...")
        @machine.action('remount_synced_folders')
      end

      # Nothing needs to be done on cleanup.
      def cleanup
        super
      end
    end
    RebootProvisioner

  end
end
