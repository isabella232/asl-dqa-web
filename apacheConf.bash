#!/usr/bin/env bash

# Setup dqa project in Apache

httpd_location=/etc/httpd/conf.d
conf_file=dqa.conf

set -e

# cd to script directory
cd "${0%/*}"

# Remove file if present
rm -rf  ${httpd_location}/${conf_file}

# Copy file from dqa project
cp examples/${conf_file}  ${httpd_location}/${conf_file}

apachectl restart
