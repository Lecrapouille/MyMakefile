# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# Demo 01: an application and its unit tests, declared in tests/tests.mk.

PROJECT_NAME := TutorialMyMakefile
PROJECT_VERSION := 0.1.0
COMPILATION_MODE ?= release

TARGETS := HelloWorld01
HelloWorld01.DESCRIPTION := Hello World
HelloWorld01.SOURCES := src/*.cpp
HelloWorld01.INCLUDES := src
HelloWorld01.DEFINES := FOO
HelloWorld01.PROJECT_INFO := 1

SUBMAKEFILES := tests/tests.mk

include ../../../MyMakefile.mk
