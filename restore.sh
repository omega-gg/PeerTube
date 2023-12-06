#!/bin/sh
set -e

#--------------------------------------------------------------------------------------------------
# Syntax
#--------------------------------------------------------------------------------------------------

if [ $# != 1 ]; then

    echo "Usage: restore <archive>"

    exit 1
fi

#--------------------------------------------------------------------------------------------------
# Stop
#--------------------------------------------------------------------------------------------------

echo "STOP"

sudo systemctl stop nginx

#--------------------------------------------------------------------------------------------------
# Restore
#--------------------------------------------------------------------------------------------------

echo ""
echo "RESTORING"

cd /var/www/peertube

if [ -d "restore" ]; then

    sudo rm -rf restore
fi

sudo -u peertube mkdir restore

mv "$1" restore

cd restore

sudo -u peertube tar -xvzf backup.tar.gz

#--------------------------------------------------------------------------------------------------
# Restore SQL
#--------------------------------------------------------------------------------------------------

echo ""
echo "RESTORE SQL"

sudo -u postgres pg_restore -c -C -d postgres sql-peertube_prod.bak

#--------------------------------------------------------------------------------------------------
# Restore storage
#--------------------------------------------------------------------------------------------------

echo ""
echo "RESTORE STORAGE"

sudo rm -rf /var/www/peertube/storage

sudo -u peertube mv var/www/peertube/storage /var/www/peertube

#--------------------------------------------------------------------------------------------------
# Clean
#--------------------------------------------------------------------------------------------------

echo ""
echo "CLEAN"

sudo rm -rf /var/www/peertube/restore

#--------------------------------------------------------------------------------------------------
# Restart
#--------------------------------------------------------------------------------------------------

echo ""
echo "RESTART"

sudo systemctl start nginx

sudo systemctl daemon-reload

sudo systemctl restart peertube
