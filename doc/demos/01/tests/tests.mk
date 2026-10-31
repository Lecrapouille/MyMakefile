# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# Paths are relative to this directory.

TARGETS += UnitTest-HelloWorld01
UnitTest-HelloWorld01.TYPE := test
UnitTest-HelloWorld01.SOURCES := ../src/foo.cpp unit-tests.cpp
UnitTest-HelloWorld01.INCLUDES := ../src
UnitTest-HelloWorld01.DEFINES := FOO
