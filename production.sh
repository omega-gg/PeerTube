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

    echo $artifacts | grep -Po '"id":.*?[^\\]}}'         | \
                      grep "$2\""                        | \
                      grep -Po '"downloadUrl":.*?[^\\]"' | \
                      grep -o '"[^"]*"$'                 | tr -d '"'
}

#--------------------------------------------------------------------------------------------------
# Syntax
#--------------------------------------------------------------------------------------------------

if [ $# != 3 ]; then

    echo "Usage: production <domain> <artifact> <production.yaml>"
fi

#--------------------------------------------------------------------------------------------------
# Configure
#--------------------------------------------------------------------------------------------------

sudo sh configure.sh

#--------------------------------------------------------------------------------------------------
# User
#--------------------------------------------------------------------------------------------------

echo ""
echo "CREATE USER"

sudo useradd -m -d /var/www/peertube -s /bin/bash -p peertube peertube

sudo passwd peertube

echo "PeerTube: Ensure the peertube root directory is traversable by nginx."

sudo chmod 755 /var/www/peertube

ls -ld /var/www/peertube # NOTE: Should be drwxr-xr-x

#--------------------------------------------------------------------------------------------------
# Database
#--------------------------------------------------------------------------------------------------

echo ""
echo "CREATE DATABASE"

cd /var/www/peertube

sudo -u postgres createuser -P peertube

sudo -u postgres createdb -O peertube -E UTF8 -T template0 peertube_prod

# NOTE PeerTube: This is required for extensions
sudo -u postgres psql -c "CREATE EXTENSION pg_trgm;"  peertube_prod
sudo -u postgres psql -c "CREATE EXTENSION unaccent;" peertube_prod

#--------------------------------------------------------------------------------------------------
# Prepare
#--------------------------------------------------------------------------------------------------

echo ""
echo "PREPARE"

sudo -u peertube mkdir config storage versions

sudo -u peertube chmod 750 config/

cd /var/www/peertube/versions

#--------------------------------------------------------------------------------------------------
# Artifact
#--------------------------------------------------------------------------------------------------

PeerTube_url="https://dev.azure.com/bunjee/PeerTube/_apis/build/builds/$2/artifacts"

name="PeerTube-linux64"

echo ""
echo "ARTIFACT $name"
echo $PeerTube_url

PeerTube_url=$(getSource $PeerTube_url $name)

sudo -u peertube curl --retry 3 -L -o PeerTube.zip $PeerTube_url

echo ""
echo "EXTRACTING $name"

sudo -u peertube unzip -q PeerTube.zip

rm PeerTube.zip

sudo -u peertube unzip -qo $name/PeerTube.zip

rm -rf $name

echo ""
ls -la # NOTE: Should be owned by peertube.

#--------------------------------------------------------------------------------------------------
# Install
#--------------------------------------------------------------------------------------------------

echo ""
echo "INSTALL"

cd /var/www/peertube

sudo -u peertube ln -s versions ./peertube-latest

cd ./peertube-latest && sudo -H -u peertube yarn install --production --pure-lockfile

#--------------------------------------------------------------------------------------------------
# Configuration
#--------------------------------------------------------------------------------------------------

echo ""
echo "CONFIGURATION"

cd /var/www/peertube

sudo -u peertube cp peertube-latest/config/default.yaml config/default.yaml

# NOTE: We might not be able to copy this file as the peertube user.
sudo cp "$3" config/production.yaml

#--------------------------------------------------------------------------------------------------
# Webserver
#--------------------------------------------------------------------------------------------------

echo ""
echo "WEBSERVER"

sudo cp /var/www/peertube/peertube-latest/support/nginx/peertube /etc/nginx/sites-available/peertube

sudo sed -i 's/${WEBSERVER_HOST}/'"$1"'/g' /etc/nginx/sites-available/peertube

sudo sed -i 's/${PEERTUBE_HOST}/127.0.0.1:9000/g' /etc/nginx/sites-available/peertube

sudo ln -s /etc/nginx/sites-available/peertube /etc/nginx/sites-enabled/peertube

#--------------------------------------------------------------------------------------------------
# Certificate
#--------------------------------------------------------------------------------------------------

echo ""
echo "CERTIFICATE"

sudo systemctl stop nginx

sudo certbot certonly --standalone --post-hook "systemctl restart nginx"

sudo systemctl reload nginx

#--------------------------------------------------------------------------------------------------
# Linux tuning
#--------------------------------------------------------------------------------------------------

echo ""
echo "TUNING"

sudo cp /var/www/peertube/peertube-latest/support/sysctl.d/30-peertube-tcp.conf /etc/sysctl.d/

sudo sysctl -p /etc/sysctl.d/30-peertube-tcp.conf

#--------------------------------------------------------------------------------------------------
# systemd
#--------------------------------------------------------------------------------------------------

echo ""
echo "SYSTEMD"

sudo cp /var/www/peertube/peertube-latest/support/systemd/peertube.service /etc/systemd/system/

sudo vim /etc/systemd/system/peertube.service

sudo systemctl daemon-reload

sudo systemctl enable peertube

#--------------------------------------------------------------------------------------------------
# Run
#--------------------------------------------------------------------------------------------------

echo ""
echo "RUN"

sudo systemctl start peertube

sudo journalctl -feu peertube
