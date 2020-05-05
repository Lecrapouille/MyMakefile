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

source $2/config.txt

### Get major and minor version from VERSION file (given as $1)
VERSION=`grep "[0-9]\+\.[0-9]\+" $1 2> /dev/null`
if [ "$VERSION" == "" ];
then
  echo "ERROR: VERSION file is missing or badly formed. Abort !"
  exit 1
fi
MAJOR_VERSION=`echo "$VERSION" | cut -d'.' -f1`
MINOR_VERSION=`echo "$VERSION" | cut -d'.' -f2`

### Get git SHA1 and branch
SHA1=`git log 2> /dev/null | head -n1 | cut -d" " -f2`
BRANCH=`git branch 2> /dev/null | head -n1 | cut -d" " -f2`

### Debug
echo "Project version: $MAJOR_VERSION.$MINOR_VERSION"
echo "git: $BRANCH $SHA1"
echo ""
BUILD_TYPE=`[ "$BUILD_TYPE" == "debug" ] && echo "true" || echo "false"`

### Header guard
GUARD=`echo "${PROJECT}_${TARGET}_GENERATED_CONFIG_HPP" | tr '[:lower:]' '[:upper:]' | tr "a-" "_"`

### Save these informations as C++ header file
cat <<EOF >$2/config.hpp
#ifndef ${GUARD}
#  define ${GUARD}

#  include <string>

namespace config
{
  //! \brief Compiled in debug or released mode
  const bool debug = ${BUILD_TYPE};
  //! \brief Used for logs and GUI.
  const std::string project_name("${TARGET}");
  //! \brief Major version of project
  const uint32_t major_version(${MAJOR_VERSION}u);
  //! \brief Minor version of project
  const uint32_t minor_version(${MINOR_VERSION}u);
  //! \brief Save the git SHA1
  const std::string git_sha1("${SHA1}");
  //! \brief Save the git branch
  const std::string git_branch("${BRANCH}");
  //! \brief Pathes where default project resources have been installed
  //! (when called  by the shell command: sudo make install).
  const std::string data_path("${PROJECT_DATA_PATH}");
  //! \brief Location for storing temporary files
  const std::string tmp_path("${PROJECT_TEMP_DIR}/");
  //! \brief Give a name to the default project log file.
  const std::string log_name(project_name + ".log");
  //! \brief Define the full path for the project.
  const std::string log_path(tmp_path + log_name);
}

#endif // ${GUARD}
EOF

exit 0
