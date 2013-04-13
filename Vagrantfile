# -*- mode: ruby -*-
# vi: set ft=ruby :

CHEF_ATTRIBUTES = {
  :chef_environment => "staging",
  :hipchat => {:room => "Testing"}
}

Vagrant::Config.run do |config|
  config.vm.define :web do |web_config|
    web_config.vm.box = "lucid64"
    web_config.vm.customize { |vm| vm.memory_size = 1024 }
    web_config.vm.network :hostonly, "192.168.51.50"
    web_config.vm.share_folder "chef", "/etc/chef", "~/.chef"
    web_config.vm.provision :chef_solo do |chef|
      chef.cookbooks_path = "cookbooks"
      chef.data_bags_path = "data_bags"
      chef.roles_path = "roles"
      chef.add_role "base"
      chef.add_role "web"
      chef.json = CHEF_ATTRIBUTES
    end
  end
end
