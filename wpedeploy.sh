#!/bin/bash
# Version: 2.2.1
# Last Update: March 15, 2020
#
# Description: Bash script to deploy a Bedrock WordPress project to WP Engine's hosting platform
# Repository: https://github.com/hello-jason/bedrock-deploy-to-wpengine.git
# README: https://github.com/hello-jason/bedrock-deploy-to-wpengine/blob/master/README.md
#
# Tested Bedrock Version: 1.13.1
# Tested bash version: 4.3.42
# Author: Jason Cross
# Author URL: https://hellojason.net/
########################################
# Usage
########################################
# bash wpedeploy.sh nameOfRemote

########################################
# Thanks
########################################
# Thanks to [schrapel](https://github.com/schrapel/wpengine-bedrock-build) for
# providing some of the foundation for this script.
# Also thanks to [cmckni3](https://github.com/cmckni3) for guidance and troubleshooting

########################################
# Set variables
########################################
# WP Engine remote to deploy to
wpengineRemoteName=$1
# Get current branch user is on
currentLocalGitBranch=`git rev-parse --abbrev-ref HEAD`
# Temporary git branch for building and deploying
tempDeployGitBranch="wpedeployscript/${currentLocalGitBranch}"
# Set message colours
red="\033[0;31m"
cyan="\033[0;36m"
green="\033[0;32m"
noColour="\033[0m"


########################################
# Perform checks before running script
########################################

# Halt if there are uncommitted files
function check_uncommited_files () {
  if [[ -n $(git status -s) ]]; then
    echo -e "[${red}ERROR${noColour}]${red} Found uncommitted files on current branch \"$currentLocalGitBranch\".\nReview and commit changes to continue."
    git status
    exit 1
  fi
}

# Check if specified remote exists
function check_remote_exists () {
  echo "Checking if specified remote exists..."
  git ls-remote "$wpengineRemoteName" &> /dev/null
  if [ "$?" -ne 0 ]; then
    echo -e "[${red}ERROR${noColour}]${red} Unknown git remote \"$wpengineRemoteName\"\nVisit ${cyan}https://wpengine.com/git/${red} to set this up."
    echo "Available remotes:"
    git remote -v
    exit 1
  fi
}

# Gets current timestamp when called
function timestamp () {
  date
}

########################################
# Begin deploy process
########################################
function deploy () {
  # Checkout new temporary branch
  echo -e "Preparing theme on branch ${tempDeployGitBranch}..."
  git checkout -b "$tempDeployGitBranch" &> /dev/null

  # Run composer
  composer install
  # Setup directory structure
  mkdir wp-content && mkdir wp-content/themes && mkdir wp-content/plugins && mkdir wp-content/mu-plugins
  # Copy meaningful contents of web/app into wp-content
  cp -rp web/app/plugins wp-content && cp -rp web/app/themes wp-content && rsync -avq --exclude="bedrock-autoloader.php" --exclude="disallow-indexing.php" --exclude="register-theme-directory.php" web/app/mu-plugins/ wp-content/mu-plugins

  ########################################
  # Push to WP Engine
  ########################################
  # WPE-friendly gitignore
  echo -e "# Ignore everything\n/*\n\n# Except this...\n!wp-content/\n!wp-content/**/*" > .gitignore
  git rm -r --cached . &> /dev/null
  # Find and remove nested git repositories
  rm -rf $(find wp-content -name ".git")
  rm -rf $(find wp-content -name ".github")

  git add --all
  git commit -m "Automated deploy of \"$tempDeployGitBranch\" branch on $(timestamp)"
  echo "Pushing to WP Engine..."

  # Push to a remote branch with a different name
  # git push remoteName localBranch:remoteBranch
  git push "$wpengineRemoteName" "$tempDeployGitBranch":master --force

  ########################################
  # Back to a clean slate
  ########################################
  git checkout "$currentLocalGitBranch" &> /dev/null
  rm -rf wp-content/ &> /dev/null
  git branch -D "$tempDeployGitBranch" &> /dev/null
  echo -e "[${green}DONE${noColour}]${green} Deployed \"$tempDeployGitBranch\" to \"$wpengineRemoteName\""
}

########################################
# Execute
########################################
# Checks
check_uncommited_files
check_remote_exists

# Uncomment the following line for debugging
# set -x

# Deploy process
deploy
