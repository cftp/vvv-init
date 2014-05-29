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
	# SETUP AND SANITY CHECKS
	# =======================

	while getopts m:s: OPTION 2>/dev/null; do
	        case "${OPTION}"
	        in
	                m) COMMIT_MSG=${OPTARG};;
	                s) SITENAME=${OPTARG};;
	        esac
	done

	if [ -z "$COMMIT_MSG" ]; then
		echo "Please provide a commit message, e.g. 'sh ./build.sh -m \"Phase 2 beta\"'"
		exit 0
	fi

	if [ -z "$SITENAME" ]; then
		echo "Please provide a sitename within WP Engine, this will control the Git repo we clone and commit to, e.g. 'sh ./build.sh -s \"somesitename\"'"
		exit 0
	fi

	# Check for uncommitted changes, and refuse to proceed if there are any

	echo "Checking for untracked or changed files…"
	if [ -n "$(git ls-files . --exclude-standard --others)" ]; then
		echo "You have untracked files, please remove or commit them before building:"
		git ls-files . --exclude-standard --others
		exit 0
	fi
	if ! git -c core.fileMode=false diff --quiet --exit-code; then
		echo "You have changes to tracked files, please reset or commit them before building:"
		git -c core.fileMode=false diff --shortstat
		exit 0
	fi

	# @TODO: Check Git has been set up with a user name

	# @TODO: Test authentication to WPEngine Git SSH, 0 is good
	# ssh -o "BatchMode yes" git@git.wpengine.com info >>/dev/null; echo $?

	# Variables for the various directories, some temp dirs
	INITIAL=`pwd`
	WHOAMI=`whoami`
	BUILD="$INITIAL/build"
	PACKAGE="$INITIAL/package"
	rm -rf $BUILD
	rm -rf $PACKAGE

	# @FIXME: This code is pretty much duplicated in the vvv-init.sh script
	mkdir -p ~/.ssh
	touch ~/.ssh/known_hosts
	while read KNOWN_HOST; do
		if ! grep -Fxq "$KNOWN_HOST" ~/.ssh/known_hosts; then
		    echo "Adding host to SSH known_hosts for user '$(whoami)': $KNOWN_HOST"
		    echo $KNOWN_HOST >> ~/.ssh/known_hosts
		fi
	done < ssh/known_hosts

	# BUILD THE PROJECT
	# =================

	echo "Creating a clean 'build' directory…"
	git clone $INITIAL build

	echo "Creating a clean 'package' directory: git clone $DESTINATION_REPO package"
	git clone git@git.wpengine.com:production/$SITENAME.git package
	cd $PACKAGE
	git remote rename origin production
	git remote add staging git@git.wpengine.com:staging/$SITENAME.git

	echo "Beginning the build…"
	cd $BUILD

	# This project doesn't include WP core in version control or in Composer
	echo "Downloading the latest core WordPress files…"
	wp core download --allow-root --path=htdocs
	echo "Running Composer…"
	ssh-agent bash -c "ssh-add $INITIAL/ssh/cftp_deploy_id_rsa; composer install --verbose;"


	echo "Clean all the version control directories out of the build directory…"
	# Remove all version control directories
	find $BUILD/htdocs -name ".svn" -exec rm -rf {} \; 2> /dev/null
	find $BUILD/htdocs -name ".git*" -exec rm -rf {} \; 2> /dev/null

	echo "Copying files to the package directory…"
	rm -rf $PACKAGE/*
	cp -pr htdocs/* $PACKAGE/
	cp -prv htdocs/.[a-zA-Z0-9]* $PACKAGE

	# Use a relevant .gitignore
	cp $INITIAL/.gitignore.package $PACKAGE/.gitignore

	echo "Creating a Git commit for the changes…"
	# Add all the things! Even the deleted things!
	cd $PACKAGE
	git add -A .
	git commit -am "$COMMIT_MSG"

	# TIDY UP
	# =======

	rm -rf $BUILD
	echo "Please examine the commit in the package directory ($PACKAGE) and push it to WP Engine if it is correct."
	exit 0
)