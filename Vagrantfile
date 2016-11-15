# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.box = "ubuntu/trusty32"

    config.vm.provider "virtualbox" do |v|
        v.memory = 1024
        v.cpus = 1
        v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate//vagrant", "1"]
    end
    #config.vm.box_url = "http://files.vagrantup.com/precise32.box"

    # config.vm.network :forwarded_port, guest: 80, host: 8080
    config.vm.network :private_network, ip: "10.10.10.9"

    config.vm.provision :shell, :path => "vagrant-install.sh"

    config.vm.synced_folder ".", "/vagrant", owner: "vagrant", group: "www-data", :mount_options => ["dmode=775", "fmode=664"]

    # If true, then any SSH connections made will enable agent forwarding.
    # Default value: false
    # config.ssh.forward_agent = true

    # Share an additional folder to the guest VM. The first argument is
    # the path on the host to the actual folder. The second argument is
    # the path on the guest to mount the folder. And the optional third
    # argument is a set of non-required options.
    # config.vm.synced_folder "../data", "/vagrant_data"
end
