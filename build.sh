#!/bin/bash
# Takes a composer controlled repo and pushes a
# composed PACKAGE into a branch called "PACKAGE".

(
	# SANITY CHECKS

	# Check for uncommitted changes, and refuse to proceed if there are any

	if [ -n "$(git ls-files . --exclude-standard --others)" ]; then
		echo "You have untracked files, please remove or commit them before building."
		exit 0
	fi
	if ! git diff --quiet --exit-code; then
		echo "You have changes to tracked files, please reset or commit them before building."
		exit 0
	fi

	# Ensure we've got a commit message

	if [ -z "$1" ]; then
		echo "Please provide a commit message, e.g. 'sh ./build.sh \"Phase 2 beta\"'"
		exit 0
	fi
	PACKAGE_MSG=$1

	# SETUP

	# Variables for the various directories, some temp dirs
	INITIAL=`pwd`
	# BUILD=`mktemp -d`
	# PACKAGE=`mktemp -d`
	# BUILD='/srv/www/tmp.build'
	# PACKAGE='/srv/www/tmp.package'
	rm -rf $BUILD
	rm -rf $PACKAGE

	echo "BUILD dir $BUILD"
	echo "PACKAGE dir $PACKAGE"

	# BUILD THE PROJECT

	git clone $INITIAL $BUILD
	cd $BUILD
	# This project doesn't include WP core in version control or in Composer
	# wp core download --allow-root --path=htdocs
	ssh-agent bash -c "ssh-add $INITIAL/ssh/cftp_deploy_id_rsa; composer install --verbose;"

	git clone $INITIAL $PACKAGE
	cd $PACKAGE
	# Check if there's already a build branch
	git show-ref --verify --quiet refs/heads/build; 
	if [ 0 = $? ]; then
		git checkout build
	else
		git checkout -b build
	fi
	# git remote add initial $INITIAL
	# git remote show origin
	# git remote show initial

	# Sequester the key .git stuff, before syncing
	mv $PACKAGE/.git $PACKAGE/.hiding
	mv $PACKAGE/.gitignore.build $PACKAGE/.hiding.gitignore.build
	# Get the files under Git, and core, and move them to
	# the PACKAGE directory
	rsync -a --exclude "- .hiding*" --exclude "- .git*" --exclude "- .svn/" --delete $BUILD/ $PACKAGE/

	# Remove all version control directories
	find htdocs -name ".svn" -exec rm -rf {} \;
	find htdocs -name ".git*" -exec rm -rf {} \;

	# Move our concealed .git stuff back
	mv $PACKAGE/.hiding $PACKAGE/.git
	mv $PACKAGE/.hiding.gitignore.build $PACKAGE/.gitignore

	exit

	# Add all the things! Even the deleted things!
	git add -A .

	pwd

	git commit -am "$PACKAGE_MSG"
	# Now pull the PACKAGE branch commits back to the initial repo
	cd $INITIAL
	git checkout build
	git pull package build
	# TODO: Save the initial branch, and switch back to it rather than assuming master
	git checkout master

	# Tidy up
	rm -rf $PACKAGE
	rm -rf $BUILD
)