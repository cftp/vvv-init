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

# ----------------------------------------------------------------
# You should not need to edit below this point. Famous last words.

echo "Commencing $SITE_NAME setup"

# Add GitHub.com to known hosts, so we don't get prompted
# to verify the server fingerprint.
mkdir -p /root/.ssh
touch /root/.ssh/known_hosts
IFS=$'\n'
for KNOWN_HOST in $(cat "ssh/known_hosts"); do
	if ! grep -Fxq "$KNOWN_HOST" /root/.ssh/known_hosts; then
	    echo "Adding host to SSH known_hosts for user 'root': $KNOWN_HOST"
	    echo $KNOWN_HOST >> /root/.ssh/known_hosts
	fi
done

# Reload SSH, to get it to notice the change to known_hosts
service ssh force-reload

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
	echo "Creating wp-config.php"
	 wp core config --dbname="$DB_NAME" --dbuser=wp --dbpass=wp --dbhost="localhost" --extra-php <<PHP
$EXTRA_CONFIG
PHP

else
	echo "wp-config.php already exists"
fi

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

echo "$SITE_NAME site now installed, you may want to add the user uploaded files";