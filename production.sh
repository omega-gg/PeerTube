#!/bin/sh
set -e

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

getSource()
{
    curl -L -o artifacts.json $1

    artifacts=$(cat artifacts.json)

    rm artifacts.json

    echo $artifacts | $grep -Po '"id":.*?[^\\]}}'         | \
                      $grep "$2\""                        | \
                      $grep -Po '"downloadUrl":.*?[^\\]"' | \
                      $grep -o '"[^"]*"$'                 | tr -d '"'
}

#--------------------------------------------------------------------------------------------------
# Syntax
#--------------------------------------------------------------------------------------------------

if [ $# != 4 ]; then

    echo "Usage: production <domain> <artifact> <default.yaml> <production.yaml>"
fi

#--------------------------------------------------------------------------------------------------
# User
#--------------------------------------------------------------------------------------------------

sudo useradd -m -d /var/www/peertube -s /bin/bash -p peertube peertube

sudo passwd peertube

echo "PeerTube: Ensure the peertube root directory is traversable by nginx."

ls -ld /var/www/peertube # Should be drwxr-xr-x

#--------------------------------------------------------------------------------------------------
# Database
#--------------------------------------------------------------------------------------------------

cd /var/www/peertube

sudo -u postgres createuser -P peertube

sudo -u postgres createdb -O peertube -E UTF8 -T template0 peertube_prod

# NOTE PeerTube: This is required for extensions
sudo -u postgres psql -c "CREATE EXTENSION pg_trgm;" peertube_prod
sudo -u postgres psql -c "CREATE EXTENSION unaccent;" peertube_prod

#--------------------------------------------------------------------------------------------------
# Prepare
#--------------------------------------------------------------------------------------------------

sudo -u peertube mkdir config storage versions

sudo -u peertube chmod 750 config/

cd /var/www/peertube/versions

#--------------------------------------------------------------------------------------------------
# Artifact
#--------------------------------------------------------------------------------------------------

PeerTube_url="https://dev.azure.com/bunjee/PeerTube/_apis/build/builds/$2/artifacts"

name="PeerTube-linux64"

echo "ARTIFACT $name"
echo $PeerTube_url

PeerTube_url=$(getSource $PeerTube_url $name)

curl --retry 3 -L -o PeerTube.zip $PeerTube_url

echo ""
echo "EXTRACTING $name"

unzip -q PeerTube.zip

rm PeerTube.zip

unzip -qo $name/PeerTube.zip

rm -rf $name

#--------------------------------------------------------------------------------------------------
# Install
#--------------------------------------------------------------------------------------------------

echo "INSTALL"

cd /var/www/peertube

sudo -u peertube ln -s versions ./peertube-latest

cd ./peertube-latest && sudo -H -u peertube yarn install --production --pure-lockfile

#--------------------------------------------------------------------------------------------------
# Configuration
#--------------------------------------------------------------------------------------------------

echo "CONFIGURATION"

cd /var/www/peertube

sudo -u peertube cp "$3" config/default.yaml
sudo -u peertube cp "$4" config/production.yaml

#--------------------------------------------------------------------------------------------------
# Webserver
#--------------------------------------------------------------------------------------------------

echo "WEBSERVER"

sudo cp /var/www/peertube/peertube-latest/support/nginx/peertube /etc/nginx/sites-available/peertube

sudo sed -i 's/${WEBSERVER_HOST}/$1/g' /etc/nginx/sites-available/peertube

sudo sed -i 's/${PEERTUBE_HOST}/127.0.0.1:9000/g' /etc/nginx/sites-available/peertube

sudo ln -s /etc/nginx/sites-available/peertube /etc/nginx/sites-enabled/peertube

#--------------------------------------------------------------------------------------------------
# Certificate
#--------------------------------------------------------------------------------------------------

echo "CERTIFICATE"

sudo systemctl stop nginx

sudo certbot certonly --standalone --post-hook "systemctl restart nginx"

sudo systemctl reload nginx

#--------------------------------------------------------------------------------------------------
# Linux tuning
#--------------------------------------------------------------------------------------------------

echo "TUNING"

sudo cp /var/www/peertube/peertube-latest/support/sysctl.d/30-peertube-tcp.conf /etc/sysctl.d/

sudo sysctl -p /etc/sysctl.d/30-peertube-tcp.conf

#--------------------------------------------------------------------------------------------------
# systemd
#--------------------------------------------------------------------------------------------------

echo "SYSTEMD"

sudo cp /var/www/peertube/peertube-latest/support/systemd/peertube.service /etc/systemd/system/

sudo vim /etc/systemd/system/peertube.service

sudo systemctl daemon-reload

sudo systemctl enable peertube

#--------------------------------------------------------------------------------------------------
# Run
#--------------------------------------------------------------------------------------------------

echo "RUN"

sudo systemctl start peertube

sudo journalctl -feu peertube
