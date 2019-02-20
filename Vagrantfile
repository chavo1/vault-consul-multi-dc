
SERVER_COUNT = 3
CLIENT_COUNT = 1
VAULT_COUNT = 1
VAULT_VERSION = '1.0.2'
CONSUL_VERSION = '1.4.2'
CONSUL_TEMPLATE_VERSION = '0.19.5'
ENVCONSUL_VERSION = '0.7.3'
DOMAIN = 'consul'
TLS_ENABLE = true

Vagrant.configure(2) do |config|
    config.vm.box = "chavo1/xenial64base"
    config.vm.provider "virtualbox" do |v|
      v.memory = 512
      v.cpus = 2
    
    end

    if TLS_ENABLE == true
    1.upto(VAULT_COUNT) do |n|
      config.vm.define "vault0#{n}" do |vault|
        vault.vm.hostname = "vault0#{n}"
        vault.vm.network "private_network", ip: "192.168.56.#{70+n}"
        vault.vm.provision "shell",inline: "cd /vagrant ; bash scripts/install_vault.sh", env: {"VAULT_VERSION" => VAULT_VERSION}
        vault.vm.provision "shell",inline: "cd /vagrant ; bash scripts/start_vault.sh", env: {"DOMAIN" => DOMAIN}

      end
    end
  end

      ["dc1", "dc2"].to_enum.with_index(1).each do |a, b|
      
    1.upto(SERVER_COUNT) do |n|
      config.vm.define "consul-#{a}-server0#{n}" do |server|
        server.vm.hostname = "consul-#{a}-server0#{n}"
        server.vm.network "private_network", ip: "192.168.#{55+b}.#{50+n}"
        server.vm.provision "shell",inline: "cd /vagrant ; bash scripts/consul.sh", env: {"TLS_ENABLE" => TLS_ENABLE, "DOMAIN" => DOMAIN, "CONSUL_VERSION" => CONSUL_VERSION, "SERVER_COUNT" => SERVER_COUNT}

      end
    end

    1.upto(CLIENT_COUNT) do |n|
      config.vm.define "consul-#{a}-client0#{n}" do |client|
        client.vm.hostname = "consul-#{a}-client0#{n}"
        client.vm.network "private_network", ip: "192.168.#{55+b}.#{60+n}"
        client.vm.provision "shell",inline: "cd /vagrant ; bash scripts/consul.sh", env: {"TLS_ENABLE" => TLS_ENABLE, "DOMAIN" => DOMAIN, "CONSUL_VERSION" => CONSUL_VERSION, "CLIENT_COUNT" => CLIENT_COUNT}
        #client.vm.provision "shell",inline: "cd /vagrant ; bash scripts/consul-template.sh", env: {"CONSUL_TEMPLATE_VERSION" => CONSUL_TEMPLATE_VERSION}
        client.vm.provision "shell",inline: "cd /vagrant ; bash scripts/envconsul.sh", env: {"ENVCONSUL_VERSION" => ENVCONSUL_VERSION}
        client.vm.provision "shell",inline: "cd /vagrant ; bash scripts/kv.sh", env: {"TLS_ENABLE" => TLS_ENABLE}
        client.vm.provision "shell",inline: "cd /vagrant ; bash scripts/call_nginx.sh", env: {"TLS_ENABLE" => TLS_ENABLE}
        #client.vm.provision "shell",inline: "cd /vagrant ; bash scripts/nginx.sh", env: {"TLS_ENABLE" => TLS_ENABLE}
        client.vm.provision "shell",inline: "cd /vagrant ; bash scripts/dns.sh"
      
      end
    end
  end
end
