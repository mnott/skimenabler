#!/bin/bash
###################################################
#
# Small Helper that makes Skim work with Sierra
#
###################################################
# (c) Matthias Nott, SAP. Licensed under WTFPL.
###################################################

###################################################
#
# Configurations
#
###################################################

#
# Your Location of Skim.app
#
SKIM=/Applications/Skim.app

#
# To work, needs to be the exact same length as
#
#      /System/Library/Frameworks/Quartz.framework
#
QUARKS=/Applications/Skim.app/Contents/Q.framework

#
# Whether to check SIP
#
SIPCHECK=false

#
# Whether to check for being root
#
ROOTCHECK=false

###################################################
#
# End of Configuration. You should not need to
# touch anything below.
#
###################################################

#
# Get the directory from which this script runs
#
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

###################################################
#
# Some Variables for Colors
#

ERR='\033[0;41;30m'
RED='\033[0;31m'
BLU='\033[0;34m'
GRE='\033[0;32m'
STD='\033[0;0;39m'

#
###################################################

#
# Helper for showing how to disable SIP
#
sipdisable(){
cat <<EOF
System Integrity Protection is turned on. You need to
disable it for this script to work. To do so,

1. Reboot the Mac and hold down Command + R keys
   simultaneously after you hear the startup chime.
   this will boot OS X into Recovery Mode.
2. Choose your languge if asked to. When the
   OS X Utilities screen appears, pull down the
   Utilities menu at the top of the screen instead,
   and choose Terminal
3. Type the following command into the terminal then
   hit return:

   csrutil disable; reboot

4. You'll see a message saying that System Integrity
   Protection has been disabled and the Mac needs to
   restart for changes to take effect, and the Mac will
   then reboot itself automatically, just let it boot
   up as normal.

After running this script, you will be able to re-enable
System Integrity Protection; to do so, follow the same
procedure as above, but just say enable instead of
disable:

   csrutil enable; reboot

EOF
}

#
# Show a colorful welcome message
#
welcome(){
  echo ""
  echo -e "${GRE} ____  _  _____ __  __   _____             _     _"
  echo -e "/ ___|| |/ /_ _|  \/  | | ____|_ ${RED}WELCOME${GRE} _| |__ | | ___ _ __"
  echo -e "\___ \| ' / | || |\/| | |  _| | '_ \ / _\` | '_ \| |/ _ \ '__|"
  echo -e " ___) | . \ | || |  | | | |___| | | | (_| | |_) | |  __/ |"
  echo -e "|____/|_|\_\___|_|  |_| |_____|_| |_|\__,_|_.__/|_|\___|_|${STD}"
  echo ""
}

#
# Write a colorful section header
#
section() {
  MSG=$*
  echo ""
  echo -e "${BLU}----------------------------------------------------------${STD}"
  echo -e "${GRE}   $MSG ${STD}"
  echo -e "${BLU}----------------------------------------------------------${STD}"
  echo ""
}

#
# Write a colorful error message
#
error() {
  MSG=$*
  echo ""
  echo -e "${ERR}  ERROR:  ${RED}  $MSG ${STD}"
  echo ""
}


#
# Binary Patch a File
#
# @param $1 The file to patch
#
patch() {
  FILE=$1

  section Patching $FILE...

  #
  # We point from Quartz to Quarks...
  #
  OLD=/System/Library/Frameworks/Quartz.framework
  NEW="$QUARKS"

  oldl=$(echo ${#OLD})
  newl=$(echo ${#NEW})

  if [[ ! $oldl -eq $newl ]]; then
    error $OLD does not have the same length as $NEW
    exit 1
  fi

  #
  # Check whether we have our helpers/patch.pl
  #
  if [[ ! -f "$DIR"/helpers/patch.pl ]]; then
     error Did not find $DIR/helpers/patch.pl
     exit 1
  fi

  #
  # Check whether we have been given a file that exists
  #
  if [[ ! -f "$FILE" ]]; then
     error $FILE not found
     exit 1
  fi

  #
  # Backup the File to Patch
  #
  if [[ ! -f "$FILE".ori ]]; then
     echo Creating a backup:
     echo of  $FILE
     echo to  $FILE.ori
     cp -a "$FILE" "$FILE".ori
  fi

  if [[ ! -f "$FILE".ori ]]; then
     error Could for some reason not backup $FILE to $FILE.ori
     exit 1
  fi

  #
  # Execute the Patch
  #
  "$DIR"/helpers/patch.pl "$FILE" -all -o $OLD -n $NEW

  #
  # Verify the output exists and replace the the input with it
  #
  if [[ ! -f "$FILE".out ]]; then
     error Did not find $FILE.out. Assuming the patch ran into an error
     exit 1
  fi

  mv "$FILE".out "$FILE"
}

#
# Welcome
#
welcome

#
# Verifications
#
section Running Verifications...

#
# Check whether we are root
#
if [[ "$ROOTCHECK" == "true" ]]; then
  if [[ "$(id -u)" != "0" ]]; then
    error This script must be run as root
    exit 1
  fi
fi

#
# Test whether we have disabled System Integrity Protection
#
if [[ "$SIPCHECK" == "true" ]]; then
  SIP=$(LANG=C csrutil status|grep ensabled)

  if [[ "" != "$SIP" ]]; then
    error System Integrity Protection active.
    sipdisable
    exit 1
  fi
fi

#
# Check whether we have Skim
#
if [[ ! -d "$SKIM" ]]; then
   error Did not find Skim.app here: $SKIM
   exit 1
fi

#
# Check whether we have the Mavericks PDFKit
#
if [[ ! -d "$DIR"/redist/Quarks.framework ]]; then
   error Did not find $DIR/helpers/Quarks.framework
   exit 1
fi

#
# Check whether we have the original Quartz Framework
#
if [[ ! -f /System/Library/Frameworks/Quartz.framework/Versions/Current/Quartz ]]; then
   error Did not find /System/Library/Frameworks/Quartz.framework/Versions/Current/Quartz
   exit 1
fi

#
# Copy the original Quartz, since we need to patch it
#
section Copying the original Quartz Framework...
cp /System/Library/Frameworks/Quartz.framework/Versions/Current/Quartz "$DIR"/redist/Quarks.framework/Versions/A/

#
# Patch the copy of the Quartz framework
#
section Patching the copy of the Quartz Framework...
if [[ ! -f "$DIR"/redist/Quarks.framework/Versions/A/Quartz ]]; then
   error Did not create "$DIR"/redist/Quarks.framework/Versions/A/Quartz
   exit 1
fi
echo 1
patch "$DIR"/redist/Quarks.framework/Versions/A/Quartz
echo 2
section Deploying of the Quarks Framework...
#
# If there already is a Quarks Framework, remove it
#
if [[ -d "$QUARKS" ]]; then
   echo Found ${QUARKS}. Removing it.
   rm -rf "$QUARKS"
fi

#
# Copy the Quarks Framework to $QUARKS
#
echo ""
echo Deploying:
echo of  "$DIR"/redist/Quarks.framework
echo to  "$QUARKS"
cp -a "$DIR"/redist/Quarks.framework "$QUARKS"

if [[ ! -d "$QUARKS" ]]; then
   error Apparently had a problem deploying $QUARKS
   exit 1
fi

#
# Patch Skim
#
# I found
#
#   /System/Library/Frameworks/Quartz.framework
#
# in these files:
#
# "$SKIM"/Contents/Frameworks/SkimNotes.framework/Versions/A/SkimNotes
# "$SKIM"/Contents/Library/Spotlight/SkimImporter.mdimporter/Contents/MacOS/SkimImporter
# "$SKIM"/Contents/MacOS/Skim
# "$SKIM"/Contents/SharedSupport/skimpdf
#
# Even though for some reason it appars we don't even need to patch any
# of them once we have deployed the Quarks variant, we'll just patch all
# of them.
#
# TODO: Investigate further. Maybe load sequence
#
patch "$SKIM"/Contents/Frameworks/SkimNotes.framework/Versions/A/SkimNotes
patch "$SKIM"/Contents/Library/Spotlight/SkimImporter.mdimporter/Contents/MacOS/SkimImporter
patch "$SKIM"/Contents/MacOS/Skim
patch "$SKIM"/Contents/SharedSupport/skimpdf


#
# Done
#
section Done.
