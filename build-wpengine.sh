#!/bin/bash
# Intended to deploy a composer controlled repo to WPEngine. 
# 1. Clones the WPEngine repo into a "package" directory
# 2. Builds a clean copy of the site in a "build" directory
# 3. Transfers the elements we need (e.g. not .git dirs, etc) 
#    from "build" to "package"
# 4. Creates a commit in "package" ready to be pushed to WPE
#
# Usage: ./build-wpengine.sh -m "Code to support new product range" -s somesite

(
	# Uncomment these lines to profile the script
	# set -x
	# PS4='$(date "+%s.%N ($LINENO) + ")'

	# SETUP AND SANITY CHECKS
	# =======================
	while getopts m:s:u: OPTION 2>/dev/null; do
		case $OPTION
		in
			m) COMMIT_MSG=${OPTARG};;
			s) SITENAME=${OPTARG};;
			u) COMPOSER_UPDATE=${OPTARG};;
		esac
	done

	# Variables for the various directories, some temp dirs
	INITIAL=`pwd`
	WHOAMI=`whoami`
	BUILD="$INITIAL/build"
	PACKAGE="$INITIAL/package"
	rm -rf $BUILD
	rm -rf $PACKAGE

	RED='\e[0;31m'
	GREEN='\e[0;32m'
	NC='\e[0m' # No Color

	# VALIDATIONS

	if [ -z "$COMMIT_MSG" ]; then
		echo -e "${RED}Please provide a commit message, e.g. 'sh ./build.sh -m \"Phase 2 beta\"'${NC}"
		exit 1
	fi

	if [ -z "$SITENAME" ]; then
		echo -e "${RED}Please provide a sitename within WP Engine, this will control the Git repo we clone and commit to, e.g. 'sh ./build.sh -s \"somesitename\"'${NC}"
		exit 2
	fi

	# Check for uncommitted changes in htdocs, and refuse to proceed if there are any
	echo "Checking for untracked or changed files…"
	if [ -n "$(git ls-files htdocs --exclude-standard --others)" ]; then
		echo -e "${RED}You have untracked files, please remove or commit them before building:${NC}"
		git ls-files . --exclude-standard --others
		exit 3
	fi
	if ! git -c core.fileMode=false diff --quiet --exit-code htdocs; then
		echo -e "${RED}You have changes to tracked files, please reset or commit them before building:${NC}"
		git -c core.fileMode=false diff --stat
		exit 4
	fi

	# Maybe run a composer update too, then commit the lock?
	if [[ $COMPOSER_UPDATE == "yes" ]]; then
		./wrapper-composer.sh update
		if [ 0 != $? ]; then
			echo -e "${RED}Composer update to regenerate the lock file failed with code $?, something went wrong.${NC}"
			exit 5
		fi
		git add ./composer.lock
		git commit -m "Composer lock for: $COMMIT_MSG"
		echo "Composer updated, new composer.lock committed"
	fi

	# @FIXME: This code is pretty much duplicated in the vvv-init.sh script
	mkdir -p ~/.ssh
	touch ~/.ssh/known_hosts
	while read FINGERPRINT; do
		if ! grep -Fxq "$FINGERPRINT" ~/.ssh/known_hosts; then
			echo "Adding $(echo $FINGERPRINT |cut -d ' ' -f1) $(echo $FINGERPRINT |cut -d ' ' -f2) to ~$WHOAMI/.ssh/known_hosts"
			echo $FINGERPRINT >> ~/.ssh/known_hosts
		fi
	done < ssh/known_hosts

	echo "Testing authentication with $SITENAME on WPEngine…"
	# The quickest command I can find is `help`, but it still takes approx 2 seconds
	# (The command is executed on Gitolite at the WPEngine end, AFAICT)
	ssh -o "BatchMode yes" git@git.wpengine.com help 2>/dev/null 1>&2
	if [ 0 != $? ]; then
		echo -e "${RED}You need to add some SSH keys to this Vagrant, to allow the '$WHOAMI' user to Git push to $SITENAME on WPEngine${NC}"
		exit 5
	fi

	echo "Checking you have a Git user setup…"
	if [[ $(git config --list) != *user.email* || $(git config --list) != *user.name* ]]; then
		echo -e "${RED}Please set your user information in git, e.g. 'git config --global --add user.email dev@example.com; git config --global --add user.name \"Alistair Developer\";'${NC}"
		exit 6
	fi

	# BUILD THE PROJECT
	# =================

	echo "Creating a clean 'build' directory: git clone $INITIAL $INITIAL/build"
	git clone $INITIAL "$INITIAL/build"
	if [[ 0 != $? ]]; then
		echo -e "${RED}Failed to clone the working Git repository${NC}"
		exit 7
	fi
	echo "Creating a clean 'package' directory: git clone git@git.wpengine.com:production/$SITENAME.git $INITIAL/package"
	git clone git@git.wpengine.com:production/$SITENAME.git "$INITIAL/package"
	if [[ 0 != $? ]]; then
		echo -e "${RED}Failed to clone the WPEngine Git repository${NC}"
		exit 8
	fi
	cd $PACKAGE
	git remote rename origin production
	git remote add staging git@git.wpengine.com:staging/$SITENAME.git

	echo "Beginning the build…"
	cd $BUILD

	# This project doesn't include WP core in version control or in Composer
	echo "Downloading the latest core WordPress files…"
	wp core download --path=htdocs
	if [ 0 != $? ]; then
		echo -e "${RED}We could not download the WordPress core files.${NC}"
		exit 9
	fi
	echo "Running Composer…"
	# Preferring distribution, rather than source, should speed things up for WP.org
	# hosted plugins, and those plugins with stable releases for the versions we need.
	ssh-agent bash -c "ssh-add $INITIAL/ssh/cftp_deploy_id_rsa; composer install --prefer-dist"

	echo "Clean all the version control directories out of the build directory…"
	# Remove all version control directories
	find $BUILD/htdocs -name ".svn" -exec rm -rf {} \; 2> /dev/null
	find $BUILD/htdocs -name ".git*" -exec rm -rf {} \; 2> /dev/null

	echo "Removing the perfidious Hello Dolly (banned on WPEngine)"
	rm $BUILD/htdocs/wp-content/plugins/hello.php

	echo "Copying files to the package directory…"
	rm -rf $PACKAGE/*
	cp -pr htdocs/* $PACKAGE/
	cp -prv htdocs/.[a-zA-Z0-9]* $PACKAGE

	# Use a relevant .gitignore
	cp $INITIAL/.gitignore.wpengine $PACKAGE/.gitignore

	echo "Creating a Git commit for the changes…"
	# Add all the things! Even the deleted things!
	cd $PACKAGE
	git add -A .
	git commit -am "$COMMIT_MSG"

	# TIDY UP
	# =======

	rm -rf $BUILD
	echo -e "${GREEN}The site was built using the 'composer install' command, from 'composer.lock', and turned into a Git commit.${NC}"
	echo -e "${GREEN}Please examine the commit in the package directory ($PACKAGE) and push it to WP Engine if it is correct.${NC}"
	echo -e "${GREEN}You can delete the package directory after you're done.${NC}"
	exit 0 # Success!
)
