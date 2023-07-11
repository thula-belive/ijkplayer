#!/bin/bash

# variables
FRAMEWORK_NAME=""
SCHEME_NAME=""
PATH_TEMP=""
PATH_SIMULATOR_BUILD=""
PATH_DEVICE_BUILD=""
PATH_TARGET=""
PATH_OUTPUT=""
PATH_LIBS=""
IS_DEBUG=false

TEXT_NORMAL=$(tput sgr0)
TEXT_BOLD=$(tput bold)
TEXT_BOLD_RED=${TEXT_BOLD}$(tput setaf 1)

echo "${TEXT_BOLD}Read input parameters${TEXT_NORMAL}"
while getopts n:d: flag
do
  case "${flag}" in
    n) FRAMEWORK_NAME=${OPTARG};;
    d) 
			if [ ${OPTARG} == "true" ]; then
				IS_DEBUG=true
			fi
    ;;
  esac
done

if [ $FRAMEWORK_NAME == "" ]; then
	echo "${TEXT_BOLD_RED}Framework Name is empty. ABORT!${TEXT_NORMAL}"
	exit 1
else
	SCHEME_NAME="$FRAMEWORK_NAME"
	PATH_TEMP="$(pwd)/.tmp/$FRAMEWORK_NAME"
	PATH_SIMULATOR_BUILD="$PATH_TEMP/simulator"
	PATH_DEVICE_BUILD="$PATH_TEMP/device"
	PATH_TARGET="${PATH_TEMP}/${FRAMEWORK_NAME}"
	PATH_OUTPUT="$(pwd)/framework"
fi

if [ $IS_DEBUG == true ]; then
	echo "FRAMEWORK_NAME: $FRAMEWORK_NAME"
	echo "WORKSPACE_NAME: $WORKSPACE_NAME"
	echo "SCHEME_NAME: $SCHEME_NAME"
	echo "PATH_TARGET: $PATH_TARGET"
fi

# delete build directory if needed
if [ -d "$PATH_TEMP" ]; then
	rm -rf "${PATH_TEMP}"
	echo "Delete ${PATH_TEMP}"
fi

# make sure the build directory exists
mkdir -p "${PATH_TARGET}"

echo "${TEXT_BOLD}Archive framwork for simulator${TEXT_NORMAL}"
if [ $FRAMEWORK_NAME == "IJKMediaFramework" ]; then
	xcodebuild archive \
				-quiet \
				-project "IJKMediaPlayer.xcodeproj" \
				-scheme "${SCHEME_NAME}" \
				-sdk iphonesimulator \
				-arch arm64 \
				-arch x86_64 \
				-archivePath "${PATH_SIMULATOR_BUILD}" \
				-configuration Release \
					SKIP_INSTALL=NO \
	   			clean archive \
	   			BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
else
	xcodebuild archive \
			-quiet \
			-project "IJKMediaPlayer.xcodeproj" \
			-scheme "${SCHEME_NAME}" \
			-sdk iphonesimulator \
			-arch x86_64 \
			-archivePath "${PATH_SIMULATOR_BUILD}" \
			-configuration Release \
				SKIP_INSTALL=NO \
   			clean archive \
   			BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
fi

echo "${TEXT_BOLD}Archive framwork for real device${TEXT_NORMAL}"
xcodebuild archive \
			-quiet \
			-project "IJKMediaPlayer.xcodeproj" \
			-scheme "${SCHEME_NAME}" \
			-sdk iphoneos \
			-arch arm64 \
			-archivePath "${PATH_DEVICE_BUILD}" \
			-configuration Release \
				SKIP_INSTALL=NO \
   			clean archive \
   			BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

echo "${TEXT_BOLD}Create xcframework${TEXT_NORMAL}"
xcodebuild -create-xcframework \
			-framework "${PATH_SIMULATOR_BUILD}.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
			-framework "${PATH_DEVICE_BUILD}.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
			-output "${PATH_TARGET}/${FRAMEWORK_NAME}.xcframework"

# make sure the result folder exists
PATH_RESULT="${PATH_OUTPUT}/${FRAMEWORK_NAME}"
mkdir -p "${PATH_RESULT}"
cp 	-R 	"${PATH_TARGET}/" \
		"${PATH_RESULT}/"

echo "${TEXT_BOLD}Cleanup${TEXT_NORMAL}"
rm -rf "${PATH_TEMP}"

# CHECK FOR ANY ERROR
if [ $? != 0 ] ; then
	echo ""
	echo "${TEXT_BOLD_RED}** ARCHIVE FAILED **${TEXT_NORMAL}"
  echo ""
	xcodebuild -list
	echo ""
	exit 1
else 
	echo "${TEXT_BOLD}** ARCHIVE ${FRAMEWORK_NAME}.xcframework SUCCEEDED **${TEXT_NORMAL}"
fi 
