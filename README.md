## This repo contains a sample of Consul cluster in multi-datacenter deployment over HTTPS. 
#### It will spin up 8 Vagrant machines with 3 Consul servers - 1 Consul client in dc1 and 3 Consul servers - 1 Consul client in dc2 and 1 vault server over HTTPS.

#### The usage is pretty simple

- At least 8GB ram
- Vagrant should be [installed](https://www.vagrantup.com/)
- Git should be [installed](https://git-scm.com/)
- Since [Consul](https://www.consul.io/) require at least 3 servers in order to survive 1 server failure. Quorum requires at least (n/2)+1 members. If we need more servers, clients or a specific Consul version - it is simple as just change the numbers in the Vagrantfile
```
SERVER_COUNT = 3
CLIENT_COUNT = 1
VAULT_COUNT = 1
VAULT_VERSION = '1.0.2'
CONSUL_VERSION = '1.4.2'
CONSUL_TEMPLATE_VERSION = '0.19.5'
DOMAIN = 'consul'
```
#### I have changed the [NGINX](https://www.nginx.com/resources/wiki/) Welcome page from [Consul KV Store](https://www.consul.io/api/kv.html)

### Now we are ready to start, just follow the steps:

- Clone the repo
```
git clone git@github.com:chavo1/vault-consul-multi-dc.git
cd vault-consul-multi-dc
```
- Start the lab
```
vagrant up
```
#### Check if Consul UI is available on the following addresses:
##### DC1
- Servers: https://192.168.56.51:8501 etc.
- Clients: https://192.168.56.61:8501 etc.
- NGINX: https://192.168.56.61 etc.
##### DC2
- Servers: https://192.168.57.51:8501 etc.
- Clients: https://192.168.57.61:8501 etc.
- NGINX: https://192.168.57.61 etc.
#### Test with infinite_loop.sh
```
vagrant ssh consul-dc2-client01
sudo su -
/vagrant/scripts/infinite_loop.sh # must be stopped manually
```
#### open another console
```
vagrant ssh consul-dc2-client01
sudo su -
curl -k \
    --request POST \
    --data \
'{
  "Name": "web",
  "Service": {
    "Service": "web",
    "Failover": {
      "NearestN": 2,
      "Datacenters": ["dc1", "dc2"]
    }
  }
}' https://127.0.0.1:8501/v1/query
systemctl stop nginx
```
#### The last command will stop nginx service and Failover will occur (traffic will be redirected to the  dc1). In query.txt you can find more queries. To switch again to dc1 just start nginx.
```
systemctl start nginx
tail -f /vagrant/conul_log/loop.log
```
#### In loop.log you will be able to see redirection in real time





