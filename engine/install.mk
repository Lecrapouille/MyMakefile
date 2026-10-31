###############################################################################
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
###############################################################################
#
# What the project delivers, for 'make install', 'make uninstall' and
# 'make dist': executables and bundles, libraries with their headers and a
# pkg-config file, data, and the files of DIST_FILES. Works with sh and
# cmd.exe. The directories (BINDIR, LIBDIR, INCLUDEDIR...) are set in
# MyMakefile.mk.

INSTALLED_TARGETS := $(strip $(foreach t,$(PRODUCT_TARGETS),$(if $(filter 0 no,$($t.INSTALL)),,$t)))
INSTALLED_LIBS := $(strip $(foreach t,$(INSTALLED_TARGETS),$(if $($t._IS_LIB),$t)))

###############################################################################
# Headers of a library: the headers of its PUBLIC_INCLUDES (A), and its
# PUBLIC_HEADERS (B: files or patterns, may be anywhere), less its
# PRIVATE_HEADERS. Each one is installed at the path the code includes it
# with: relative to the deepest include directory of the library holding it.
#
#   lib.PUBLIC_INCLUDES := include           include/foo/a.hpp -> foo/a.hpp
#   lib.INCLUDES := src                      src/foo/b.hpp     -> foo/b.hpp
#   lib.PUBLIC_HEADERS := src/foo/*.hpp
#   lib.PRIVATE_HEADERS := src/foo/*-private.hpp
###############################################################################

header-files = $(filter-out $(call glob,$($1.PRIVATE_HEADERS),$($1.DIR)),\
    $(filter $(HEADER_EXTS),$(foreach d,$($1._PUB_INCS),$(call rwildcard,$d,*)) \
    $(call glob,$($1.PUBLIC_HEADERS),$($1.DIR))))

deepest-first = $(foreach n,9 8 7 6 5 4 3 2 1,$(foreach d,$1,$(if $(filter $n,$(words $(subst /, ,$d))),$d)))
header-dest = $(or $(firstword $(foreach d,$(call deepest-first,$(filter-out .,$2)),$(if $(filter $d/%,$1),$(patsubst $d/%,%,$1)))),$(if $(filter .,$2),$1,$(notdir $1)))
include-dirs = $($1._PUB_INCS) $($1._PRIV_INCS)
header-dests = $(foreach h,$(call header-files,$1),$(call header-dest,$h,$(call include-dirs,$1)))

# Copy the headers of $1 into the directory $2, one copy per directory.
stage-headers = $(foreach dd,$(sort $(dir $(call header-dests,$1))),\
    $(call cmd,$(call make-dir,$2/$(dd)))$(call cmd,$(call copy-files,$(foreach h,$(call header-files,$1),$(if $(filter $(dd),$(dir $(call header-dest,$h,$(call include-dirs,$1)))),$h)),$2/$(dd))))

###############################################################################
# pkg-config files. The one of the build tree points to the sources and to the
# build; the installed one finds its prefix from its own place, so that it
# also works unpacked from an archive of 'make dist'.
###############################################################################

# Libraries of the project needed by $1, which have their own .pc file.
pc-requires = $(strip $($1.PKG_CONFIG) $(foreach d,$(filter $(INSTALLED_LIBS),$($1._DEPS)),$($d.NAME)))
# Third parties needed by $1: their headers and libraries are not installed.
pc-externals = $(filter-out $(foreach d,$($1._DEPS),$($d._MERGE_TARGETS)) $($1._MERGE_TARGETS),$(filter $(EXTERNAL_TARGETS),$($1._DEPS)))
pc-libs-private = $(strip $($1.LIBS) $(foreach d,$($1._DEPS),$($d.LIBS)))

define PKG_CONFIG_BUILD
libdir=$(abspath $($1._LIBDIR))

Name: $($1.NAME)
Description: $(or $($1.DESCRIPTION),$(PROJECT_NAME))
Version: $(PROJECT_VERSION)
Requires.private: $(call pc-requires,$1)
Libs: -L$${libdir} -l$($1.NAME)
Libs.private: $(abspath $(foreach d,$(call pc-externals,$1),$($d._LINKABLE))) $(call pc-libs-private,$1)
Cflags: $(addprefix -I,$(abspath $($1._PUB_INCS) $(foreach d,$(call pc-externals,$1),$($d._PUB_INCS)))) $(addprefix -D,$($1.PUBLIC_DEFINES))
endef

define PKG_CONFIG_INSTALLED
prefix=$${pcfiledir}/$(call up-path,$(patsubst $(PREFIX)/%,%,$(PKGLIBDIR)))
libdir=$${prefix}/$(patsubst $(PREFIX)/%,%,$(LIBDIR))
includedir=$${prefix}/$(patsubst $(PREFIX)/%,%,$(INCLUDEDIR))

Name: $($1.NAME)
Description: $(or $($1.DESCRIPTION),$(PROJECT_NAME))
Version: $(PROJECT_VERSION)
Requires.private: $(call pc-requires,$1)
Libs: -L$${libdir} -l$($1.NAME)
Libs.private: $(call pc-libs-private,$1)
Cflags: -I$${includedir} $(addprefix -D,$($1.PUBLIC_DEFINES))
endef

STAGE_DIR := $(BUILD)/stage
installed-pc = $(STAGE_DIR)/$($1.NAME).pc
INSTALLED_PCS := $(strip $(foreach t,$(INSTALLED_LIBS),$(call installed-pc,$t)))

define INSTALLED_PC_RULE
$$(call installed-pc,$(1)): $$($(1)._LD_STAMP) | $$(STAGE_DIR)
	$$(file >$$@,$$(call PKG_CONFIG_INSTALLED,$(1)))
endef
$(foreach t,$(INSTALLED_LIBS),$(eval $(call INSTALLED_PC_RULE,$t)))
$(STAGE_DIR): ; $(Q)$(call make-dir,$@)

###############################################################################
# Copy of a target into a tree laid out as PREFIX: $(call stage,t,root)
###############################################################################

# Where the directory $1 of PREFIX goes in the root $2.
stage-path = $(patsubst $(PREFIX)%,$2%,$1)

# Files beside an executable: .js, .wasm and .data of Emscripten.
exe-files = $(if $(filter Emscripten,$(TARGET_OS)),$(basename $($1._EXE)).*,$($1._EXE))
shared-files = $(if $(filter Windows,$(TARGET_OS)),$($1._SHARED),$(dir $($1._SHARED))$(LIB_PREFIX)$($1.NAME)$(SHARED_EXT)*)
shared-dir = $(if $(filter Windows,$(TARGET_OS)),$(BINDIR),$(LIBDIR))

stage = \
    $(if $($1._EXE),$(call cmd,$(call make-dir,$(call stage-path,$(BINDIR),$2)))$(call cmd,$(call copy-files,$(call exe-files,$1),$(call stage-path,$(BINDIR),$2)/))) \
    $(if $($1._BUNDLE),$(call cmd,$(call copy-dir,$($1._BUNDLE),$(call stage-path,$(BINDIR),$2)/$(notdir $($1._BUNDLE))))) \
    $(if $($1._IS_LIB),$(call cmd,$(call make-dir,$(call stage-path,$(LIBDIR),$2))) \
        $(call cmd,$(call make-dir,$(call stage-path,$(PKGLIBDIR),$2)))$(call cmd,$(call copy-files,$(call installed-pc,$1),$(call stage-path,$(PKGLIBDIR),$2)/))) \
    $(if $($1._ARCHIVE),$(call cmd,$(call copy-files,$($1._ARCHIVE),$(call stage-path,$(LIBDIR),$2)/))) \
    $(if $($1._IMPLIB),$(call cmd,$(call copy-files,$($1._IMPLIB),$(call stage-path,$(LIBDIR),$2)/))) \
    $(if $($1._SHARED),$(call cmd,$(call make-dir,$(call stage-path,$(shared-dir),$2)))$(call cmd,$(call copy-files,$(call shared-files,$1),$(call stage-path,$(shared-dir),$2)/))) \
    $(if $($1._IS_LIB),$(call stage-headers,$1,$(call stage-path,$(INCLUDEDIR),$2))) \
    $(foreach d,$($1._DATA),$(call cmd,$(call copy-dir,$d,$(call stage-path,$(PROJECT_DATADIR),$2))))

# A third party used by a library is neither installed nor merged in it.
warn-externals = $(foreach t,$(INSTALLED_LIBS),$(if $(call pc-externals,$t),$(call print-warning,$t uses the third parties '$(call pc-externals,$t)' which are not installed: add them to $t.MERGE)))

#? Install the project in $(DESTDIR)$(PREFIX).
.PHONY: install
install:: all $(INSTALLED_PCS)
	$(call print-to,Installing,$(PROJECT_NAME),$(DESTDIR)$(PREFIX))
	$(warn-externals)
	$(foreach t,$(INSTALLED_TARGETS),$(call stage,$t,$(DESTDIR)$(PREFIX)))
	$(if $(DIST_FILES),$(call cmd,$(call make-dir,$(DESTDIR)$(DOCDIR)))$(call cmd,$(call copy-files,$(DIST_FILES),$(DESTDIR)$(DOCDIR)/)))

# Files and directories 'make install' writes.
installed-files = $(foreach t,$(INSTALLED_TARGETS),\
    $(if $($t._EXE),$(BINDIR)/$(notdir $(call exe-files,$t))) \
    $(if $($t._ARCHIVE),$(LIBDIR)/$(notdir $($t._ARCHIVE))) \
    $(if $($t._IMPLIB),$(LIBDIR)/$(notdir $($t._IMPLIB))) \
    $(if $($t._SHARED),$(shared-dir)/$(notdir $(call shared-files,$t))) \
    $(if $($t._IS_LIB),$(PKGLIBDIR)/$($t.NAME).pc $(addprefix $(INCLUDEDIR)/,$(call header-dests,$t))))
installed-dirs = $(if $(strip $(foreach t,$(INSTALLED_TARGETS),$($t._DATA))),$(PROJECT_DATADIR)) $(if $(DIST_FILES),$(DOCDIR)) $(foreach t,$(INSTALLED_TARGETS),$(if $($t._BUNDLE),$(BINDIR)/$(notdir $($t._BUNDLE))))

#? Remove what 'make install' installed.
.PHONY: uninstall
uninstall::
	$(call print-simple,Uninstalling,$(PROJECT_NAME),$(SPACE)$(DESTDIR)$(PREFIX))
	$(Q)$(call remove-files,$(addprefix $(DESTDIR),$(strip $(installed-files))))
	$(foreach d,$(installed-dirs),$(call cmd,$(call remove-dir,$(DESTDIR)$d)))

###############################################################################
# Archive of what the project delivers, for the artifacts of a CI.
###############################################################################

#? Name and place of the archive made by 'make dist'.
DIST_NAME ?= $(INSTALL_NAME)-$(PROJECT_VERSION)-$(OS_NAME)-$(TARGET_ARCH)
DIST_DIR ?= $(BUILD_DIR)/dist/$(DIST_NAME)
DIST_ARCHIVE ?= $(DIST_DIR).tar.gz
#? Files copied at the root of the archive, and in DOCDIR by 'make install'.
DIST_FILES ?= $(wildcard LICENSE* LICENCE* LICENSING* COPYING* README* AUTHORS ChangeLog CHANGELOG*)

$(STAGE_DIR)/VERSION: | $(STAGE_DIR)
	$(file >$@,$(PROJECT_VERSION))

#? Gather in DIST_DIR and DIST_ARCHIVE what 'make install' installs (in the
#? same tree, without PREFIX), DIST_FILES and VERSION.
.PHONY: dist
dist: all $(INSTALLED_PCS) $(STAGE_DIR)/VERSION
	$(call print-to,Packaging,$(PROJECT_NAME),$(DIST_ARCHIVE))
	$(warn-externals)
	$(Q)$(call remove-dir,$(DIST_DIR))
	$(Q)$(call make-dir,$(DIST_DIR))
	$(foreach t,$(INSTALLED_TARGETS),$(call stage,$t,$(DIST_DIR)))
	$(Q)$(call copy-files,$(DIST_FILES) $(STAGE_DIR)/VERSION,$(DIST_DIR)/)
	$(Q)tar -czf $(DIST_ARCHIVE) -C $(dir $(DIST_DIR)) $(notdir $(DIST_DIR))
