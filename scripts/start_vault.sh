#!/usr/bin/env bash

DOMAIN=${DOMAIN}
HOST=$(hostname)

set -x

# kill vault
sudo killall vault &>/dev/null

sleep 5

# Create vault configuration
sudo mkdir -p /etc/vault.d

cat << EOF >/etc/vault.d/config.hcl
storage "file" {
  path = "/tmp/data"
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_cert_file = "/etc/vault.d/vault.crt"
  tls_key_file = "/etc/vault.d/vault.key"
}

listener "tcp" {
  address   = "192.168.56.71:8200"
  tls_cert_file = "/etc/vault.d/vault.crt"
  tls_key_file = "/etc/vault.d/vault.key"
}
ui = true
api_addr = "https://192.168.56.71:8200"
cluster_addr = "https://192.168.56.71:8201"
EOF

cat << EOF >/etc/vault.d/vault.hcl
path "sys/mounts/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# List enabled secrets engine
path "sys/mounts" {
  capabilities = [ "read", "list" ]
}

# Work with pki secrets engine
path "pki*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}
EOF

################
# openssl conf # Creating openssl conf /// more info  https://www.phildev.net/ssl/opensslconf.html
################
cat << EOF >/usr/lib/ssl/req.conf
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
C = BG
ST = Sofia
L = Sofia
O = chavo
OU = chavo
CN = chavo.consul
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
IP.2 = 192.168.56.71
EOF

######################################
# generate self signed certificate #
######################################
pushd /etc/vault.d
openssl req -x509 -batch -nodes -newkey rsa:2048 -keyout vault.key -out vault.crt -config /usr/lib/ssl/req.conf -days 365
cat vault.crt >> /usr/lib/ssl/certs/ca-certificates.crt
popd

# setup .bash_profile
grep VAULT_ADDR ~/.bash_profile || {
  echo export VAULT_ADDR=https://127.0.0.1:8200 | sudo tee -a ~/.bash_profile
}

source ~/.bash_profile
##################
# starting vault #
##################
vault -autocomplete-install
complete -C /usr/local/bin/vault vault
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault
sudo useradd --system --home /etc/vault.d --shell /bin/false vault

# Create a Vault service file at /etc/systemd/system/vault.service
sudo cat << EOF >/etc/systemd/system/vault.service
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/config.hcl

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/config.hcl &>${LOG}
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitIntervalSec=60
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start vault

#########################
# Redirecting vault log #
#########################
    if [ -d /vagrant ]; then
        mkdir -p /vagrant/vault_logs
        journalctl -f -u vault.service > /vagrant/vault_logs/${HOST}.log &
    else
        journalctl -f -u vault.service > /tmp/vault.log
    fi
echo vault started

sleep 3 

# Initialize Vault
mkdir -p /vagrant/token/
vault operator init > /vagrant/token/keys.txt
vault operator unseal $(cat /vagrant/token/keys.txt | grep "Unseal Key 1:" | cut -c15-)
vault operator unseal $(cat /vagrant/token/keys.txt | grep "Unseal Key 2:" | cut -c15-)
vault operator unseal $(cat /vagrant/token/keys.txt | grep "Unseal Key 3:" | cut -c15-)
vault login $(cat /vagrant/token/keys.txt | grep "Initial Root Token:" | cut -c21-)

# enable secret KV version 1
sudo VAULT_ADDR="https://127.0.0.1:8200" vault secrets enable -version=1 kv
  
# setup .bashrc
grep VAULT_TOKEN ~/.bashrc || {
  echo export VAULT_TOKEN=\`cat /root/.vault-token\` | sudo tee -a ~/.bashrc
}

sudo VAULT_ADDR="https://127.0.0.1:8200" vault secrets enable pki
sudo VAULT_ADDR="https://127.0.0.1:8200" vault secrets tune -max-lease-ttl=87600h pki
sudo VAULT_ADDR="https://127.0.0.1:8200" vault write -field=certificate pki/root/generate/internal common_name="example.com" \
      ttl=87600h > CA_cert.crt
sudo VAULT_ADDR="https://127.0.0.1:8200" vault write pki/config/urls \
      issuing_certificates="https://127.0.0.1:8200/v1/pki/ca" \
      crl_distribution_points="https://127.0.0.1:8200/v1/pki/crl"
sudo VAULT_ADDR="https://127.0.0.1:8200" vault secrets enable -path=pki_int pki
sudo VAULT_ADDR="https://127.0.0.1:8200" vault secrets tune -max-lease-ttl=43800h pki_int
sudo VAULT_ADDR="https://127.0.0.1:8200" vault write -format=json pki_int/intermediate/generate/internal \
        common_name="example.com Intermediate Authority" ttl="43800h" \
        | jq -r '.data.csr' > pki_intermediate.csr
sudo VAULT_ADDR="https://127.0.0.1:8200" vault write -format=json pki/root/sign-intermediate csr=@pki_intermediate.csr \
        format=pem_bundle \
        | jq -r '.data.certificate' > intermediate.cert.pem
sudo VAULT_ADDR="https://127.0.0.1:8200" vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem
sudo VAULT_ADDR="https://127.0.0.1:8200" vault write pki_int/roles/example-dot-com \
        allowed_domains="${DOMAIN}" \
        allow_subdomains=true \
        max_ttl="720h"

# Sealing Vault 
vault operator seal
set +x