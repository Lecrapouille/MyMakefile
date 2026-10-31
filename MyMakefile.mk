###############################################################################
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
###############################################################################
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
#   SUBMAKEFILES := app/app.mk tests/tests.mk
#
#   include .makefile/MyMakefile.mk
#
# Paths written in a file of SUBMAKEFILES are relative to the directory of
# that file. That directory is also in HERE while the file is read.

MYMAKEFILE := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
MYMAKEFILE_VERSION := 3.0.0

include $(MYMAKEFILE)/engine/functions.mk

# 4.2 for $(file <): the stamps are read with it.
MAKE_MAJOR := $(call version-field,1,$(MAKE_VERSION))
MAKE_MINOR := $(call version-field,2,$(MAKE_VERSION))
ifeq ($(or $(call ge,$(MAKE_MAJOR),5),$(and $(filter 4,$(MAKE_MAJOR)),$(call ge,$(MAKE_MINOR),2))),)
    $(error MyMakefile needs GNU Make 4.2 or newer, this is $(MAKE_VERSION). macOS: brew install make, then use gmake)
endif

include $(MYMAKEFILE)/engine/platform.mk
include $(MYMAKEFILE)/engine/display.mk

###############################################################################
# Project
###############################################################################

ifndef PROJECT_NAME
    $(call fail,PROJECT_NAME is mandatory for giving a name to your project)
endif
ifndef PROJECT_VERSION
    $(call fail,PROJECT_VERSION is mandatory for giving a version to your binaries and libraries: 1.0.0)
endif
ifneq ($(filter lib%,$(PROJECT_NAME)),)
    $(call fail,PROJECT_NAME shall not start by lib)
endif
CXX_STANDARD ?= c++17
C_STANDARD ?=

#? Lower case names for the files built and installed (libfoo, not libFoo).
FORCE_LOWER_CASE ?=
INSTALL_NAME := $(if $(FORCE_LOWER_CASE),$(call lower,$(PROJECT_NAME)),$(PROJECT_NAME))

###############################################################################
# Compilation mode
###############################################################################

COMPILATION_MODES := debug normal release release-with-debug size fast
COMPILATION_MODE ?= normal
# The unit test mode of MyMakefile 2.
ifeq ($(COMPILATION_MODE),test)
    override COMPILATION_MODE := debug
    COVERAGE := 1
endif
ifeq ($(filter $(COMPILATION_MODES),$(COMPILATION_MODE)),)
    $(call fail,COMPILATION_MODE is '$(COMPILATION_MODE)'$(COMMA) expected one of: $(COMPILATION_MODES))
endif
# 'make coverage' and 'make gprof' build with their instrumentation.
ifneq ($(filter coverage,$(MAKECMDGOALS)),)
    COVERAGE := 1
endif
ifneq ($(filter gprof,$(MAKECMDGOALS)),)
    GPROF := 1
endif

###############################################################################
# Directories
###############################################################################

BUILD_DIR ?= build
EXTERNAL_DIR ?= external
DOC_DIR ?= doc

#? Installation, as in MyMakefile 2. INSTALL_VERSIONED=1 keeps the versions
#? side by side, as MyMakefile 2 did: include/<project>/<version>,
#? share/<project>/<version>, bin/<name>-<version> and <name>-<version>.pc,
#? with links without the version.
INSTALL_VERSIONED ?=
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
INCLUDEDIR ?= $(PREFIX)/include$(if $(INSTALL_VERSIONED),/$(INSTALL_NAME)/$(PROJECT_VERSION))
PKGLIBDIR ?= $(LIBDIR)/pkgconfig
DATADIR ?= $(PREFIX)/share
PROJECT_DATADIR ?= $(DATADIR)/$(INSTALL_NAME)$(if $(INSTALL_VERSIONED),/$(PROJECT_VERSION))
DOCDIR ?= $(DATADIR)/doc/$(INSTALL_NAME)

Q := $(if $(V),,@)

###############################################################################
# Toolchain
###############################################################################

# emmake, emsdk and the ExaequOS image give em++ as CXX or set these variables.
TOOLCHAIN ?= $(if $(or $(EMSCRIPTEN),$(EXAEQUOS),$(filter em++%,$(notdir $(CXX)))),emscripten,$(if $(filter Darwin,$(HOST_OS)),clang,gcc))

ifeq ($(TOOLCHAIN),msvc)
    include $(MYMAKEFILE)/engine/toolchain-msvc.mk
else
    include $(MYMAKEFILE)/engine/toolchain-gnu.mk
endif

PKG_CONFIG ?= pkg-config

#? Build directory of this configuration: build/linux-gcc-normal,
#? build/emscripten-release, build/exaequos-normal, build/linux-gcc-debug-coverage...
OS_NAME := $(call lower,$(TARGET_OS))
#? Generated headers: GEN_DIR/<target>/project_info.hpp
GEN_DIR = $(BUILD)/gen
BUILD := $(BUILD_DIR)/$(if $(EXAEQUOS),exaequos,$(if $(filter $(OS_NAME),$(TOOLCHAIN)),,$(OS_NAME)-)$(TOOLCHAIN))-$(COMPILATION_MODE)$(if $(COVERAGE),-coverage)$(if $(SANITIZERS),-$(subst $(SPACE),-,$(SANITIZERS)))$(if $(filter 1 yes,$(GPROF)),-gprof)

###############################################################################
# Goals which neither compile nor need the third parties: with only them,
# MyMakefile does not fetch, write the stamps or call pkg-config.
###############################################################################

PASSIVE_GOALS := clean distclean veryclean clean-% help list-targets print-% \
    ci-info format check-format tarball uninstall uninstall-dry-run cache-clean
BUILDING := $(if $(MAKECMDGOALS),$(filter-out $(PASSIVE_GOALS),$(MAKECMDGOALS)),all)

# 'make rebuild': the build of this configuration is removed before make
# looks at what is up to date.
ifneq ($(filter rebuild,$(MAKECMDGOALS)),)
    REBUILD := $(shell $(call remove-dir,$(BUILD)))
endif

###############################################################################
# Files declaring targets. Each target records the directory of the file
# declaring it; the targets of the main Makefile have the root of the project.
###############################################################################

define INCLUDE_SUBMAKEFILE
TARGETS_BEFORE := $$(TARGETS)
HERE := $(dir $(1))
include $(1)
$$(foreach t,$$(filter-out $$(TARGETS_BEFORE),$$(TARGETS)),$$(eval $$t.DIR := $$(HERE)))
endef

$(foreach f,$(SUBMAKEFILES),$(eval $(call INCLUDE_SUBMAKEFILE,$f)))
HERE :=
TARGETS := $(call uniq,$(TARGETS))

include $(MYMAKEFILE)/engine/externals.mk
include $(MYMAKEFILE)/engine/targets.mk
include $(MYMAKEFILE)/engine/info.mk
include $(MYMAKEFILE)/engine/goals.mk
include $(MYMAKEFILE)/engine/install.mk
include $(MYMAKEFILE)/engine/tools.mk
