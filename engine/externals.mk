###############################################################################
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
###############################################################################
#
# Third parties: the targets having a GIT url (or a local PATH).
#
# - Each VERSION (branch, tag; a COMMIT can also be given) is resolved once
#   to a commit, written in EXTERNAL_LOCK. Commit this file: the next builds,
#   and the builds of the other developers and of the CI, use the same
#   commits. 'make update-externals' moves to the last commits.
# - The sources are fetched once per commit in a cache shared by all the
#   projects of the user (EXTERNAL_CACHE), and compiled once per
#   configuration (see CACHED_BUILD in targets.mk). EXTERNAL_CACHE= (empty)
#   clones in EXTERNAL_DIR of the project instead, as MyMakefile 2 did.
# - 't.PATH := ../imgui' uses a local copy instead, never fetched.
# - 't.URL := https://.../mujoco-3.3.0-linux-x86_64.tar.gz' downloads and
#   unpacks an archive (sources or binaries), once in the cache. 't.SHA256'
#   checks it, 't.SUBDIR' is the directory of the archive to use.

#? Where the sources and the builds of the third parties are shared.
ifeq ($(HOST_OS),Windows)
    MYMAKEFILE_CACHE ?= $(subst \,/,$(LOCALAPPDATA))/mymakefile
else
    MYMAKEFILE_CACHE ?= $(or $(XDG_CACHE_HOME),$(HOME)/.cache)/mymakefile
endif
EXTERNAL_CACHE ?= $(MYMAKEFILE_CACHE)
#? Commits of the third parties, written by MyMakefile.
EXTERNAL_LOCK ?= $(EXTERNAL_DIR)/versions.lock

# make cannot handle a path holding a space.
ifneq ($(word 2,$(EXTERNAL_CACHE)),)
    $(call print-warning,EXTERNAL_CACHE '$(EXTERNAL_CACHE)' holds a space: the third parties are cloned in $(EXTERNAL_DIR))
    override EXTERNAL_CACHE :=
endif

UPDATE_EXTERNALS := $(filter update-externals,$(MAKECMDGOALS))

###############################################################################
# Debugging helpers of MyMakefile 2, in debug mode: backward-cpp prints the
# stack of a crash (Linux, needs libdw: BACKWARD=0 to do without); dbg-macro
# gives dbg(...) (DBG_MACRO=0 to do without).
###############################################################################

BACKWARD ?= auto
DBG_MACRO ?= auto

# The targets of the project which will be executables.
is-executable = $(filter executable test,$(or $($1.TYPE),$(if $($1.SOURCES),executable)))
OWN_SOURCE_TARGETS := $(strip $(foreach t,$(TARGETS),$(if $($t.GIT)$($t.PATH)$($t.URL),,$(if $($t.SOURCES),$t))))
OWN_EXECUTABLES := $(strip $(foreach t,$(OWN_SOURCE_TARGETS),$(if $(call is-executable,$t),$t)))

ifeq ($(COMPILATION_MODE),debug)
    ifeq ($(filter 0 no off,$(BACKWARD))$(filter address thread memory hwaddress,$(subst $(COMMA), ,$(SANITIZER)))$(filter 1 yes,$(GPROF)),)
        ifeq ($(TARGET_OS),Linux)
            ifneq ($(and $(BUILDING),$(OWN_EXECUTABLES)),)
                USE_BACKWARD := $(if $(filter auto,$(BACKWARD)),$(shell $(PKG_CONFIG) --exists libdw && echo 1),1)
            endif
        endif
    endif
    ifeq ($(filter 0 no off,$(DBG_MACRO)),)
        USE_DBG_MACRO := $(if $(OWN_SOURCE_TARGETS),1)
    endif
endif

ifneq ($(USE_BACKWARD),)
    TARGETS += backward-cpp
    backward-cpp.GIT := https://github.com/bombela/backward-cpp.git
    backward-cpp.TYPE := objects
    backward-cpp.SOURCES := backward.cpp
    backward-cpp.PUBLIC_INCLUDES := .
    backward-cpp.PUBLIC_DEFINES := BACKWARD_HAS_DW=1 BACKWARD_HAS_BFD=0 \
        BACKWARD_HAS_DWARF=0 BACKWARD_HAS_UNWIND=1 BACKWARD_HAS_BACKTRACE=0 \
        BACKWARD_HAS_BACKTRACE_SYMBOL=1 BACKWARD_HAS_LIBUNWIND=0
    backward-cpp.PKG_CONFIG := libdw
    $(foreach t,$(OWN_EXECUTABLES),$(eval $t.DEPENDS += backward-cpp))
endif

ifneq ($(USE_DBG_MACRO),)
    TARGETS += dbg-macro
    dbg-macro.GIT := https://github.com/sharkdp/dbg-macro.git
    dbg-macro.PUBLIC_INCLUDES := .
    dbg-macro.PUBLIC_DEFINES := DBG_MACRO_NO_WARNING
    $(foreach t,$(OWN_SOURCE_TARGETS),$(eval $t.DEPENDS += dbg-macro))
endif

EXTERNAL_TARGETS := $(strip $(foreach t,$(TARGETS),$(if $($t.GIT)$($t.PATH)$($t.URL),$t)))
GIT_TARGETS := $(strip $(foreach t,$(TARGETS),$(if $($t.GIT),$(if $($t.PATH),,$t))))
URL_TARGETS := $(strip $(foreach t,$(TARGETS),$(if $($t.URL),$(if $($t.PATH)$($t.GIT),,$t))))
FETCHED_TARGETS := $(GIT_TARGETS) $(URL_TARGETS)

###############################################################################
# Resolution of the versions into commits.
###############################################################################

# The lock file is a makefile: 'imgui.LOCKED := <sha1>'.
ifneq ($(wildcard $(EXTERNAL_LOCK)),)
    $(eval $(file <$(EXTERNAL_LOCK)))
endif

# What to fetch: COMMIT, else the branch or tag VERSION, else the default
# branch of the repository.
git-ref = $(or $($1.COMMIT),$($1.VERSION),HEAD)

# The commit of a reference, asked to the repository. The commit of an
# annotated tag is given by 'refs/tags/X^{}'.
ls-remote = $(shell git ls-remote $($1.GIT) $(if $(filter HEAD,$2),HEAD,refs/heads/$2 refs/tags/$2 "refs/tags/$2^{}") 2>$(DEVNULL))
# 'sha<tab>ref' lines become 'sha@ref' words.
ls-remote-words = $(subst $(SPACE)HEAD,@HEAD,$(subst $(SPACE)refs/,@refs/,$(strip $1)))
remote-sha = $(firstword $(subst @, ,$(firstword $(filter %^{},$(call ls-remote-words,$1)) $(call ls-remote-words,$1))))

# The commit of an external: given, locked, or asked to the repository.
locked-sha = $(if $(and $(filter $(call git-ref,$1),$($1.LOCKED_REF)),$(if $(UPDATE_EXTERNALS),,1)),$(strip $($1.LOCKED)))
resolve-sha = $(or $($1.COMMIT),$(call locked-sha,$1),$(call remote-sha,$(call ls-remote,$1,$(call git-ref,$1))))

# Fetch only the commit; a server refusing it gets a full clone.
git-fetch = git init -q $2 && git -C $2 fetch -q --depth 1 $($1.GIT) $3 && git -C $2 checkout -q FETCH_HEAD
git-clone = git clone -q $($1.GIT) $2 && git -C $2 checkout -q $3
git-head = $(shell git -C $1 rev-parse HEAD 2>$(DEVNULL))

define FETCH_EXTERNAL
$(1)._SHA := $$(strip $$(call resolve-sha,$(1)))
ifeq ($$($(1)._SHA),)
    $$(call fail,cannot find '$$(call git-ref,$(1))' in $$($(1).GIT) for $(1))
endif
ifneq ($$(EXTERNAL_CACHE),)
    $(1)._SRCDIR := $$(EXTERNAL_CACHE)/sources/$(1)/$$($(1)._SHA)
    $(1)._FETCHED := $$(wildcard $$($(1)._SRCDIR)/.git/mymakefile-ok)
else
    $(1)._SRCDIR := $$(EXTERNAL_DIR)/$(1)
    $(1)._FETCHED := $$(filter $$($(1)._SHA),$$(call git-head,$$($(1)._SRCDIR)))
endif
ifeq ($$($(1)._FETCHED),)
    $$(call print-to,Fetching,$(1),$$($(1)._SRCDIR) $$(call git-ref,$(1)))
    FETCH_LOG := $$(shell $$(call remove-dir,$$($(1)._SRCDIR)))
    FETCH_LOG := $$(shell $$(call git-fetch,$(1),$$($(1)._SRCDIR),$$($(1)._SHA)) 2>&1)
    ifneq ($$(call git-head,$$($(1)._SRCDIR)),$$($(1)._SHA))
        FETCH_LOG := $$(shell $$(call remove-dir,$$($(1)._SRCDIR)))
        FETCH_LOG += $$(shell $$(call git-clone,$(1),$$($(1)._SRCDIR),$$($(1)._SHA)) 2>&1)
    endif
    ifneq ($$(call git-head,$$($(1)._SRCDIR)),$$($(1)._SHA))
        $$(call fail,cannot fetch $$($(1)._SHA) of $$($(1).GIT): $$(FETCH_LOG))
    endif
    $$(file >$$($(1)._SRCDIR)/.git/mymakefile-ok,$$($(1)._SHA))
endif
$(1).DIR := $$($(1)._SRCDIR)/
endef

# Archives: downloaded with curl (Linux, macOS, Windows 10), checked with the
# sha256 tool found, unpacked with tar (unzip for a .zip, but on Windows
# where tar reads them).
SHA256_TOOL := $(if $(call which,sha256sum),sha256sum,$(if $(call which,shasum),shasum -a 256,$(if $(filter Windows,$(HOST_OS)),certutil -hashfile)))
sha256-of = $(call lower,$(shell $(SHA256_TOOL) $1 $(if $(findstring certutil,$(SHA256_TOOL)),SHA256) 2>$(DEVNULL)))
archive-key = $(patsubst %.tar,%,$(basename $(notdir $1)))
extract-archive-into = $(if $(and $(filter %.zip,$1),$(filter-out Windows,$(HOST_OS))),unzip -q -o $1 -d $2,tar -xf $1 -C $2)

define FETCH_ARCHIVE
$(1)._SHA := $$(call archive-key,$$($(1).URL))
ifneq ($$(EXTERNAL_CACHE),)
    $(1)._SRCDIR := $$(EXTERNAL_CACHE)/sources/$(1)/$$($(1)._SHA)
    $(1)._DOWNLOAD := $$(EXTERNAL_CACHE)/downloads/$$(notdir $$($(1).URL))
else
    $(1)._SRCDIR := $$(EXTERNAL_DIR)/$(1)
    $(1)._DOWNLOAD := $$(EXTERNAL_DIR)/$$(notdir $$($(1).URL))
endif
ifeq ($$(wildcard $$($(1)._SRCDIR)/.mymakefile-ok),)
    $$(call print-to,Downloading,$(1),$$($(1)._SRCDIR))
    FETCH_LOG := $$(shell $$(call make-dir,$$(patsubst %/,%,$$(dir $$($(1)._DOWNLOAD)))))
    FETCH_LOG := $$(shell curl -fsSL -o $$($(1)._DOWNLOAD) $$($(1).URL) 2>&1)
    ifeq ($$(wildcard $$($(1)._DOWNLOAD)),)
        $$(call fail,cannot download $$($(1).URL): $$(FETCH_LOG))
    endif
    ifneq ($$($(1).SHA256),)
        ifeq ($$(filter $$(call lower,$$($(1).SHA256)),$$(call sha256-of,$$($(1)._DOWNLOAD))),)
            FETCH_LOG := $$(shell $$(call remove-files,$$($(1)._DOWNLOAD)))
            $$(call fail,$$($(1).URL) has not the SHA256 $$($(1).SHA256): download refused)
        endif
    endif
    FETCH_LOG := $$(shell $$(call remove-dir,$$($(1)._SRCDIR)))
    FETCH_LOG := $$(shell $$(call make-dir,$$($(1)._SRCDIR)))
    FETCH_LOG := $$(shell $$(call extract-archive-into,$$($(1)._DOWNLOAD),$$($(1)._SRCDIR)) 2>&1)
    ifeq ($$(wildcard $$($(1)._SRCDIR)/*),)
        $$(call fail,cannot unpack $$($(1)._DOWNLOAD): $$(FETCH_LOG))
    endif
    $$(file >$$($(1)._SRCDIR)/.mymakefile-ok,$$($(1).URL))
endif
$(1).DIR := $$($(1)._SRCDIR)/$$(if $$($(1).SUBDIR),$$($(1).SUBDIR)/)
endef

# A local copy: its paths are relative to the file declaring it.
define LOCAL_EXTERNAL
$(1).DIR := $$(call resolve,$$($(1).PATH),$$($(1).DIR))/
$(1)._SHA := local
endef

# The third parties of other configurations (backward-cpp exists in debug
# only) keep their line.
LOCKED_TARGETS := $(patsubst %.LOCKED,%,$(filter %.LOCKED,$(.VARIABLES)))
lock-ref = $(strip $(if $(filter $1,$(GIT_TARGETS)),$(call git-ref,$1),$($1.LOCKED_REF)))
lock-sha = $(strip $(if $(filter $1,$(GIT_TARGETS)),$($1._SHA),$($1.LOCKED)))

define LOCK_FILE
# Commits of the third parties of $(PROJECT_NAME), written by MyMakefile:
# commit this file. 'make update-externals' moves them to the last commit of
# their VERSION.
$(subst $(SPACE)$(NEWLINE),$(NEWLINE),$(foreach t,$(sort $(GIT_TARGETS) $(LOCKED_TARGETS)),$(NEWLINE)$t.LOCKED_REF := $(call lock-ref,$t)$(NEWLINE)$t.LOCKED := $(call lock-sha,$t)))
endef

ifneq ($(BUILDING),)
    $(foreach t,$(EXTERNAL_TARGETS),$(eval $(if $($t.PATH),$(call LOCAL_EXTERNAL,$t),$(if $($t.GIT),$(call FETCH_EXTERNAL,$t),$(call FETCH_ARCHIVE,$t)))))
    ifneq ($(GIT_TARGETS),)
        ifneq ($(call read-stamp,$(EXTERNAL_LOCK)),$(LOCK_FILE))
            $(call print-to,Locking,$(PROJECT_NAME),$(EXTERNAL_LOCK))
            $(call write-stamp,$(EXTERNAL_LOCK),$(LOCK_FILE))
        endif
    endif
endif

###############################################################################
# ExaequOS: epm.py installs the packages its pkg-config does not know (glfw,
# exa-wayland...), once, in the current directory: EXAEQUOS_PKGS/exapkgs.
###############################################################################

#? Where epm.py installs the packages of ExaequOS.
EXAEQUOS_PKGS ?= $(abspath $(BUILD_DIR)/exaequos)

ifneq ($(and $(EXAEQUOS),$(BUILDING)),)
    # make 4.3 does not give the exported variables to $(shell).
    PKG_CONFIG := PKG_CONFIG_PATH=$(EXAEQUOS_PKGS)/exapkgs/pkgconfigs$(if $(PKG_CONFIG_PATH),:$(PKG_CONFIG_PATH)) $(PKG_CONFIG)
    EXAEQUOS_MISSING := $(strip $(foreach p,$(call uniq,$(foreach t,$(TARGETS),$($t.PKG_CONFIG))),$(if $(shell $(PKG_CONFIG) --exists $p && echo 1),,$p)))
    ifneq ($(EXAEQUOS_MISSING),)
        $(call print-to,Installing ExaequOS packages,$(EXAEQUOS_MISSING),$(EXAEQUOS_PKGS))
        $(info $(shell $(call make-dir,$(EXAEQUOS_PKGS)) && cd $(EXAEQUOS_PKGS) && epm.py install $(EXAEQUOS_MISSING) 2>&1))
    endif
endif

#? Move the third parties to the last commit of their VERSION, and rewrite
#? EXTERNAL_LOCK.
.PHONY: update-externals
update-externals:
	$(call print-ok,Third parties at: $(foreach t,$(GIT_TARGETS),$t@$(call git-ref,$t)=$($t._SHA)))
	@$(NOOP)

#? Print the place of the third parties in the cache.
.PHONY: cache-info
cache-info:
	$(info Cache: $(or $(EXTERNAL_CACHE),none: the third parties are in $(EXTERNAL_DIR)))
	$(foreach t,$(EXTERNAL_TARGETS),$(info $(CYAN)$t$(COLOR_DEFAULT) $($t._SHA)$(NEWLINE)  sources $($t.DIR)$(if $($t._OBJS),$(NEWLINE)  build   $($t._OBJDIR))))
	@$(NOOP)

#? Remove the cache of the third parties, shared by all the projects.
.PHONY: cache-clean
cache-clean:
	$(call print-simple,Cleaning,$(EXTERNAL_CACHE))
	$(if $(EXTERNAL_CACHE),$(Q)$(call remove-dir,$(EXTERNAL_CACHE)))
