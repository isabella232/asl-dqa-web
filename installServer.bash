#!/usr/bin/env bash

# This script installs the dqa web project on a server environment
# Assumes asl-dqa-web repo cloned locally under /data/www/asl-dqa-web
# execute this script as asluser ... "sudo su - asluser"

set -e

SRCDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo $SRCDIR

cd $SRCDIR

# Create the virtual environment, load PYTHON modules
./setup.bash

# Copy local_settings.py file to proper location, this file must be modified
cp examples/local_settings.py dqa/local_settings.py

echo "Please modify your local_settings.py and install your apache config file!"
echo "Then run ./updateServer.bash"
