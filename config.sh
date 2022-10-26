#!/bin/bash
##==================================================================================
## MIT License
##
## Copyright (c) 2019 Quentin Quadrat <lecrapouille@gmail.com>
##
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to deal
## in the Software without restriction, including without limitation the rights
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
##
## The above copyright notice and this permission notice shall be included in all
## copies or substantial portions of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
## SOFTWARE.
##==================================================================================

# From the file VERSION and the current git SHA1, this script generates
# the build/version.h with these informations. This project uses them
# in log files, in "about" windows ... This script is called by Makefile.

source $2/project_info.txt

### Get major and minor version from VERSION file (given as $1)
VERSION=`grep "[0-9]\+\.[0-9]\+" $1 2> /dev/null`
if [ "$VERSION" == "" ];
then
  echo "$0 ERROR: VERSION file is missing or badly formed. Abort !"
  exit 1
fi
MAJOR_VERSION=`echo "$VERSION" | cut -d'.' -f1`
MINOR_VERSION=`echo "$VERSION" | cut -d'.' -f2`

### Get git SHA1 and branch
SHA1=`git log 2> /dev/null | head -n1 | cut -d" " -f2`
BRANCH=`git rev-parse --abbrev-ref HEAD 2> /dev/null`

### Debug
echo "Project version: $MAJOR_VERSION.$MINOR_VERSION"
echo "Git branch $BRANCH SHA1 $SHA1"
echo ""
BUILD_TYPE=`[ "$BUILD_TYPE" == "debug" ] && echo "true" || echo "false"`

### Header guard
GUARD=`echo "${PROJECT}_${TARGET}_GENERATED_PROJECT_INFO_HPP" | tr '[:lower:]' '[:upper:]' | tr "\-." "__"`

### Save these informations as C++ header file
cat <<EOF >$2/project_info.hpp
#ifndef ${GUARD}
#  define ${GUARD}

#  include <cstdint>

namespace project
{
  static Info info(
    // Compiled in debug or released mode
    ${BUILD_TYPE},
    // Project name used for logs and GUI.
    "${TARGET}",
    // Major version of project
    ${MAJOR_VERSION}u,
    // Minor version of project
    ${MINOR_VERSION}u,
    // git SHA1
    "${SHA1}",
    // git branch
    "${BRANCH}",
    // Pathes where default project resources have been installed
    // (when called  by the shell command: sudo make install).
    "${PROJECT_DATA_PATH}",
    // Location for storing temporary files
    "${PROJECT_TEMP_DIR}/",
    // Give a name to the default project log file.
    "${TARGET}.log",
    // Define the full path for the project.
    "${PROJECT_TEMP_DIR}/${TARGET}.log"
  );
}

#endif // ${GUARD}
EOF

exit 0
