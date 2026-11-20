#!/bin/bash
##########################################################################
# If not stated otherwise in this file or this component's Licenses.txt
# file the following copyright and licenses apply:
#
# Copyright 2024 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

#Package name can be provided as command line argument
tdk_package=$1

uninstall=false

if [ "$1" == "--uninstall" ]; then
    uninstall=true
fi

if $uninstall; then
    file=".tdk_extracted_files.log"
    if [ ! -f $file ];then
        echo "TDK Package is not installed in the device"
        echo "Uninstall is revoked"
        exit
    fi

    echo "Stopping TDK Service"
    systemctl stop tdk
    echo "Deleting all TDK libs and bins"
    while IFS= read -r path; do
        if [ -f "$path" ]; then
            rm "$path"
        fi
    done < "$file"
    echo "Deleting TDK specific directories"
    rm -rf /var/TDK
    rm -rf /opt/TDK
    exit
fi

start_tdk() {
    echo -e "\nExtract TDK files to respective folders \n"
    log_file=".tdk_extracted_files.log"
    # Use the tar command with error checking
    if ! tar -xvzf $tdk_package | tee $log_file; then
        echo "Error extracting $tdk_package. Exiting."
        exit 1
    fi

    additionalLibsDir="/additional_libs"
    if [ -d "$additionalLibsDir" ]; then
        echo "The directory $additionalLibsDir exists."
        echo "Copying additional libs to /usr/lib"
        cp "${additionalLibsDir}"/lib* /usr/lib
        for lib in "${additionalLibsDir}"/lib/*; do
            lib_name=$(basename "$lib")
            echo "/usr/lib/$lib_name" >> "$log_file"
        done
    fi

    additionalBinsDir="/additional_bins"
    if [ -d "$additionalBinsDir" ]; then
        echo "The directory $additionalBinsDir exists."
        echo "Copying additional bins to /usr/bin"
        cp "${additionalBinsDir}"/* /usr/bin
        for app in "${additionalBinsDir}"/*; do
            app_name=$(basename "$app")
            echo "/usr/lib/$app_name" >> "$log_file"
        done
    fi


    [ ! -f "/opt/TDK/.no_tdk_agent" ] && tdk_agent_present=1 || tdk_agent_present=0

    if [ $tdk_agent_present -ne 0 ];then
        echo -e "\nEnable TDK service\n"
        systemctl enable tdk
        sleep 1
        echo -e "Going to start tdk service\n"
        sleep 1
        systemctl restart tdk
    fi
}

# Check if TDK_Package.tar.gz is present in / folder.
cd /

if [[ -z "$tdk_package" ]]; then
   echo "Packagename is not provided as command line argument"
   echo "Searching for package name \"TDK_Package*tar.gz\" "
   tdk_package=`ls /TDK_Package*tar.gz | head -n 1`
   echo -e "Processing $tdk_package\n"
fi


if [ -f "/$tdk_package" ]; then
    start_tdk && echo "TDK Package installed successfully"
else
    echo -e "Please copy the TDK_Package.tar.gz file to / folder in the device"
fi
