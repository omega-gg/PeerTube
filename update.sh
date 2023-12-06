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

    echo "Usage: update <version> <artifact> <production.yaml>"

    exit 1
fi

#--------------------------------------------------------------------------------------------------
# Stop
#--------------------------------------------------------------------------------------------------

echo "STOP"

sudo systemctl stop nginx

#--------------------------------------------------------------------------------------------------
# Configure
#--------------------------------------------------------------------------------------------------

sudo sh configure.sh

#--------------------------------------------------------------------------------------------------
# Backup SQL
#--------------------------------------------------------------------------------------------------

echo ""
echo "BACKUP SQL"

SQL_BACKUP_PATH="backup/sql-peertube_prod-$(date -Im).bak"

cd /var/www/peertube && sudo -u peertube mkdir -p backup

sudo -u postgres pg_dump -F c peertube_prod | sudo -u peertube tee "$SQL_BACKUP_PATH" >/dev/null

#--------------------------------------------------------------------------------------------------
# Artifact
#--------------------------------------------------------------------------------------------------

cd /var/www/peertube/versions

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

if [ -d "${1}" ]; then

    # NOTE: Removing the old folder.
    sudo rm -rf $1
fi

sudo -u peertube unzip -qo $name/PeerTube.zip -d $1

rm -rf $name

#--------------------------------------------------------------------------------------------------
# Install
#--------------------------------------------------------------------------------------------------

echo ""
echo "INSTALL"

cd /var/www/peertube

# NOTE: Removing the old symbolic link.
sudo rm peertube-latest

sudo -u peertube ln -s versions/$1 ./peertube-latest

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
# Check configuration
#--------------------------------------------------------------------------------------------------

echo ""
echo "CHECK CONFIGURATION"

cd /var/www/peertube/versions

diff -u "$(ls --sort=t | head -2 | tail -1)/config/production.yaml.example" \
         "$(ls --sort=t | head -1)/config/production.yaml.example"

diff -u "$(ls --sort=t | head -2 | tail -1)/support/nginx/peertube" \
        "$(ls --sort=t | head -1)/support/nginx/peertube"

diff -u "$(ls --sort=t | head -2 | tail -1)/support/systemd/peertube.service" \
        "$(ls --sort=t | head -1)/support/systemd/peertube.service"

#--------------------------------------------------------------------------------------------------
# Restart
#--------------------------------------------------------------------------------------------------

echo ""
echo "RESTART"

sudo systemctl start nginx

sudo systemctl daemon-reload

sudo systemctl restart peertube && sudo journalctl -fu peertube
