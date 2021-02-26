# @file SETUP.bash
# @brief Source this file to add the Portage Cluster Utils tools to your PATH in place.
#
# This configuration script is a convenient alternative that can be used to puth
# the scripts on your PATH in place instead of running "make install" inside
# src/scripts
#
# @author Eric Joanis
#
# Traitement multilingue de textes / Multilingual Text Processing
# Technologies numériques / Digital Technologies
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2021, Sa Majeste la Reine du Chef du Canada /
# Copyright 2021, Her Majesty in Right of Canada

echo "PortageClusterUtils, NRC-CNRC, (c) 2005 - 2021, Her Majesty in Right of Canada" >&2

SOURCE="${BASH_SOURCE[0]}"
if [[ -h $SOURCE ]]; then
    SOURCE=$(readlink -f $SOURCE)
fi
BASE_DIR="$( cd "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
echo "PortageClusterUtils path: $BASE_DIR" >&2
export PATH=$BASE_DIR/src/scripts:$PATH
