# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
#
# Turns the declaration of the targets into the rules of a single make graph.
# Variables of a target 't' written by the user are 't.SOMETHING'; the ones
# computed here are 't._SOMETHING'.

_MM_TYPES := executable test static shared library header-only
_MM_LIB_TYPES := static shared library
_MM_SRC_EXTS := %.c %.cc %.cpp %.cxx %.c++
_MM_DIRS :=

TARGETS := $(call _mm_uniq,$(TARGETS))

# Goals which neither compile nor need the third parties: with only them,
# MyMakefile does not clone, write the stamps or call pkg-config.
_mm_passive_goals := clean distclean veryclean clean-% help list-targets \
    print-% ci-info format check-format tarball
_mm_building := $(if $(MAKECMDGOALS),$(filter-out $(_mm_passive_goals),$(MAKECMDGOALS)),all)

###############################################################################
# Pass 1: defaults, cloning of the external targets, files of each target.
###############################################################################

define _mm_resolve_target
ifneq ($$(filter $(1),$$(_MM_TYPES)),)
    $$(call _mm_fail,a target cannot be named '$(1)')
endif
ifdef $(1).GIT
    $(1).DIR := $$(EXTERNAL_DIR)/$(1)/
    $(1).WARNINGS ?= none
    $(1).SYSTEM ?= 1
    $(1)._CLONE := $$(EXTERNAL_DIR)/$(1)/.git
endif
$(1).NAME ?= $(1)
$(1).WARNINGS ?= strict
$(1).TYPE ?= $$(if $$($(1).SOURCES),executable,header-only)
ifeq ($$(filter $$($(1).TYPE),$$(_MM_TYPES)),)
    $$(call _mm_fail,$(1).TYPE is '$$($(1).TYPE)'$$(_mm_comma) expected one of: $$(_MM_TYPES))
endif

$(1)._SRCS := $$(filter $$(_MM_SRC_EXTS),$$(call _mm_glob,$$($(1).SOURCES),$$($(1).DIR)))
$(1)._PUB_INCS := $$(call _mm_resolve,$$($(1).PUBLIC_INCLUDES),$$($(1).DIR))
$(1)._PRIV_INCS := $$(call _mm_resolve,$$($(1).INCLUDES),$$($(1).DIR))
$(1)._DATA := $$(call _mm_resolve,$$($(1).DATA),$$($(1).DIR))
$(1)._ICON := $$(call _mm_resolve,$$($(1).ICON),$$($(1).DIR))
$(1)._OBJDIR := $$(BUILD)/obj/$(1)
$(1)._OBJS := $$(foreach s,$$($(1)._SRCS),$$($(1)._OBJDIR)/$$(basename $$(call _mm_objstem,$$s))$$(OBJ_EXT))
$(1)._IS_LIB := $$(filter $$($(1).TYPE),$$(_MM_LIB_TYPES))

# Without shared libraries (Emscripten), a shared library is a static one.
$(1)._ARCHIVE := $$(if $$(filter static library,$$($(1).TYPE))$$(if $$(SHARED_SUPPORTED),,$$(filter shared,$$($(1).TYPE))),$$(BUILD)/lib/$$(LIB_PREFIX)$$($(1).NAME)$$(STATIC_EXT))
$(1)._SHARED := $$(if $$(SHARED_SUPPORTED),$$(if $$(filter shared library,$$($(1).TYPE)),$$(BUILD)/$$(if $$(filter Windows,$$(TARGET_OS)),bin,lib)/$$(call _mm_tc_shared_name,$$($(1).NAME))))
$(1)._IMPLIB := $$(if $$(and $$($(1)._SHARED),$$(filter Windows,$$(TARGET_OS))),$$(BUILD)/lib/$$(LIB_PREFIX)$$($(1).NAME).dll.a)
$(1)._EXE := $$(if $$(filter executable,$$($(1).TYPE)),$$(BUILD)/bin/$$($(1).NAME)$$(or $$($(1).EXT),$$(EXE_EXT)))$$(if $$(filter test,$$($(1).TYPE)),$$(BUILD)/bin/$$($(1).NAME)$$(or $$($(1).EXT),$$(TEST_EXT)))
# macOS application bundle: 't.BUNDLE := 1'.
$(1)._BUNDLE := $$(if $$(and $$($(1).BUNDLE),$$($(1)._EXE),$$(filter Darwin,$$(TARGET_OS))),$$(BUILD)/bin/$$($(1).NAME).app)
$(1)._OUTS := $$($(1)._ARCHIVE) $$($(1)._SHARED) $$($(1)._EXE) $$($(1)._BUNDLE)
# What the targets depending on this one link with: the static library first.
$(1)._LINKABLE := $$(or $$($(1)._ARCHIVE),$$($(1)._IMPLIB),$$($(1)._SHARED))

ifneq ($$($(1).PROJECT_INFO)$$($(1)._BUNDLE),)
    $(1)._GENDIR := $$(BUILD)/gen/$(1)
endif
ifneq ($$($(1).PROJECT_INFO),)
    $(1)._INFO := $$($(1)._GENDIR)/project_info.hpp
endif

$(1)._CC_STAMP := $$($(1)._OBJDIR)/compile-flags.txt
$(1)._LD_STAMP := $$($(1)._OBJDIR)/link-flags.txt
endef

# Clone an external target when it is missing, before the wildcards on its
# sources are expanded.
define _mm_clone
ifeq ($$(wildcard $$(EXTERNAL_DIR)/$(1)/.git),)
    $$(call _mm_say_to,Cloning,$(1),$$(EXTERNAL_DIR)/$(1) $$($(1).VERSION)$$($(1).COMMIT))
    _mm_out := $$(shell git clone --quiet $$(if $$($(1).COMMIT),,--depth 1) $$(if $$($(1).VERSION),--branch $$($(1).VERSION)) $$($(1).GIT) $$(EXTERNAL_DIR)/$(1) 2>&1)
    ifneq ($$($(1).COMMIT),)
        _mm_out += $$(shell git -C $$(EXTERNAL_DIR)/$(1) checkout --quiet $$($(1).COMMIT) 2>&1)
    endif
    ifeq ($$(wildcard $$(EXTERNAL_DIR)/$(1)/.git),)
        $$(call _mm_fail,cannot clone $$($(1).GIT): $$(_mm_out))
    endif
endif
endef

ifneq ($(_mm_building),)
    $(foreach t,$(TARGETS),$(if $($t.GIT),$(eval $(call _mm_clone,$t))))
endif
$(foreach t,$(TARGETS),$(eval $(call _mm_resolve_target,$t)))

###############################################################################
# Pass 2: dependency graph. t._DEPS holds every target t depends on, directly
# or not, in link order: a library comes after the libraries using it.
###############################################################################

_mm_closure = $(foreach d,$($1.DEPENDS),$(if $(filter $d,$2),$(call _mm_fail,dependency cycle: $2 $d))$(if $(filter $d,$(TARGETS)),,$(call _mm_fail,'$(lastword $2)' depends on '$d' which is not in TARGETS))$d $(call _mm_closure,$d,$2 $d))

$(foreach t,$(TARGETS),$(eval $t._DEPS := $(call _mm_uniq_last,$(call _mm_closure,$t,$t))))

###############################################################################
# Pass 3: compilation and link flags of each target.
###############################################################################

_mm_pkg_cflags = $(if $(and $1,$(_mm_building)),$(shell $(PKG_CONFIG) --cflags $1 2>$(_mm_devnull)))
_mm_pkg_libs = $(if $(and $1,$(_mm_building)),$(shell $(PKG_CONFIG) $(if $(PKG_CONFIG_STATIC),--static) --libs $1 2>$(_mm_devnull)))

# Packages pkg-config does not know, asked once each. A target missing some
# stops make when it is built, not when another target is.
_mm_pkg_found = $(if $(filter undefined,$(origin _mm_pkg.$1)),$(eval _mm_pkg.$1 := $(shell $(PKG_CONFIG) --exists $1 && echo 1)))$(_mm_pkg.$1)
_mm_pkg_missing = $(if $(_mm_building),$(foreach p,$1,$(if $(call _mm_pkg_found,$p),,$p)))
_mm_check_pkgs = $(if $($1._PKG_MISSING),$(call _mm_fail,$1 needs the packages '$($1._PKG_MISSING)'$(_mm_comma) unknown to $(PKG_CONFIG): install them or set PKG_CONFIG_PATH))

define _mm_flags
$(1)._PKGS := $$(call _mm_uniq,$$($(1).PKG_CONFIG) $$(foreach d,$$($(1)._DEPS),$$($$d.PKG_CONFIG)))
$(1)._PKG_MISSING := $$(strip $$(call _mm_pkg_missing,$$($(1)._PKGS)))
$(1)._CPPFLAGS := \
    $$(addprefix $$(TC_DEF),$$(TC_MODE_DEFINES) $$($(1).DEFINES) $$($(1).PUBLIC_DEFINES) \
        $$(foreach d,$$($(1)._DEPS),$$($$d.PUBLIC_DEFINES))) \
    $$(addprefix $$(TC_INC),$$($(1)._PRIV_INCS) $$($(1)._PUB_INCS) $$($(1)._GENDIR)) \
    $$(foreach d,$$($(1)._DEPS),$$(addprefix $$(if $$($$d.SYSTEM),$$(TC_SYSINC),$$(TC_INC)),$$($$d._PUB_INCS))) \
    $$(call _mm_pkg_cflags,$$($(1)._PKGS))
$(1)._PIC := $$(if $$($(1)._IS_LIB),$$(PIC_FLAGS))
$(1)._CXXFLAGS := $$(strip $$(call _mm_tc_std,$$(CXX_STANDARD)) $$(TC_MODE_FLAGS) \
    $$(call _mm_tc_warnings_cxx,$$($(1).WARNINGS)) $$($(1)._PIC) $$($(1)._CPPFLAGS) \
    $$($(1).CXXFLAGS) $$(CXXFLAGS))
$(1)._CFLAGS := $$(strip $$(if $$(C_STANDARD),$$(call _mm_tc_std,$$(C_STANDARD))) $$(TC_MODE_FLAGS) \
    $$(call _mm_tc_warnings_c,$$($(1).WARNINGS)) $$($(1)._PIC) $$($(1)._CPPFLAGS) \
    $$($(1).CFLAGS) $$(CFLAGS))

$(1)._LINKDEPS := $$(foreach d,$$($(1)._DEPS),$$($$d._LINKABLE))
$(1)._LINKER := $$(if $$(filter-out %.c,$$($(1)._SRCS) $$(foreach d,$$($(1)._DEPS),$$($$d._SRCS))),$$(CXX),$$(CC))
$(1)._LDFLAGS := $$(strip $$(TC_MODE_LDFLAGS) $$($(1).LDFLAGS) $$(LDFLAGS) \
    $$(if $$(and $$(filter-out Windows,$$(TARGET_OS)),$$(filter-out %$$(STATIC_EXT),$$($(1)._LINKDEPS))),-Wl$$(_mm_comma)-rpath$$(_mm_comma)$$(abspath $$(BUILD)/lib)))
$(1)._LIBS := $$(strip $$($(1)._LINKDEPS) $$($(1).LIBS) \
    $$(foreach d,$$($(1)._DEPS),$$($$d.LIBS)) $$(call _mm_pkg_libs,$$($(1)._PKGS)))

# A changed flag rebuilds the objects, a changed list of sources relinks.
$(1)._CC_SIG := $$(strip $$($(1)._CXXFLAGS) | $$($(1)._CFLAGS))
$(1)._LD_SIG := $$(strip $$($(1)._OBJS) | $$($(1)._LDFLAGS) $$($(1)._LIBS))
ifneq ($$(_mm_building),)
    ifneq ($$(call _mm_read_stamp,$$($(1)._CC_STAMP)),$$($(1)._CC_SIG))
        $$(call _mm_write_stamp,$$($(1)._CC_STAMP),$$($(1)._CC_SIG))
    endif
    ifneq ($$(call _mm_read_stamp,$$($(1)._LD_STAMP)),$$($(1)._LD_SIG))
        $$(call _mm_write_stamp,$$($(1)._LD_STAMP),$$($(1)._LD_SIG))
    endif
endif
endef

$(foreach t,$(TARGETS),$(eval $(call _mm_flags,$t)))

###############################################################################
# Pass 4: rules.
###############################################################################

# $1: target, $2: source, $3: object, $4: cxx or c
define _mm_compile_rule
$(3): $(2) $$($(1)._CC_STAMP) | $(patsubst %/,%,$(dir $(3))) $$($(1)._INFO)
	$$(call _mm_check_pkgs,$(1))
	$$(call _mm_say_from,Compiling $(if $(filter c,$(4)),C,C++),$(1),$$<)
	$$(Q)$$(call _mm_tc_compile_$(4),$(1))
endef

define _mm_target_rules
.PHONY: $(1)
$(1): $$($(1)._OUTS)

$$(foreach s,$$($(1)._SRCS),$$(eval $$(call _mm_compile_rule,$(1),$$s,$$($(1)._OBJDIR)/$$(basename $$(call _mm_objstem,$$s))$$(OBJ_EXT),$$(if $$(filter %.c,$$s),c,cxx))))
-include $$(wildcard $$($(1)._OBJS:%$$(OBJ_EXT)=%.d))
_MM_DIRS += $$(patsubst %/,%,$$(dir $$($(1)._OBJS) $$($(1)._OUTS) $$($(1)._IMPLIB))) $$($(1)._GENDIR)

ifneq ($$($(1)._ARCHIVE),)
$$($(1)._ARCHIVE): $$($(1)._OBJS) $$($(1)._LD_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._ARCHIVE)))
	$$(call _mm_say_to,Static library,$(1),$$@)
	$$(Q)$$(call _mm_rm,$$@)
	$$(Q)$$(call _mm_tc_archive,$(1))
endif

ifneq ($$($(1)._SHARED),)
$$($(1)._SHARED): $$($(1)._OBJS) $$($(1)._LINKDEPS) $$($(1)._LD_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._SHARED) $$($(1)._IMPLIB)))
	$$(call _mm_check_pkgs,$(1))
	$$(call _mm_say_to,Shared library,$(1),$$@)
	$$(Q)$$(call _mm_tc_link_shared,$(1))
	$$(if $$(_mm_tc_shared_post),$$(Q)$$(call _mm_tc_shared_post,$(1)))
ifneq ($$($(1)._IMPLIB),)
$$($(1)._IMPLIB): $$($(1)._SHARED) ;
endif
endif

ifneq ($$($(1)._EXE),)
$$($(1)._EXE): $$($(1)._OBJS) $$($(1)._LINKDEPS) $$($(1)._LD_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._EXE)))
	$$(call _mm_check_pkgs,$(1))
	$$(call _mm_say_to,Linking,$(1),$$@)
	$$(Q)$$(call _mm_tc_link_exe,$(1))

.PHONY: run-$(1)
run-$(1): $(1)
	$$(call _mm_say_simple,Running,$(1))
	$$(Q)$$(if $$(filter test,$$($(1).TYPE)),$$(TEST_RUNNER),$$(RUNNER)) $$(call _mm_exec,$$($(1)._EXE)) $$($(1).ARGS) $$(ARGS)
endif

ifneq ($$($(1)._BUNDLE),)
$$($(1)._GENDIR)/Info.plist: $$($(1)._LD_STAMP) | $$($(1)._GENDIR)
	$$(file >$$@,$$(call _mm_info_plist,$(1)))

$$($(1)._BUNDLE): $$($(1)._EXE) $$($(1)._GENDIR)/Info.plist $$($(1)._ICON)
	$$(call _mm_say_to,Bundle,$(1),$$@)
	$$(Q)$$(call _mm_rmdir,$$@)
	$$(Q)mkdir -p $$@/Contents/MacOS $$@/Contents/Resources
	$$(Q)cp -f $$($(1)._EXE) $$@/Contents/MacOS/$$($(1).NAME)
	$$(Q)cp -f $$($(1)._GENDIR)/Info.plist $$@/Contents/Info.plist
	$$(if $$($(1)._ICON),$$(Q)cp -f $$($(1)._ICON) $$@/Contents/Resources/$$($(1).NAME).icns)
	$$(foreach d,$$($(1)._DATA),$$(Q)cp -R $$d/. $$@/Contents/Resources/$$(_mm_newline))
endif

ifneq ($$($(1)._INFO),)
$$($(1)._INFO): $$($(1)._GENDIR)/info.txt | $$($(1)._GENDIR)
	$$(call _mm_say_to,Generating,$(1),$$@)
	$$(file >$$@,$$(call _mm_project_info_hpp,$(1)))
endif

.PHONY: clean-$(1)
clean-$(1):
	$$(call _mm_say_simple,Cleaning,$(1))
	$$(Q)$$(call _mm_rmdir,$$($(1)._OBJDIR))
	$$(if $$($(1)._GENDIR),$$(Q)$$(call _mm_rmdir,$$($(1)._GENDIR)))
	$$(if $$(strip $$($(1)._OUTS) $$($(1)._IMPLIB)),$$(Q)$$(call _mm_rm,$$($(1)._OUTS) $$($(1)._IMPLIB)))
endef

$(foreach t,$(TARGETS),$(eval $(call _mm_target_rules,$t)))

# One rule per directory of the build, shared by all the targets.
$(foreach d,$(sort $(_MM_DIRS)),$(eval $d: ; $$(Q)$$(call _mm_mkdir,$$@)))
