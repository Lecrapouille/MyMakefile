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
    $(call glob,$($1.PUBLIC_HEADERS),$($1.DIR)))) $($1._INFO)

deepest-first = $(foreach n,$(call reverse,$(wordlist 1,40,$(NUMBERS))),$(foreach d,$1,$(if $(filter $n,$(words $(subst /, ,$d))),$d)))
header-dest = $(or $(firstword $(foreach d,$(call deepest-first,$(filter-out .,$2)),$(if $(filter $d/%,$1),$(patsubst $d/%,%,$1)))),$(if $(filter .,$2),$1,$(notdir $1)))
include-dirs = $($1._PUB_INCS) $($1._PRIV_INCS) $(if $($1._INFO),$(GEN_DIR))
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

# Versioned names of INSTALL_VERSIONED: OpenGlassBox-demo-0.2.0, linked from
# OpenGlassBox-demo. Not for the files of Emscripten.
VERSIONED_EXES := $(if $(and $(INSTALL_VERSIONED),$(filter-out Emscripten,$(TARGET_OS))),1)
versioned-exe = $($1.NAME)-$(PROJECT_VERSION)$(EXE_EXT)
versioned-pc = $($1.NAME)-$(PROJECT_VERSION).pc

#? Windows with MSYS2: the DLLs of MSYS2 an executable needs (libstdc++,
#? glfw3.dll...) are copied beside it, unless it is linked with -static.
#? COPY_RUNTIME_DLLS=0 to do without.
COPY_RUNTIME_DLLS ?= 1
runtime-dlls = $(if $(and $(filter Windows,$(TARGET_OS)),$(MSYSTEM_PREFIX),$(filter 1 yes,$(COPY_RUNTIME_DLLS))),$(sort $(filter $(MSYSTEM_PREFIX)/%.dll,$(subst \,/,$(shell ldd $1 2>$(DEVNULL))))))
stage-dlls = $(if $(call runtime-dlls,$($1._EXE)),$(call cmd,$(call copy-files,$(call runtime-dlls,$($1._EXE)),$2/)))

stage-exe = $(call stage-dlls,$1,$2)$(if $(VERSIONED_EXES),\
    $(call cmd,$(call copy-files,$($1._EXE),$2/$(call versioned-exe,$1)))$(call cmd,$(call link-file,$(call versioned-exe,$1),$2/$(notdir $($1._EXE)))),\
    $(call cmd,$(call copy-files,$(call exe-files,$1),$2/)))
stage-pc = $(if $(INSTALL_VERSIONED),\
    $(call cmd,$(call copy-files,$(call installed-pc,$1),$2/$(call versioned-pc,$1)))$(call cmd,$(call link-file,$(call versioned-pc,$1),$2/$($1.NAME).pc)),\
    $(call cmd,$(call copy-files,$(call installed-pc,$1),$2/)))

stage = \
    $(if $($1._EXE),$(call cmd,$(call make-dir,$(call stage-path,$(BINDIR),$2)))$(call stage-exe,$1,$(call stage-path,$(BINDIR),$2))) \
    $(if $($1._BUNDLE),$(call cmd,$(call copy-dir,$($1._BUNDLE),$(call stage-path,$(BINDIR),$2)/$(notdir $($1._BUNDLE))))) \
    $(if $($1._IS_LIB),$(call cmd,$(call make-dir,$(call stage-path,$(LIBDIR),$2))) \
        $(call cmd,$(call make-dir,$(call stage-path,$(PKGLIBDIR),$2)))$(call stage-pc,$1,$(call stage-path,$(PKGLIBDIR),$2))) \
    $(if $($1._ARCHIVE),$(call cmd,$(call copy-files,$($1._ARCHIVE),$(call stage-path,$(LIBDIR),$2)/))) \
    $(if $($1._IMPLIB),$(call cmd,$(call copy-files,$($1._IMPLIB),$(call stage-path,$(LIBDIR),$2)/))) \
    $(if $($1._SHARED),$(call cmd,$(call make-dir,$(call stage-path,$(shared-dir),$2)))$(call cmd,$(call copy-files,$(call shared-files,$1),$(call stage-path,$(shared-dir),$2)/))) \
    $(if $($1._IS_LIB),$(call stage-headers,$1,$(call stage-path,$(INCLUDEDIR),$2))) \
    $(foreach d,$($1._DATA),$(call cmd,$(call copy-dir,$d,$(call stage-path,$(PROJECT_DATADIR),$2))))

# A third party used by a library is neither installed nor merged in it.
warn-externals = $(foreach t,$(INSTALLED_LIBS),$(if $(call pc-externals,$t),$(call print-warning,$t uses the third parties '$(call pc-externals,$t)' which are not installed: add them to $t.MERGE)))

###############################################################################
# ExaequOS, as MyMakefile 2 did: each application in
# EXAEQUOS_DIR/<name>/exa/ with its .js, .wasm and an exa.html page.
###############################################################################

EXAEQUOS_DIR ?= media/localhost
EXAEQUOS_APPS := $(if $(EXAEQUOS),$(strip $(foreach t,$(INSTALLED_TARGETS),$(if $(filter executable,$($t.TYPE)),$t))))

define EXAEQUOS_HTML
<!doctype html>
<html lang="en-us">
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <title>$($1.NAME)</title>
  <style>
    html, body { margin: 0; padding: 0; border: none; width: 100%; height: 100%; }
  </style>
</head>
<body>
  <script async type="text/javascript" src="$($1.NAME).js"></script>
</body>
</html>
endef

exaequos-html = $(STAGE_DIR)/$($1.NAME)-exa.html
$(foreach t,$(EXAEQUOS_APPS),$(eval $(call exaequos-html,$t): $$($t._LD_STAMP) | $$(STAGE_DIR) ; $$(file >$$@,$$(call EXAEQUOS_HTML,$t))))
stage-exaequos = $(call cmd,$(call make-dir,$(EXAEQUOS_DIR)/$($1.NAME)/exa))$(call cmd,$(call copy-files,$(wildcard $(basename $($1._EXE)).js $(basename $($1._EXE)).wasm $(basename $($1._EXE)).data),$(EXAEQUOS_DIR)/$($1.NAME)/exa/))$(call cmd,$(call copy-files,$(call exaequos-html,$1),$(EXAEQUOS_DIR)/$($1.NAME)/exa/exa.html))

#? Install the project in $(DESTDIR)$(PREFIX) (ExaequOS: in EXAEQUOS_DIR).
.PHONY: install
install:: all $(INSTALLED_PCS) $(foreach t,$(INSTALLED_LIBS),$($t._INFO)) $(foreach t,$(EXAEQUOS_APPS),$(call exaequos-html,$t))
	$(call print-to,Installing,$(PROJECT_NAME),$(if $(EXAEQUOS),$(EXAEQUOS_DIR),$(DESTDIR)$(PREFIX)))
	$(warn-externals)
	$(if $(EXAEQUOS),$(foreach t,$(EXAEQUOS_APPS),$(call stage-exaequos,$t)),$(foreach t,$(INSTALLED_TARGETS),$(call stage,$t,$(DESTDIR)$(PREFIX))))
	$(if $(and $(DIST_FILES),$(if $(EXAEQUOS),,1)),$(call cmd,$(call make-dir,$(DESTDIR)$(DOCDIR)))$(call cmd,$(call copy-files,$(DIST_FILES),$(DESTDIR)$(DOCDIR)/)))

# Files and directories 'make install' writes.
installed-files = $(foreach t,$(INSTALLED_TARGETS),\
    $(if $($t._EXE),$(BINDIR)/$(notdir $(call exe-files,$t)) $(if $(VERSIONED_EXES),$(BINDIR)/$(call versioned-exe,$t))) \
    $(if $($t._ARCHIVE),$(LIBDIR)/$(notdir $($t._ARCHIVE))) \
    $(if $($t._IMPLIB),$(LIBDIR)/$(notdir $($t._IMPLIB))) \
    $(if $($t._SHARED),$(shared-dir)/$(notdir $(call shared-files,$t))) \
    $(if $($t._IS_LIB),$(PKGLIBDIR)/$($t.NAME).pc $(if $(INSTALL_VERSIONED),$(PKGLIBDIR)/$(call versioned-pc,$t)) $(addprefix $(INCLUDEDIR)/,$(call header-dests,$t))))
installed-dirs = $(if $(strip $(foreach t,$(INSTALLED_TARGETS),$($t._DATA))),$(PROJECT_DATADIR)) $(if $(DIST_FILES),$(DOCDIR)) $(foreach t,$(INSTALLED_TARGETS),$(if $($t._BUNDLE),$(BINDIR)/$(notdir $($t._BUNDLE))))

# 'make uninstall' removes files: a wrong variable must not remove the files
# of the user. It removes only what exists among what 'make install' writes,
# checks each path, prints the list and asks before (YES=1 to not ask,
# DRY_RUN=1 or 'make uninstall-dry-run' to only print the list).
INSTALL_ROOTS = $(sort $(foreach d,$(BINDIR) $(LIBDIR) $(INCLUDEDIR) $(PKGLIBDIR) $(DATADIR) $(DOCDIR) $(PROJECT_DATADIR),$(DESTDIR)$d))
UNINSTALL_FILES = $(sort $(wildcard $(addprefix $(DESTDIR),$(installed-files))))
UNINSTALL_DIRS = $(sort $(patsubst %/,%,$(wildcard $(addsuffix /,$(addprefix $(DESTDIR),$(installed-dirs))))))
# Directories of the headers, removed when they are empty, deepest first.
UNINSTALL_EMPTY_DIRS = $(call deepest-first,$(filter-out $(INSTALL_ROOTS),$(sort $(patsubst %/,%,$(dir $(filter $(DESTDIR)$(INCLUDEDIR)/%,$(UNINSTALL_FILES)))))))

# Is $1 strictly below one of the installation directories?
below-roots = $(strip $(foreach r,$(INSTALL_ROOTS),$(filter $r/%,$1)))
unsafe-paths = $(strip $(foreach p,$1,$(if $(call below-roots,$p),,$p)))
# A directory removed with all its content must hold the name of the project.
unsafe-dirs = $(strip $(foreach d,$1,$(if $(or $(findstring $(INSTALL_NAME),$(subst $(PREFIX),,$d)),$(filter %.app,$d)),,$d)))

check-uninstall = \
    $(if $(call is-absolute,$(PREFIX)),,$(call fail,uninstall: PREFIX '$(PREFIX)' is not an absolute path))\
    $(if $(filter / $(HOME) $(HOME)/,$(PREFIX) $(abspath $(DESTDIR)$(PREFIX))),$(call fail,uninstall: refused for PREFIX '$(DESTDIR)$(PREFIX)'))\
    $(if $(call unsafe-paths,$(UNINSTALL_FILES) $(UNINSTALL_DIRS)),$(call fail,uninstall: refused$(COMMA) outside of the installation directories: $(call unsafe-paths,$(UNINSTALL_FILES) $(UNINSTALL_DIRS))))\
    $(if $(call unsafe-dirs,$(UNINSTALL_DIRS)),$(call fail,uninstall: refused$(COMMA) directories not named after $(INSTALL_NAME): $(call unsafe-dirs,$(UNINSTALL_DIRS))))

ifeq ($(HOST_SHELL),cmd)
    ask-confirmation = choice /c ny /m "$1" & if not errorlevel 2 exit 1
    remove-empty-dir = rd "$(call win-path,$1)" 2>nul & rem
else
    ask-confirmation = printf '%s [y/N] ' '$1' && read answer && case "$$answer" in y|Y|yes) ;; *) echo Cancelled; exit 1;; esac
    remove-empty-dir = rmdir $1 2>/dev/null || true
endif

print-uninstall = $(info $(foreach f,$(UNINSTALL_FILES),$(NEWLINE)  $f)$(foreach d,$(UNINSTALL_DIRS),$(NEWLINE)  $d/ (and its content)))

#? Print what 'make uninstall' would remove.
.PHONY: uninstall-dry-run
uninstall-dry-run:
	$(check-uninstall)
	$(call print-simple,Would remove,$(PROJECT_NAME),$(SPACE)($(words $(UNINSTALL_FILES)) files$(COMMA) $(words $(UNINSTALL_DIRS)) directories))
	$(print-uninstall)
	@$(NOOP)

#? Remove what 'make install' installed, after showing the list and asking.
.PHONY: uninstall
ifneq ($(filter 1 yes,$(DRY_RUN)),)
uninstall:: uninstall-dry-run
else
uninstall::
	$(check-uninstall)
	$(if $(UNINSTALL_FILES)$(UNINSTALL_DIRS),,$(call print-ok,Nothing of $(PROJECT_NAME) is installed in $(DESTDIR)$(PREFIX)))
	$(if $(UNINSTALL_FILES)$(UNINSTALL_DIRS),$(call print-simple,Uninstalling,$(PROJECT_NAME),$(SPACE)($(words $(UNINSTALL_FILES)) files$(COMMA) $(words $(UNINSTALL_DIRS)) directories)))
	$(if $(UNINSTALL_FILES)$(UNINSTALL_DIRS),$(print-uninstall))
	$(if $(and $(UNINSTALL_FILES)$(UNINSTALL_DIRS),$(if $(filter 1 yes,$(YES)),,1)),@$(call ask-confirmation,Remove these files?))
	$(if $(UNINSTALL_FILES),$(Q)$(call remove-files,$(UNINSTALL_FILES)))
	$(foreach d,$(UNINSTALL_DIRS),$(call cmd,$(call remove-dir,$d)))
	$(foreach d,$(UNINSTALL_EMPTY_DIRS),$(call cmd,$(call remove-empty-dir,$d)))
	@$(NOOP)
endif

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
dist: all $(INSTALLED_PCS) $(STAGE_DIR)/VERSION $(foreach t,$(INSTALLED_LIBS),$($t._INFO))
	$(call print-to,Packaging,$(PROJECT_NAME),$(DIST_ARCHIVE))
	$(warn-externals)
	$(Q)$(call remove-dir,$(DIST_DIR))
	$(Q)$(call make-dir,$(DIST_DIR))
	$(foreach t,$(INSTALLED_TARGETS),$(call stage,$t,$(DIST_DIR)))
	$(Q)$(call copy-files,$(DIST_FILES) $(STAGE_DIR)/VERSION,$(DIST_DIR)/)
	$(Q)tar -czf $(DIST_ARCHIVE) -C $(dir $(DIST_DIR)) $(notdir $(DIST_DIR))
