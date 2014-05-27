#!/bin/bash
# Takes a composer controlled repo, builds a clean copy in a "build" directory,
# transfers the elements we need (e.g. not .git dirs, etc) to a "package" directory
# and pushes a composed PACKAGE into a branch called "PACKAGE".

(
	# SANITY CHECKS

	# Ensure we've got a commit message

	if [ -z "$1" ]; then
		echo "Please provide a commit message, e.g. 'sh ./build.sh \"Phase 2 beta\"'"
		exit 0
	fi

	# Check for uncommitted changes, and refuse to proceed if there are any

	echo "Checking for untracked or changed files…"
	# if [ -n "$(git ls-files . --exclude-standard --others)" ]; then
	# 	echo "You have untracked files, please remove or commit them before building:"
	# 	git ls-files . --exclude-standard --others
	# 	exit 0
	# fi
	# if ! git -c core.fileMode=false diff --quiet --exit-code; then
	# 	echo "You have changes to tracked files, please reset or commit them before building:"
	# 	git -c core.fileMode=false diff --shortstat
	# 	exit 0
	# fi

	# @TODO: Check Git has been set up with a user name

	# SETUP

	echo "Setting up variables…"
	# Variables for the various directories, some temp dirs
	INITIAL=`pwd`
	# BUILD=`mktemp -d`
	# PACKAGE=`mktemp -d`
	BUILD='/srv/www/tmp.build'
	PACKAGE='/srv/www/tmp.package'
	PACKAGE_MSG=$1
	rm -rf $BUILD
	rm -rf $PACKAGE

	echo "BUILD dir $BUILD"
	echo "PACKAGE dir $PACKAGE"

	# BUILD THE PROJECT

	echo "Creating a clean 'build' directory…"
	git clone $INITIAL $BUILD

	echo "Creating a clean 'package' directory…"
	git clone $INITIAL $PACKAGE

	cd $BUILD

	# This project doesn't include WP core in version control or in Composer
	echo "Downloading the latest core WordPress files…"
	# wp core download --allow-root --path=htdocs
	echo "Running Composer…"
	ssh-agent bash -c "ssh-add $INITIAL/ssh/cftp_deploy_id_rsa; composer install --verbose;"

	cd $PACKAGE
	
	echo "Checking if there's already a build branch…"
	git show-ref --verify --quiet refs/heads/build; 
	if [ 0 = $? ]; then
		git checkout build
	else
		echo " * Creating a build branch…"
		git checkout -b build
	fi

	# Sequester the key .git stuff, before syncing
	# mv $PACKAGE/.git $PACKAGE/.gitignore.package
	# mv $PACKAGE/.gitignore.package $PACKAGE/.hiding.gitignore.package
	# Get the files under Git, and core, and move them to
	# the PACKAGE directory
	echo "Clean all the version control directories out of the build directory…"
	find $BUILD/htdocs -name ".svn" -exec rm -rf {} \; 2> /dev/null
	find $BUILD/htdocs -name ".git*" -exec rm -rf {} \; 2> /dev/null
	rm -rf $PACKAGE/*
	cp -pr $BUILD/htdocs/* $PACKAGE/

	# Remove all version control directories

	# Move our concealed .git stuff back
	mv $PACKAGE/.gitignore.package $PACKAGE/.gitignore

	echo "Creating a Git commit for the changes"
	# Add all the things! Even the deleted things!
	git add -A .
	git commit -am "$PACKAGE_MSG"
	exit

	# PULL THE BUILD COMMITS BACK INTO THE INITIAL REPO

	cd $INITIAL
	
	echo "Checking if there's already a build branch…"
	git show-ref --verify --quiet refs/heads/build; 
	if [ 0 = $? ]; then
		git checkout build
	else
		echo " * Creating a build branch…"
		git checkout --orphan build
		git rm --cached -r .
	fi
	exit
	git pull package build
	# TODO: Save the initial branch, and switch back to it rather than assuming master
	git checkout master

	# Tidy up
	rm -rf $PACKAGE
	rm -rf $BUILD
)
