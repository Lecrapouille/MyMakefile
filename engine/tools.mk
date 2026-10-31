# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
#
# Developer tools: documentation, coverage, formatting, static analysis,
# archives of the sources and RPM packages. Each tool is a variable (DOXYGEN,
# GCOVR, CLANG_FORMAT, CPPCHECK, RPMBUILD) which can be replaced.

# The targets written by the project, not the third parties.
_mm_own := $(filter-out $(_mm_externals),$(TARGETS))

#? One line about the project: the first DESCRIPTION of a target by default.
PROJECT_DESCRIPTION ?= $(foreach t,$(firstword $(foreach t,$(TARGETS),$(if $($t.DESCRIPTION),$t))),$($t.DESCRIPTION))

###############################################################################
# License, found in the LICENSE file (read once, when a goal needs it).
###############################################################################

_mm_has = $(and $(findstring $1,$3),$(findstring $2,$3))
_mm_detect_license = $(strip \
    $(if $(call _mm_has,GNU LESSER GENERAL PUBLIC LICENSE,Version 3,$1),LGPL-3.0,\
    $(if $(call _mm_has,GNU LESSER GENERAL PUBLIC LICENSE,Version 2.1,$1),LGPL-2.1,\
    $(if $(call _mm_has,GNU GENERAL PUBLIC LICENSE,Version 3,$1),GPL-3.0,\
    $(if $(call _mm_has,GNU GENERAL PUBLIC LICENSE,Version 2,$1),GPL-2.0,\
    $(if $(call _mm_has,MIT License,Permission is hereby granted,$1),MIT,\
    $(if $(call _mm_has,Apache License,Version 2.0,$1),Apache-2.0,\
    $(if $(call _mm_has,Redistribution and use in source and binary forms,Neither the name,$1),BSD-3-Clause,\
    $(if $(findstring Redistribution and use in source and binary forms,$1),BSD-2-Clause,\
    UNKNOWN)))))))))

#? License of the project: GPL-3.0, MIT... found in the LICENSE file.
LICENSE ?= $(eval LICENSE := $(call _mm_detect_license,$(if $(wildcard LICENSE),$(file <LICENSE))))$(LICENSE)

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

_mm_doxy_templates := $(MYMAKEFILE)/assets/doxygen
_mm_doxy_conf := $(BUILD_DIR)/doxygen
_mm_doxy_footer = $(_mm_doxy_templates)/footer-$(if $(wildcard $(_mm_doxy_templates)/footer-$(LICENSE).html),$(LICENSE),UNKNOWN).html

# The placeholders of the templates, replaced without sed.
_mm_doxy_subst = $(subst %VERSION,$(PROJECT_VERSION),$(subst %PROJECT,$(PROJECT_NAME),\
    $(subst %TARGET,$(PROJECT_NAME),$(subst %DESCRIPTION,$(PROJECT_DESCRIPTION),\
    $(subst %LOGO,$(abspath $(PROJECT_LOGO)),$(subst %GENDOC,$(abspath $(DOXYGEN_DIR)),\
    $(subst %INPUT,$(abspath $(DOXYGEN_INPUTS)),$(subst %LICENSE,$(LICENSE),\
    $(subst doc/doxygen/,$(abspath $(_mm_doxy_conf))/,$1)))))))))

$(_mm_doxy_conf): ; $(Q)$(call _mm_mkdir,$@)

#? Generate the documentation of the code with Doxygen.
.PHONY: doc
doc: | $(_mm_doxy_conf)
	$(call _mm_say_to,Documenting,$(PROJECT_NAME),$(DOXYGEN_DIR)/html/index.html)
	$(foreach f,Doxyfile header.html doxygen.css,$(file >$(_mm_doxy_conf)/$f,$(call _mm_doxy_subst,$(file <$(_mm_doxy_templates)/$f))))
	$(file >$(_mm_doxy_conf)/footer-$(LICENSE).html,$(call _mm_doxy_subst,$(file <$(_mm_doxy_footer))))
	$(Q)$(call _mm_mkdir,$(DOXYGEN_DIR))
	$(Q)$(DOXYGEN) $(_mm_doxy_conf)/Doxyfile

###############################################################################
# Code coverage of the tests, with gcovr.
###############################################################################

GCOVR ?= gcovr
#? Where the coverage report is written.
COVERAGE_DIR ?= $(DOC_DIR)/code-coverage
#? Directories left out of the report: the third parties, the build and the
#? directories of the tests.
COVERAGE_EXCLUDE ?= $(EXTERNAL_DIR) $(BUILD_DIR) $(patsubst %/,%,$(sort $(foreach t,$(_mm_tests),$($t.DIR))))

#? Build with COVERAGE=1, run the tests and write the coverage report.
.PHONY: coverage
coverage: $(_mm_tests)
	$(Q)$(call _mm_rm,$(call _mm_rwildcard,$(BUILD)/obj,*.gcda))
	$(foreach t,$(_mm_tests),$(call _mm_run_test,$t))
	$(call _mm_cmd,$(call _mm_echo_simple,Coverage report,$(PROJECT_NAME), => $(COVERAGE_DIR)/index.html))
	$(Q)$(call _mm_mkdir,$(COVERAGE_DIR))
	$(Q)$(GCOVR) --root . $(addprefix --exclude ,$(addsuffix /,$(COVERAGE_EXCLUDE))) \
	    --html-details $(COVERAGE_DIR)/index.html --lcov $(COVERAGE_DIR)/lcov.info \
	    --print-summary $(BUILD)/obj

###############################################################################
# clang-format, on the sources and the headers of the project.
###############################################################################

CLANG_FORMAT ?= clang-format
_mm_format_exts := %.c %.cc %.cpp %.cxx %.c++ %.h %.hh %.hpp %.hxx %.ipp %.tpp %.inl
_mm_format_dirs := $(sort $(foreach t,$(_mm_own),$($t._PUB_INCS) $($t._PRIV_INCS)))
_mm_header_dirs := $(sort $(foreach t,$(_mm_own),$(patsubst %/,%,$(dir $($t._SRCS)))))

#? Files formatted: the sources of the targets of the project, the headers
#? beside them and in their include directories.
FORMAT_FILES ?= $(sort $(filter-out $(EXTERNAL_DIR)/% $(BUILD_DIR)/%,$(filter $(_mm_format_exts),\
    $(foreach t,$(_mm_own),$($t._SRCS)) \
    $(foreach d,$(_mm_format_dirs),$(call _mm_rwildcard,$d,*)) \
    $(foreach d,$(_mm_header_dirs),$(wildcard $d/*)))))

# The style of MyMakefile, for a project without its own.
.clang-format:
	$(call _mm_say_to,Copying,$(MYMAKEFILE)/assets/format/clang-format,$@)
	$(Q)$(call _mm_copy,$(MYMAKEFILE)/assets/format/clang-format,$@)

#? Format the code with clang-format and the .clang-format of the project.
.PHONY: format
format: .clang-format
	$(call _mm_say_simple,Formatting,$(PROJECT_NAME),$(_mm_space)($(words $(FORMAT_FILES)) files))
	$(Q)$(CLANG_FORMAT) -i --style=file $(FORMAT_FILES)

#? Fail when a file is not formatted (for a CI).
.PHONY: check-format
check-format: .clang-format
	$(call _mm_say_simple,Checking the format,$(PROJECT_NAME),$(_mm_space)($(words $(FORMAT_FILES)) files))
	$(Q)$(CLANG_FORMAT) --dry-run --Werror --style=file $(FORMAT_FILES)

###############################################################################
# Static analysis with cppcheck, target by target with their own flags.
###############################################################################

CPPCHECK ?= cppcheck
#? Add --error-exitcode=1 for a CI.
CPPCHECK_FLAGS ?= --enable=warning,style,performance,portability \
    --inline-suppr --suppress=missingIncludeSystem --quiet

# Only the include directories of the project: the system ones slow cppcheck.
_mm_lint_flags = $(filter-out -I/% -I$(EXTERNAL_DIR)/%,$(filter -I% -D%,$($1._CPPFLAGS))) \
    $(if $(filter %.c,$($1._SRCS)),,--language=c++ --std=$(patsubst -std=%,%,$(patsubst --std=%,%,$(CXX_STANDARD))))
_mm_lint_targets := $(foreach t,$(_mm_own),$(if $($t._SRCS),$t))

#? Run cppcheck on the targets of the project.
.PHONY: lint
lint:
	$(foreach t,$(_mm_lint_targets),$(call _mm_cmd,$(call _mm_echo_simple,Analysing,$t))$(call _mm_cmd,$(CPPCHECK) $(CPPCHECK_FLAGS) $(call _mm_lint_flags,$t) $($t._SRCS)))

###############################################################################
# Archive of the sources: the project with its third parties, without git,
# builds and generated documentation.
###############################################################################

TARBALL ?= $(BUILD_DIR)/dist/$(PROJECT_NAME)-$(PROJECT_VERSION)-src.tar.gz
#? Other files or directories left out of TARBALL, from the project root.
TARBALL_EXCLUDE ?=
_mm_here := $(notdir $(CURDIR))

#? Archive the sources in TARBALL.
.PHONY: tarball
tarball:
	$(call _mm_say_to,Archiving,$(PROJECT_NAME),$(TARBALL))
	$(Q)$(call _mm_mkdir,$(dir $(TARBALL)))
	$(Q)tar -czf $(TARBALL) --exclude=.git \
	    $(addprefix --exclude=$(_mm_here)/,$(BUILD_DIR) $(DOXYGEN_DIR) $(COVERAGE_DIR) compile_commands.json .cache $(TARBALL_EXCLUDE)) \
	    -C .. $(_mm_here)

###############################################################################
# RPM package, built from the sources of the project with 'make install'.
###############################################################################

RPMBUILD ?= rpmbuild
RPM_DIR ?= $(BUILD_DIR)/rpm
_mm_rpm_top := $(abspath $(RPM_DIR))
_mm_rpm_spec := $(RPM_DIR)/SPECS/$(PROJECT_NAME).spec
_mm_rpm_make = $(MAKE) -C $(CURDIR) BUILD_DIR=%{_builddir}/build COMPILATION_MODE=release PREFIX=/usr COLORS=0

# What 'make install' puts in /usr, for %files.
_mm_rpm_files = \
    $(foreach t,$(_mm_installed),\
        $(if $($t._EXE),/usr/bin/$(notdir $($t._EXE))) \
        $(if $($t._IS_LIB),/usr/lib/pkgconfig/$($t.NAME).pc) \
        $(if $($t._ARCHIVE),/usr/lib/$(notdir $($t._ARCHIVE))) \
        $(if $($t._SHARED),/usr/lib/$(LIB_PREFIX)$($t.NAME)$(SHARED_EXT)*) \
        $(if $($t._IS_LIB),$(foreach d,$($t._PUB_INCS),$(addprefix /usr/include/,$(notdir $(wildcard $d/*)))))) \
    $(if $(strip $(foreach t,$(_mm_installed),$($t._DATA))),/usr/share/$(PROJECT_NAME))

define _mm_rpm_spec_file
%global debug_package %{nil}
%global source_date_epoch_from_changelog 0

Name:           $(PROJECT_NAME)
Version:        $(subst -,_,$(PROJECT_VERSION))
Release:        1%{?dist}
Summary:        $(or $(PROJECT_DESCRIPTION),$(PROJECT_NAME))
License:        $(LICENSE)
$(if $(PROJECT_URL),URL:            $(PROJECT_URL))
BuildRequires:  make >= 4.2

%description
$(or $(PROJECT_DESCRIPTION),$(PROJECT_NAME))

%build
$(_mm_rpm_make) %{?_smp_mflags} all

%install
$(_mm_rpm_make) DESTDIR=%{buildroot} install

%files
$(subst $(_mm_space),$(_mm_newline),$(strip $(_mm_rpm_files)))
endef

$(RPM_DIR)/SPECS: ; $(Q)mkdir -p $@

#? Build an RPM package of the project in RPM_DIR.
.PHONY: rpm
rpm: | $(RPM_DIR)/SPECS
	$(call _mm_say_to,RPM package,$(PROJECT_NAME),$(RPM_DIR)/RPMS)
	$(file >$(_mm_rpm_spec),$(_mm_rpm_spec_file))
	$(Q)MAKEFLAGS= $(RPMBUILD) --quiet --define "_topdir $(_mm_rpm_top)" -bb $(_mm_rpm_spec) --nodeps
