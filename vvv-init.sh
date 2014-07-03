#!/bin/bash
# Init script for a development site with a monolithic Git repo
# v1.0

# Edit these variables to suit your porpoises
# -------------------------------------------

# Just a human readable description of this site
SITE_NAME="Site Name"
# The name (to be) used by MySQL for the DB
DB_NAME="site_name"
# The repo URL in SSH format, e.g. git@github.com:cftp/foo.git
REPO_SSH_URL="git@github.com:cftp/site_name.git"
# The multisite stuff for wp-config.php
EXTRA_CONFIG="
// No extra config, but if there was multisite stuff, etc,
// it would go here.
"

# ----------------------------------------------------------------
# You should not need to edit below this point. Famous last words.

echo "---------------------------"
echo "Commencing $SITE_NAME setup"

# Add GitHub and GitLab to known_hosts, so we don't get prompted
# to verify the server fingerprint.
# The fingerprints in [this repo]/ssh/known_hosts are generated as follows:
#
# As the starting point for the ssh-keyscan tool, create an ASCII file 
# containing all the hosts from which you will create the known hosts 
# file, e.g. sshhosts.
# Each line of this file states the name of a host (alias name or TCP/IP 
# address) and must be terminated with a carriage return line feed 
# (Shift + Enter), e.g.
# 
# bitbucket.org
# github.com
# gitlab.com
# 
# Execute ssh-keyscan with the following parameters to generate the file:
# 
# ssh-keyscan -t rsa,dsa -f ssh_hosts >ssh/known_hosts
# The parameter -t rsa,dsa defines the host’s key type as either rsa 
# or dsa.
# The parameter -f /home/user/ssh_hosts states the path of the source 
# file ssh_hosts, from which the host names are read.
# The parameter >ssh/known_hosts states the output path of the 
# known_host file to be created.
# 
# From "Create Known Hosts Files" at: 
# http://tmx0009603586.com/help/en/entpradmin/Howto_KHCreate.html
mkdir -p ~/.ssh
touch ~/.ssh/known_hosts
IFS=$'\n'
for KNOWN_HOST in $(cat "ssh/known_hosts"); do
	if ! grep -Fxq "$KNOWN_HOST" ~/.ssh/known_hosts; then
	    echo "Adding host to SSH known_hosts for user 'root': $(echo $KNOWN_HOST |cut -d '|' -f1)"
	    echo $KNOWN_HOST >> ~/.ssh/known_hosts
	fi
done

# Clone the repo, if it's not there already
if [ ! -d htdocs ]
then
	ssh-agent bash -c "ssh-add ssh/cftp_deploy_id_rsa; git clone $REPO_SSH_URL htdocs;"
	echo "Cloning the repo"
else
	echo "The htdocs directory already exists, and should contain the repo. If not, delete it and run Vagrant provisioning again."
fi

# Make a database, if we don't already have one
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS $DB_NAME; GRANT ALL PRIVILEGES ON $DB_NAME.* TO wp@localhost IDENTIFIED BY 'wp';"

# Let's get some config in the house
if [ ! -f htdocs/wp-config.php ]; then
	wp core download --path=htdocs
	wp core config --dbname="$DB_NAME" --dbuser=wp --dbpass=wp --dbhost="localhost" --extra-php <<PHP
$EXTRA_CONFIG
PHP
else
	echo "wp-config.php already exists"
fi

# Load the composer stuff
./wrapper-composer.sh update

DATA_IN_DB=`mysql -u root --password=root --skip-column-names -e "SHOW TABLES FROM $DB_NAME;"`
if [ "" == "$DATA_IN_DB" ]; then
	if [ ! -f initial-data.sql ]
	then
		echo "DATABASE NOT INSTALLED, add initial-data.sql file and run Vagrant provisioning again"
	else
		echo "Loading the database with lovely data"
		mysql -u root --password=root $DB_NAME < initial-data.sql
	fi
	wp user create dev_admin dev_admin@example.com --role=administrator --user_pass=password
else
	echo "Database has data, skipping"
fi

# The Vagrant site setup script will restart Nginx for us

echo "$SITE_NAME init is complete";
