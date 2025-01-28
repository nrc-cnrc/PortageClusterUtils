# @file SETUP.bash
# @brief Source this file to add the Portage Cluster Utils tools to your PATH in place.
#
# GPSC psub initialization
# 
#
# @author Marc Tessier
#
# Traitement multilingue de textes / Multilingual Text Processing
# Technologies numériques / Digital Technologies
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2025, Sa Majeste le Roi du Chef du Canada /
# Copyright 2025, His Majesty the King in Right of Canada

#Set to your assigned project name
export PSUB_PROJECT_NAME=nrc_ict



echo "PortageClusterUtils, NRC-CNRC, (c) 2005 - 2025, His Majesty the King in Right of Canada" >&2
SOURCE="${BASH_SOURCE[0]}"
if [[ -h $SOURCE ]]; then
    SOURCE=$(readlink -f "$SOURCE")
fi
BASE_DIR="$( cd "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
echo "PortageClusterUtils path: $BASE_DIR" >&2
export PATH=$BASE_DIR/bin:$PATH


# Set default container OS.
if grep "CentOS Linux release 7" /etc/centos-release >& /dev/null; then
    export PSUB_RES_IMAGE=${PSUB_RES_IMAGE_OVERRIDE:-nrc/nrc_all_default_centos-7-amd64_latest}
elif grep "Ubuntu 20" /etc/os-release >& /dev/null; then
    export PSUB_RES_IMAGE=${PSUB_RES_IMAGE_OVERRIDE:-nrc/nrc_all_default_ubuntu-20.04-amd64_latest}
elif grep "Ubuntu 22" /etc/os-release >& /dev/null; then
    export PSUB_RES_IMAGE=${PSUB_RES_IMAGE_OVERRIDE:-nrc/nrc_all_default_ubuntu-22.04-amd64_latest}
fi

