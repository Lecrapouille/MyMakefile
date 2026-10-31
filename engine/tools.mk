###############################################################################
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
###############################################################################
#
# Developer tools: documentation, coverage, formatting, static analysis,
# archives of the sources and RPM packages. Each tool is a variable (DOXYGEN,
# GCOVR, CLANG_FORMAT, CPPCHECK, RPMBUILD) which can be replaced.

#? One line about the project: the first DESCRIPTION of a target by default.
PROJECT_DESCRIPTION ?= $(foreach t,$(firstword $(foreach t,$(TARGETS),$(if $($t.DESCRIPTION),$t))),$($t.DESCRIPTION))

###############################################################################
# License, found in the LICENSE file (read once, when a goal needs it).
###############################################################################

has-both = $(and $(findstring $1,$3),$(findstring $2,$3))
detect-license = $(strip \
    $(if $(call has-both,GNU LESSER GENERAL PUBLIC LICENSE,Version 3,$1),LGPL-3.0,\
    $(if $(call has-both,GNU LESSER GENERAL PUBLIC LICENSE,Version 2.1,$1),LGPL-2.1,\
    $(if $(call has-both,GNU GENERAL PUBLIC LICENSE,Version 3,$1),GPL-3.0,\
    $(if $(call has-both,GNU GENERAL PUBLIC LICENSE,Version 2,$1),GPL-2.0,\
    $(if $(call has-both,MIT License,Permission is hereby granted,$1),MIT,\
    $(if $(call has-both,Apache License,Version 2.0,$1),Apache-2.0,\
    $(if $(call has-both,Redistribution and use in source and binary forms,Neither the name,$1),BSD-3-Clause,\
    $(if $(findstring Redistribution and use in source and binary forms,$1),BSD-2-Clause,\
    UNKNOWN)))))))))

#? License of the project: GPL-3.0, MIT... found in the LICENSE file.
LICENSE ?= $(eval LICENSE := $(call detect-license,$(if $(wildcard LICENSE),$(file <LICENSE))))$(LICENSE)

###############################################################################
# Doxygen, from the templates of MyMakefile.
###############################################################################

DOXYGEN ?= doxygen
#? Where the documentation is written.
DOXYGEN_DIR ?= $(DOC_DIR)/doxygen
#? Files and directories documented.
DOXYGEN_INPUTS ?= $(wildcard README.md include src)
#? Logo at the top of the documentation.
PROJECT_LOGO ?= $(MYMAKEFILE)/assets/icons/logo.png

DOXYGEN_TEMPLATES := $(MYMAKEFILE)/assets/doxygen
DOXYGEN_CONF := $(BUILD_DIR)/doxygen
doxygen-footer = $(DOXYGEN_TEMPLATES)/footer-$(if $(wildcard $(DOXYGEN_TEMPLATES)/footer-$(LICENSE).html),$(LICENSE),UNKNOWN).html

# The placeholders of the templates, replaced without sed.
doxygen-subst = $(subst %VERSION,$(PROJECT_VERSION),$(subst %PROJECT,$(PROJECT_NAME),\
    $(subst %TARGET,$(PROJECT_NAME),$(subst %DESCRIPTION,$(PROJECT_DESCRIPTION),\
    $(subst %LOGO,$(abspath $(PROJECT_LOGO)),$(subst %GENDOC,$(abspath $(DOXYGEN_DIR)),\
    $(subst %INPUT,$(abspath $(DOXYGEN_INPUTS)),$(subst %LICENSE,$(LICENSE),\
    $(subst doc/doxygen/,$(abspath $(DOXYGEN_CONF))/,$1)))))))))

$(DOXYGEN_CONF): ; $(Q)$(call make-dir,$@)

#? Generate the documentation of the code with Doxygen.
.PHONY: doc
doc: | $(DOXYGEN_CONF)
	$(call print-to,Documenting,$(PROJECT_NAME),$(DOXYGEN_DIR)/html/index.html)
	$(foreach f,Doxyfile header.html doxygen.css,$(file >$(DOXYGEN_CONF)/$f,$(call doxygen-subst,$(file <$(DOXYGEN_TEMPLATES)/$f))))
	$(file >$(DOXYGEN_CONF)/footer-$(LICENSE).html,$(call doxygen-subst,$(file <$(doxygen-footer))))
	$(Q)$(call make-dir,$(DOXYGEN_DIR))
	$(Q)$(DOXYGEN) $(DOXYGEN_CONF)/Doxyfile

###############################################################################
# Code coverage of the tests, with gcovr.
###############################################################################

GCOVR ?= gcovr
#? Where the coverage report is written.
COVERAGE_DIR ?= $(DOC_DIR)/code-coverage
#? Directories left out of the report: the third parties, the build and the
#? directories of the tests.
COVERAGE_EXCLUDE ?= $(EXTERNAL_DIR) $(BUILD_DIR) $(patsubst %/,%,$(sort $(foreach t,$(TEST_TARGETS),$($t.DIR))))

#? Build with COVERAGE=1, run the tests and write the coverage report.
.PHONY: coverage
coverage: $(TEST_TARGETS)
	$(Q)$(call remove-files,$(call rwildcard,$(BUILD)/obj,*.gcda))
	$(foreach t,$(TEST_TARGETS),$(call run-test,$t))
	$(call cmd,$(call echo-simple,Coverage report,$(PROJECT_NAME), => $(COVERAGE_DIR)/index.html))
	$(Q)$(call make-dir,$(COVERAGE_DIR))
	$(Q)$(GCOVR) --root . $(addprefix --exclude ,$(addsuffix /,$(COVERAGE_EXCLUDE))) \
	    --html-details $(COVERAGE_DIR)/index.html --lcov $(COVERAGE_DIR)/lcov.info \
	    --print-summary $(BUILD)/obj

###############################################################################
# clang-format, on the sources and the headers of the project.
###############################################################################

CLANG_FORMAT ?= clang-format
FORMAT_EXTS := $(SOURCE_EXTS) $(HEADER_EXTS)
FORMAT_INCLUDE_DIRS := $(sort $(foreach t,$(OWN_TARGETS),$($t._PUB_INCS) $($t._PRIV_INCS)))
FORMAT_SOURCE_DIRS := $(sort $(foreach t,$(OWN_TARGETS),$(patsubst %/,%,$(dir $($t._SRCS)))))

#? Files formatted: the sources of the targets of the project, the headers
#? beside them and in their include directories.
FORMAT_FILES ?= $(sort $(filter-out $(EXTERNAL_DIR)/% $(BUILD_DIR)/%,$(filter $(FORMAT_EXTS),\
    $(foreach t,$(OWN_TARGETS),$($t._SRCS)) \
    $(foreach d,$(FORMAT_INCLUDE_DIRS),$(call rwildcard,$d,*)) \
    $(foreach d,$(FORMAT_SOURCE_DIRS),$(wildcard $d/*)))))

# The style of MyMakefile, for a project without its own.
.clang-format:
	$(call print-to,Copying,$(MYMAKEFILE)/assets/format/clang-format,$@)
	$(Q)$(call copy-files,$(MYMAKEFILE)/assets/format/clang-format,$@)

#? Format the code with clang-format and the .clang-format of the project.
.PHONY: format
format: .clang-format
	$(call print-simple,Formatting,$(PROJECT_NAME),$(SPACE)($(words $(FORMAT_FILES)) files))
	$(Q)$(CLANG_FORMAT) -i --style=file $(FORMAT_FILES)

#? Fail when a file is not formatted (for a CI).
.PHONY: check-format
check-format: .clang-format
	$(call print-simple,Checking the format,$(PROJECT_NAME),$(SPACE)($(words $(FORMAT_FILES)) files))
	$(Q)$(CLANG_FORMAT) --dry-run --Werror --style=file $(FORMAT_FILES)

###############################################################################
# Static analysis with cppcheck, target by target with their own flags.
###############################################################################

CPPCHECK ?= cppcheck
#? Add --error-exitcode=1 for a CI.
CPPCHECK_FLAGS ?= --enable=warning,style,performance,portability \
    --inline-suppr --suppress=missingIncludeSystem --quiet

# Only the include directories of the project: the system ones slow cppcheck.
lint-flags = $(filter-out -I/% -I$(EXTERNAL_DIR)/%,$(filter -I% -D%,$($1._CPPFLAGS))) \
    $(if $(filter %.c,$($1._SRCS)),,--language=c++ --std=c++$(CXX_STD_NUMBER))
LINT_TARGETS := $(strip $(foreach t,$(OWN_TARGETS),$(if $($t._SRCS),$t)))

#? Run cppcheck on the targets of the project.
.PHONY: lint
lint:
	$(foreach t,$(LINT_TARGETS),$(call cmd,$(call echo-simple,Analysing,$t))$(call cmd,$(CPPCHECK) $(CPPCHECK_FLAGS) $(call lint-flags,$t) $($t._SRCS)))

###############################################################################
# Archive of the sources: the project with its third parties of EXTERNAL_DIR,
# without git, builds and generated documentation. As in MyMakefile 2, an
# existing archive is kept: the new one gets the next free name.
###############################################################################

TARBALL_BASE ?= $(BUILD_DIR)/dist/$(INSTALL_NAME)-$(PROJECT_VERSION)-src
#? Other files or directories left out of the archive, from the project root.
TARBALL_EXCLUDE ?=
TARBALL ?= $(if $(wildcard $(TARBALL_BASE).tar.gz),$(TARBALL_BASE)-$(words $(wildcard $(TARBALL_BASE)*.tar.gz) x).tar.gz,$(TARBALL_BASE).tar.gz)
PROJECT_DIRNAME := $(notdir $(CURDIR))

#? Archive the sources in TARBALL.
.PHONY: tarball
tarball:
	$(call print-to,Archiving,$(PROJECT_NAME),$(TARBALL))
	$(Q)$(call make-dir,$(dir $(TARBALL)))
	$(Q)tar -czf $(TARBALL) --exclude=.git \
	    $(addprefix --exclude=$(PROJECT_DIRNAME)/,$(BUILD_DIR) $(DOXYGEN_DIR) $(COVERAGE_DIR) compile_commands.json .cache $(TARBALL_EXCLUDE)) \
	    -C .. $(PROJECT_DIRNAME)

###############################################################################
# RPM package, built from the sources of the project with 'make install'.
###############################################################################

RPMBUILD ?= rpmbuild
RPM_DIR ?= $(BUILD_DIR)/rpm
RPM_TOP := $(abspath $(RPM_DIR))
RPM_SPEC_FILE := $(RPM_DIR)/SPECS/$(INSTALL_NAME).spec
rpm-make = $(MAKE) -C $(CURDIR) BUILD_DIR=%{_builddir}/build COMPILATION_MODE=release PREFIX=/usr COLORS=0

define RPM_SPEC
%global debug_package %{nil}
%global source_date_epoch_from_changelog 0

Name:           $(INSTALL_NAME)
Version:        $(subst -,_,$(PROJECT_VERSION))
Release:        1%{?dist}
Summary:        $(or $(PROJECT_DESCRIPTION),$(PROJECT_NAME))
License:        $(LICENSE)
$(if $(PROJECT_URL),URL:            $(PROJECT_URL))
BuildRequires:  make >= 4.2

%description
$(or $(PROJECT_DESCRIPTION),$(PROJECT_NAME))

%build
$(rpm-make) %{?_smp_mflags} all

%install
$(rpm-make) DESTDIR=%{buildroot} install

%files
$(subst $(SPACE),$(NEWLINE),$(strip $(patsubst $(PREFIX)/%,/usr/%,$(installed-files) $(installed-dirs))))
endef

$(RPM_DIR)/SPECS: ; $(Q)mkdir -p $@

#? Build an RPM package of the project in RPM_DIR.
.PHONY: rpm
rpm: | $(RPM_DIR)/SPECS
	$(call print-to,RPM package,$(PROJECT_NAME),$(RPM_DIR)/RPMS)
	$(file >$(RPM_SPEC_FILE),$(RPM_SPEC))
	$(Q)MAKEFLAGS= $(RPMBUILD) --quiet --define "_topdir $(RPM_TOP)" -bb $(RPM_SPEC_FILE) --nodeps
