#!/bin/sh
set -e

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

node_version="18"

#--------------------------------------------------------------------------------------------------
# Global
#--------------------------------------------------------------------------------------------------

echo "INSTALL GLOBAL"

sudo apt-get update

sudo apt-get install -y curl sudo unzip vim

#--------------------------------------------------------------------------------------------------
# Node.js
#--------------------------------------------------------------------------------------------------

echo "INSTALL CERTIFICATE"

sudo apt-get install -y ca-certificates curl gnupg

if [ -f "/etc/apt/keyrings/nodesource.gpg" ]; then

    sudo rm -rf /etc/apt/keyrings/nodesource.gpg

elif [ ! -d "/etc/apt/keyrings" ]; then

    sudo mkdir -p /etc/apt/keyrings
fi

curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

echo "INSTALL NODE"

NODE_MAJOR=$node_version

echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

sudo apt-get update

sudo apt-get install -y nodejs

# NOTE: It seems we need 'aptitude' to properly install npm.
sudo apt install -y aptitude

sudo aptitude install -y npm

npm install --global yarn

#--------------------------------------------------------------------------------------------------
# Python
#--------------------------------------------------------------------------------------------------

echo "INSTALL PYTHON"

sudo apt-get install -y python3-dev python-is-python3

#--------------------------------------------------------------------------------------------------
# Common
#--------------------------------------------------------------------------------------------------

echo "INSTALL COMMON"

sudo apt-get install -y certbot nginx ffmpeg postgresql postgresql-contrib openssl g++ make redis-server git cron wget

#--------------------------------------------------------------------------------------------------
# Database
#--------------------------------------------------------------------------------------------------

echo "START DATABASE"

sudo systemctl start redis postgresql
