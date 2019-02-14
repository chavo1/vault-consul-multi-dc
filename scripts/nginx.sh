#!/usr/bin/env bash

which nginx &>/dev/null || {
    sudo apt get update -y
    sudo apt install nginx -y
    }

service nginx stop

IPs=$(hostname -I | cut -f2 -d' ')
HOST=$(hostname)

sudo mkdir -p /vagrant/pkg

# If we need envconsul
if which envconsul >/dev/null; then

echo $nginx > /var/www/html/index.nginx-debian.html

# Another examples
# envconsul -pristine -prefix nginx env | sed 's/consul-client01=//g' > /var/www/html/index.nginx-debian.html
# export `envconsul -pristine -prefix nginx env`; env

# If we consul-template
elif  which consul-template >/dev/null; then

set -x
#export HOST=$HOST
#consul-template -config=/vagrant/templates/config.hcl > /vagrant/consul_logs/template_$HOST.log & 
consul-template -consul-ssl -consul-ssl-ca-cert=/etc/consul.d/ssl/consul-agent-ca.pem -consul-addr=127.0.0.1:8501 -config=/vagrant/templates/config.hcl > /vagrant/consul_logs/template_$HOST.log &


else
  
  # Updating nginx start page

sudo curl -s -k https://127.0.0.1:8501/v1/kv/$HOST/nginx?raw > /var/www/html/index.nginx-debian.html

fi

service nginx start

sudo mkdir -p /etc/consul.d

# create script to check nging welcome page
cat << EOF > /tmp/welcome.sh
#!/usr/bin/env bash
curl ${HOST}:80 | grep "Welcome to nginx from ${HOST}!"
EOF
sudo chmod +x /tmp/welcome.sh

#####################
# Register services #
#####################
cat << EOF > /etc/consul.d/web.json
{
    "service": {
        "name": "web",
        "tags": ["${HOST}"],
        "port": 80
    },
    "checks": [
      {
          "id": "nginx_http_check",
          "name": "nginx",
          "http": "http://${HOST}:80",
          "tls_skip_verify": false,
          "method": "GET",
          "interval": "10s",
          "timeout": "1s"
      },
      {
          "id": "tcp_check",
          "name": "TCP on port 80",
          "tcp": "127.0.0.1:80",
          "interval": "10s",
          "timeout": "1s"
      },
      {
          "id": "script_check",
          "name": "check_welcome_page",
          "args": ["/tmp/welcome.sh", "-limit", "256MB"],
          "interval": "10s",
          "timeout": "1s"
      }
   ]
}
EOF


consul reload -ca-file=/etc/consul.d/ssl/consul-agent-ca.pem -client-cert=/etc/consul.d/ssl/consul-agent.pem \
-client-key=/etc/consul.d/ssl/consul-agent.key -http-addr="https://127.0.0.1:8501"

consul members -ca-file=/etc/consul.d/ssl/consul-agent-ca.pem -client-cert=/etc/consul.d/ssl/consul-agent.pem \
-client-key=/etc/consul.d/ssl/consul-agent.key -http-addr="https://127.0.0.1:8501"

set +x