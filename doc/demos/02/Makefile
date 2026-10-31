# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# Demo 02: an application linked against two libraries, each declared in the
# directory of its sources.

PROJECT_NAME := TutorialMyMakefile
PROJECT_VERSION := 0.1.0

TARGETS := HelloWorld02
HelloWorld02.SOURCES := src/main.cpp
HelloWorld02.DEPENDS := foo bar

TARGET_FILES := src/foo/foo.mk src/bar/bar.mk

include ../../../MyMakefile.mk
