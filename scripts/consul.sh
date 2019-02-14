#!/usr/bin/env bash

SERVER_COUNT=${SERVER_COUNT}
CLIENT_COUNT=${CLIENT_COUNT}
CONSUL_VERSION=${CONSUL_VERSION}
DOMAIN=${DOMAIN}
IPs=$(hostname -I | cut -f2 -d' ')
HOST=$(hostname)
VAULT_TOKEN=`cat /vagrant/token/keys.txt | grep "Initial Root Token:" | cut -c21-` # Vault token, it is needed to access vault
httpUrl="https://192.168.56.71:8200/v1/pki_int/issue/example-dot-com" # Vault address, from where the certificates will be acquired
VaultunSeal="https://192.168.56.71:8200/v1/sys/unseal" # Curl url to unseal Vault
VaultSeal="https://192.168.56.71:8200/v1/sys/seal" # Curl url to seal Vault
key0=`cat /vagrant/token/keys.txt | grep "Unseal Key 1:" | cut -c15-` #
key1=`cat /vagrant/token/keys.txt | grep "Unseal Key 2:" | cut -c15-` # Needed keys to unseal Vault
key2=`cat /vagrant/token/keys.txt | grep "Unseal Key 3:" | cut -c15-` #


# Install packages
which unzip socat jq dig route vim curl sshpass &>/dev/null || {
    apt-get update -y
    apt-get install unzip socat net-tools jq dnsutils vim curl sshpass -y 
}

#####################
# Installing consul #
#####################
sudo mkdir -p /vagrant/pkg

which consul || {
    # check if consul file exist.
    CHECKFILE="/vagrant/pkg/consul_${CONSUL_VERSION}_linux_amd64.zip"
    if [ ! -f "$CHECKFILE" ]; then
        pushd /vagrant/pkg
        wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
        popd
 
    fi
    
    pushd /usr/local/bin/
    unzip /vagrant/pkg/consul_${CONSUL_VERSION}_linux_amd64.zip 
    sudo chmod +x consul
    popd
}

killall consul
sudo mkdir -p /etc/consul.d/ssl /vagrant/consul_logs

# Copy the certificate from Vault in order to autorize consul agents to comunicate with Vault
sshpass -p 'vagrant' scp -o StrictHostKeyChecking=no vagrant@192.168.56.71:"/etc/vault.d/vault.crt" /etc/consul.d/ssl/
set -x
############################### We unseal Vault in order to acquire needed certificates
# Triple Loop to Unseal Vault #             It must be done with 3 keys
###############################
        for x in {0..2}; do
            echo $x
            for u in {0..2}; do
                ukey=key${x}
                `curl --cacert /etc/consul.d/ssl/vault.crt --header --request PUT --data '{"key": "'${!ukey}'"}' $VaultunSeal`
            done
        done
    
###########################
# Starting consul servers #
###########################
# check if we are on a server
  IS_SERVER=false

if [[ $HOST =~ server ]]; then
# if the name contain server we are there
  IS_SERVER=true

fi
# check DC
if [[ $IPs =~ 192.168.56 ]]; then # if 192.168.56 it is dc1
  i=client
  dc=dc1
      pushd /etc/consul.d/ssl/
          GENCERT=`curl --cacert /etc/consul.d/ssl/vault.crt --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data '{"common_name": "'${i}.${dc}.${DOMAIN}'", "ttl": "24h", "alt_names": "localhost", "ip_sans": "127.0.0.1"}' $httpUrl`
        if [ $? -ne 0 ]; then
            echo "Vault is not available. Exit ..."
            exit 1 # if vault is not available script will be terminated
        else
            echo $GENCERT | jq -r .data.issuing_ca > consul-agent-ca.pem
            echo $GENCERT | jq -r .data.certificate > consul-agent.pem
            echo $GENCERT | jq -r .data.private_key > consul-agent.key
        fi
      popd
  LAN=',
    "retry_join": [
      "192.168.56.51",
      "192.168.56.52",
      "192.168.56.53"
    ]'
  if [ "$IS_SERVER" = true ] ; then # confirm if we are on dc1 server
    i=server
    server=${SERVER_COUNT}
      pushd /etc/consul.d/ssl/
      GENCERT=`curl --cacert /etc/consul.d/ssl/vault.crt --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data '{"common_name": "'${i}.${dc}.${DOMAIN}'", "ttl": "24h", "alt_names": "localhost", "ip_sans": "127.0.0.1"}' $httpUrl`
          if [ $? -ne 0 ]; then
              echo "Vault is not available. Exit ..."
              exit 1 # if vault is not available script will be terminated
          else
              echo $GENCERT | jq -r .data.issuing_ca > consul-agent-ca.pem
              echo $GENCERT | jq -r .data.certificate > consul-agent.pem
              echo $GENCERT | jq -r .data.private_key > consul-agent.key
          fi
      popd
    WAN=',
      "retry_join_wan": [
        "192.168.57.51",
        "192.168.57.52",
        "192.168.57.53"
      ]'
  fi


elif [[ $IPs =~ 192.168.57 ]]; then  # if 192.168.57 it is dc2
  i=client
  dc=dc2
      pushd /etc/consul.d/ssl/
          GENCERT=`curl --cacert /etc/consul.d/ssl/vault.crt --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data '{"common_name": "'${i}.${dc}.${DOMAIN}'", "ttl": "24h", "alt_names": "localhost", "ip_sans": "127.0.0.1"}' $httpUrl`
        if [ $? -ne 0 ]; then
            echo "Vault is not available. Exit ..."
            exit 1 # if vault is not available script will be terminated
        else
            echo $GENCERT | jq -r .data.issuing_ca > consul-agent-ca.pem
            echo $GENCERT | jq -r .data.certificate > consul-agent.pem
            echo $GENCERT | jq -r .data.private_key > consul-agent.key
        fi
      popd
  LAN=',
    "retry_join": [
      "192.168.57.51",
      "192.168.57.52",
      "192.168.57.53"
    ]'
    if [ "$IS_SERVER" = true ] ; then # confirm if we are on dc2 server
      i=server
      server=${SERVER_COUNT}
        pushd /etc/consul.d/ssl/
            GENCERT=`curl --cacert /etc/consul.d/ssl/vault.crt --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data '{"common_name": "'${i}.${dc}.${DOMAIN}'", "ttl": "24h", "alt_names": "localhost", "ip_sans": "127.0.0.1"}' $httpUrl`
          if [ $? -ne 0 ]; then
              echo "Vault is not available. Exit ..."
              exit 1 # if vault is not available script will be terminated
          else
              echo $GENCERT | jq -r .data.issuing_ca > consul-agent-ca.pem
              echo $GENCERT | jq -r .data.certificate > consul-agent.pem
              echo $GENCERT | jq -r .data.private_key > consul-agent.key
          fi
        popd
      WAN=',
        "retry_join_wan": [
          "192.168.56.51",
          "192.168.56.52",
          "192.168.56.53"
        ]'
    fi

else 
  # In this case we not need else but after else must some command
  echo "Hello"
fi
# Creating consul configuration files - they are almost the same so - just a few variables
if [[ $HOST =~ server ]]; then
sudo cat <<EOF > /etc/consul.d/config.json
{
  "datacenter": "${dc}",
  "domain": "${DOMAIN}",
  "server": true,
  "ui": true,
  "client_addr": "0.0.0.0",
  "bind_addr": "0.0.0.0",
  "data_dir": "/usr/local/consul",
  "bootstrap_expect": ${server}${LAN}${WAN},
  "verify_outgoing": true,
  "verify_server_hostname": true,
  "verify_incoming_https": false,
  "verify_incoming_rpc": true, 
  "ca_file": "/etc/consul.d/ssl/consul-agent-ca.pem",  
  "cert_file": "/etc/consul.d/ssl/consul-agent.pem",
  "key_file": "/etc/consul.d/ssl/consul-agent.key",
    "ports": {
    "http": -1,
    "https": 8501
  }
}
EOF

else

sudo cat <<EOF > /etc/consul.d/config.json
{
  "datacenter": "${dc}",
  "server": false,
  "ui": true,
  "client_addr": "0.0.0.0",
  "bind_addr": "0.0.0.0",
  "enable_script_checks": true,
  "data_dir": "/usr/local/consul"${LAN},
  "verify_outgoing": true,
  "verify_server_hostname": true,
  "verify_incoming_https": false,
  "verify_incoming_rpc": true, 
  "ca_file": "/etc/consul.d/ssl/consul-agent-ca.pem",  
  "cert_file": "/etc/consul.d/ssl/consul-agent.pem",
  "key_file": "/etc/consul.d/ssl/consul-agent.key",
    "ports": {
    "http": -1,
    "https": 8501
  }
}
EOF
fi
# starting consul agents
if [[ $HOST =~ server ]]; then
    # starting consul servers
    consul agent -server -ui -advertise $IPs -config-dir=/etc/consul.d > /vagrant/consul_logs/$HOST.log & 
else # starting consul clients
    consul agent -ui -advertise $IPs -config-dir=/etc/consul.d > /vagrant/consul_logs/$HOST.log & 

fi
set +x
sleep 5

consul members -ca-file=/etc/consul.d/ssl/consul-agent-ca.pem -client-cert=/etc/consul.d/ssl/consul-agent.pem \
-client-key=/etc/consul.d/ssl/consul-agent.key -http-addr="https://127.0.0.1:8501"

