# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
#
# MyMakefile 3: include this file at the end of the Makefile of the project.
#
#   PROJECT_NAME := MyProject
#   PROJECT_VERSION := 1.0.0
#   CXX_STANDARD := c++17
#
#   TARGETS += mylib
#   mylib.TYPE := library
#   mylib.SOURCES := src/**/*.cpp
#   mylib.PUBLIC_INCLUDES := include
#
#   TARGET_FILES := app/app.mk tests/tests.mk
#
#   include .makefile/MyMakefile.mk
#
# Paths written in a file of TARGET_FILES are relative to the directory of
# that file. That directory is also in HERE while the file is read.

MYMAKEFILE := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
MYMAKEFILE_VERSION := 3.0.0-experimental

include $(MYMAKEFILE)/engine/functions.mk

# 4.2 for $(file <): the stamps are read with it.
_mm_make_major := $(call _mm_version_field,1,$(MAKE_VERSION))
_mm_make_minor := $(call _mm_version_field,2,$(MAKE_VERSION))
ifeq ($(or $(call _mm_ge,$(_mm_make_major),5),$(and $(filter 4,$(_mm_make_major)),$(call _mm_ge,$(_mm_make_minor),2))),)
    $(error MyMakefile needs GNU Make 4.2 or newer, this is $(MAKE_VERSION). macOS: brew install make, then use gmake)
endif

###############################################################################
# Project and build configuration
###############################################################################

ifndef PROJECT_NAME
    $(error MyMakefile: PROJECT_NAME is not set)
endif
PROJECT_VERSION ?= 0.0.0
CXX_STANDARD ?= c++17
C_STANDARD ?=
COMPILATION_MODE ?= normal
ifeq ($(filter debug normal release,$(COMPILATION_MODE)),)
    $(error MyMakefile: COMPILATION_MODE is '$(COMPILATION_MODE)', expected debug, normal or release)
endif
BUILD_DIR ?= build
EXTERNAL_DIR ?= external
PREFIX ?= /usr/local

Q := $(if $(V),,@)

include $(MYMAKEFILE)/engine/platform.mk

TOOLCHAIN ?= $(if $(filter Darwin,$(HOST_OS)),clang,gcc)
ifeq ($(TOOLCHAIN),msvc)
    include $(MYMAKEFILE)/engine/toolchain-msvc.mk
else
    include $(MYMAKEFILE)/engine/toolchain-gnu.mk
endif

PKG_CONFIG ?= pkg-config

#? Build directory of this configuration: build/linux-gcc-normal,
#? build/emscripten-release...
_mm_os := $(call _mm_lc,$(TARGET_OS))
BUILD := $(BUILD_DIR)/$(if $(filter $(_mm_os),$(TOOLCHAIN)),,$(_mm_os)-)$(TOOLCHAIN)-$(COMPILATION_MODE)

###############################################################################
# Files declaring targets. Each target records the directory of the file
# declaring it; the targets of the main Makefile have the root of the project.
###############################################################################

define _mm_include_target_file
_mm_before := $$(TARGETS)
HERE := $(dir $(1))
include $(1)
$$(foreach t,$$(filter-out $$(_mm_before),$$(TARGETS)),$$(eval $$t.DIR := $$(HERE)))
endef

$(foreach f,$(TARGET_FILES),$(eval $(call _mm_include_target_file,$f)))
HERE :=

include $(MYMAKEFILE)/engine/targets.mk
include $(MYMAKEFILE)/engine/info.mk
include $(MYMAKEFILE)/engine/goals.mk
