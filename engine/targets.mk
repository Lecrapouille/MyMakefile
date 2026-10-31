###############################################################################
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
###############################################################################
#
# Turns the declaration of the targets into the rules of a single make graph.
# The variables of a target 't' written by the user are 't.SOMETHING'; the
# ones computed here are 't._SOMETHING'.

TARGET_TYPES := executable test static shared library objects header-only
LIBRARY_TYPES := static shared library
COMPILED_TYPES := executable test static shared library objects
SOURCE_EXTS := %.c %.cc %.cpp %.cxx %.c++
HEADER_EXTS := %.h %.hh %.hpp %.hxx %.ipp %.tpp %.inl %.incl
BUILD_DIRS :=

#? What a target can define: anything else is reported as a typo.
TARGET_ATTRIBUTES := TYPE SOURCES INCLUDES PUBLIC_INCLUDES DEFINES \
    PUBLIC_DEFINES DEPENDS PKG_CONFIG CXXFLAGS CFLAGS LDFLAGS LIBS RPATH \
    WARNINGS NAME DESCRIPTION PROJECT_INFO DATA ARGS INSTALL CLEAN \
    PUBLIC_HEADERS PRIVATE_HEADERS MERGE BUNDLE ICON BUNDLE_ID EXT SYSTEM \
    GIT VERSION COMMIT PATH DIR LOCKED LOCKED_REF

# The object file of a source: the tree of the sources is kept below the
# object directory, and never escapes from it. The sources of a third party
# are taken from its own directory.
object-stem = $(if $(call is-absolute,$1),_abs/$(subst :,,$(patsubst /%,%,$1)),$1)
object-of = $($1._OBJDIR)/$(basename $(call object-stem,$(if $(filter $1,$(EXTERNAL_TARGETS)),$(patsubst $($1.DIR)%,%,$2),$2)))$(OBJ_EXT)

# Sources given to a target but not found: a pattern matching nothing, or a
# file which does not exist.
missing-sources = $(foreach p,$1,$(if $(wildcard $(call glob,$p,$2)),,$p))

# String equality.
same = $(and $(findstring x$1x,x$2x),$(findstring x$2x,x$1x))

###############################################################################
# Pass 1: defaults, checks and files of each target.
###############################################################################

define RESOLVE_TARGET
ifneq ($$(filter $(1),$$(TARGET_TYPES)),)
    $$(call fail,a target cannot be named '$(1)')
endif
ifneq ($$(filter lib%,$(1)),)
    $$(call fail,the target '$(1)' shall not start by lib: MyMakefile adds it to the name of the libraries)
endif
ifneq ($$(filter $(1),$$(EXTERNAL_TARGETS)),)
    $(1).WARNINGS ?= none
    $(1).SYSTEM ?= 1
endif
$(1).NAME ?= $$(if $$(FORCE_LOWER_CASE),$$(call lower,$(1)),$(1))
$(1).WARNINGS ?= strict
$(1).TYPE ?= $$(if $$($(1).SOURCES),executable,header-only)
ifeq ($$(filter $$($(1).TYPE),$$(TARGET_TYPES)),)
    $$(call fail,$(1).TYPE is '$$($(1).TYPE)'$$(COMMA) expected one of: $$(TARGET_TYPES))
endif
ifneq ($$(filter-out $$(addprefix $(1).,$$(TARGET_ATTRIBUTES)) $(1)._%,$$(filter $(1).%,$$(.VARIABLES))),)
    $$(call print-warning,unknown variables $$(filter-out $$(addprefix $(1).,$$(TARGET_ATTRIBUTES)) $(1)._%,$$(filter $(1).%,$$(.VARIABLES))): a typo? Known: $$(TARGET_ATTRIBUTES))
endif

$(1)._SRCS := $$(filter $$(SOURCE_EXTS),$$(call glob,$$($(1).SOURCES),$$($(1).DIR)))
ifneq ($$(BUILDING),)
    ifneq ($$(strip $$(call missing-sources,$$($(1).SOURCES),$$($(1).DIR))),)
        $$(call fail,$(1).SOURCES: no file for '$$(strip $$(call missing-sources,$$($(1).SOURCES),$$($(1).DIR)))' in $$(or $$($(1).DIR),the root of the project))
    endif
    ifneq ($$(and $$(filter $$($(1).TYPE),$$(COMPILED_TYPES)),$$(if $$($(1)._SRCS),,1)),)
        $$(call fail,$(1) is a $$($(1).TYPE) without SOURCES)
    endif
endif
$(1)._PUB_INCS := $$(call resolve,$$($(1).PUBLIC_INCLUDES),$$($(1).DIR))
$(1)._PRIV_INCS := $$(call resolve,$$($(1).INCLUDES),$$($(1).DIR))
$(1)._DATA := $$(call resolve,$$($(1).DATA),$$($(1).DIR))
$(1)._ICON := $$(call resolve,$$($(1).ICON),$$($(1).DIR))
$(1)._IS_LIB := $$(filter $$($(1).TYPE),$$(LIBRARY_TYPES))
$(1)._IS_EXE := $$(filter executable test,$$($(1).TYPE))
$(1)._OBJDIR := $$(BUILD)/obj/$(1)
$(1)._OBJS := $$(foreach s,$$($(1)._SRCS),$$(call object-of,$(1),$$s))
$(1)._LIBDIR := $$(BUILD)/lib

# Without shared libraries (Emscripten, MSVC), a shared library is a static one.
$(1)._ARCHIVE := $$(if $$(filter static library,$$($(1).TYPE))$$(if $$(SHARED_SUPPORTED),,$$(filter shared,$$($(1).TYPE))),$$($(1)._LIBDIR)/$$(LIB_PREFIX)$$($(1).NAME)$$(STATIC_EXT))
$(1)._SHARED := $$(if $$(SHARED_SUPPORTED),$$(if $$(filter shared library,$$($(1).TYPE)),$$(if $$(filter Windows,$$(TARGET_OS)),$$(BUILD)/bin,$$($(1)._LIBDIR))/$$(call tc-shared-name,$$($(1).NAME))))
$(1)._IMPLIB := $$(if $$(and $$($(1)._SHARED),$$(filter Windows,$$(TARGET_OS))),$$($(1)._LIBDIR)/$$(LIB_PREFIX)$$($(1).NAME).dll.a)
$(1)._EXE := $$(if $$($(1)._IS_EXE),$$(BUILD)/bin/$$($(1).NAME)$$(or $$($(1).EXT),$$(if $$(filter test,$$($(1).TYPE)),$$(TEST_EXT),$$(EXE_EXT))))
# macOS application bundle: 't.BUNDLE := 1'.
$(1)._BUNDLE := $$(if $$(and $$($(1).BUNDLE),$$($(1)._EXE),$$(filter Darwin,$$(TARGET_OS))),$$(BUILD)/bin/$$($(1).NAME).app)
# pkg-config file of the build tree: PKG_CONFIG_PATH=build/.../lib/pkgconfig
$(1)._PC := $$(if $$(and $$($(1)._IS_LIB),$$(filter-out $(1),$$(EXTERNAL_TARGETS))),$$($(1)._LIBDIR)/pkgconfig/$$($(1).NAME).pc)

ifneq ($$($(1).PROJECT_INFO)$$($(1)._BUNDLE),)
    $(1)._GENDIR := $$(BUILD)/gen/$(1)
endif
ifneq ($$($(1).PROJECT_INFO),)
    $(1)._INFO := $$($(1)._GENDIR)/project_info.hpp
endif
$(1)._CC_STAMP := $$($(1)._OBJDIR)/compile-flags.txt
$(1)._LD_STAMP := $$($(1)._OBJDIR)/link-flags.txt
endef

$(foreach t,$(TARGETS),$(eval $(call RESOLVE_TARGET,$t)))

###############################################################################
# Pass 2: dependency graph. t._DEPS holds every target t depends on, directly
# or not, in link order: a library comes after the libraries using it.
###############################################################################

closure = $(foreach d,$($1.DEPENDS),$(if $(filter $d,$2),$(call fail,dependency cycle: $2 $d))$(if $(filter $d,$(TARGETS)),,$(call fail,'$(lastword $2)' depends on '$d' which is not in TARGETS))$(if $($d._IS_EXE),$(call fail,'$(lastword $2)' depends on the $($d.TYPE) '$d': only libraries can be linked))$d $(call closure,$d,$2 $d))

$(foreach t,$(TARGETS),$(eval $t._DEPS := $(call uniq-last,$(call closure,$t,$t))))

###############################################################################
# Pass 3: compilation flags.
###############################################################################

pkg-cflags = $(if $(and $1,$(BUILDING)),$(shell $(PKG_CONFIG) --cflags $1 2>$(DEVNULL)))
pkg-libs = $(if $(and $1,$(BUILDING)),$(shell $(PKG_CONFIG) $(if $(PKG_CONFIG_STATIC),--static) --libs $1 2>$(DEVNULL)))

# Packages pkg-config does not know, asked once each. A target missing some
# stops make when it is built, not when another target is.
pkg-found = $(if $(filter undefined,$(origin PKG_FOUND.$1)),$(eval PKG_FOUND.$1 := $(shell $(PKG_CONFIG) --exists $1 && echo 1)))$(PKG_FOUND.$1)
pkg-missing = $(if $(BUILDING),$(foreach p,$1,$(if $(call pkg-found,$p),,$p)))
check-packages = $(if $($1._PKG_MISSING),$(call fail,$1 needs the packages '$($1._PKG_MISSING)'$(COMMA) unknown to $(PKG_CONFIG): install them or set PKG_CONFIG_PATH))

define COMPILE_FLAGS
$(1)._IS_OWN := $$(if $$(filter $(1),$$(EXTERNAL_TARGETS)),,1)
$(1)._PKGS := $$(call uniq,$$($(1).PKG_CONFIG) $$(foreach d,$$($(1)._DEPS),$$($$d.PKG_CONFIG)))
$(1)._PKG_MISSING := $$(strip $$(call pkg-missing,$$($(1)._PKGS)))
$(1)._CPPFLAGS := $$(TC_UNDEFINES) \
    $$(addprefix $$(TC_DEF),$$(TC_MODE_DEFINES) $$($(1).DEFINES) $$($(1).PUBLIC_DEFINES) \
        $$(foreach d,$$($(1)._DEPS),$$($$d.PUBLIC_DEFINES))) \
    $$(addprefix $$(TC_INC),$$($(1)._PRIV_INCS) $$($(1)._PUB_INCS) $$($(1)._GENDIR)) \
    $$(foreach d,$$($(1)._DEPS),$$(addprefix $$(if $$($$d.SYSTEM),$$(TC_SYSINC),$$(TC_INC)),$$($$d._PUB_INCS))) \
    $$(call pkg-cflags,$$($(1)._PKGS))
# Position independent code for the libraries, executables for the others.
$(1)._TYPE_FLAGS := $$(if $$(filter $$($(1).TYPE),$$(LIBRARY_TYPES) objects),$$(PIC_FLAGS),$$(TC_EXE_FLAGS))
$(1)._WERROR := $$(if $$(and $$($(1)._IS_OWN),$$(filter 1 yes,$$(WERROR))),$$(TC_WERROR))
$(1)._CXXFLAGS := $$(strip $$(call tc-std,$$(CXX_STANDARD)) $$(TC_MODE_FLAGS) \
    $$(call tc-warnings-cxx,$$($(1).WARNINGS)) $$($(1)._WERROR) $$($(1)._TYPE_FLAGS) \
    $$($(1)._CPPFLAGS) $$($(1).CXXFLAGS) $$(CXXFLAGS))
$(1)._CFLAGS := $$(strip $$(if $$(C_STANDARD),$$(call tc-std,$$(C_STANDARD))) $$(TC_MODE_FLAGS) \
    $$(call tc-warnings-c,$$($(1).WARNINGS)) $$($(1)._WERROR) $$($(1)._TYPE_FLAGS) \
    $$($(1)._CPPFLAGS) $$($(1).CFLAGS) $$(CFLAGS))
# The compiler is part of it: a new compiler rebuilds everything.
$(1)._CC_SIG := $$(strip $$(COMPILER_FAMILY) $$(COMPILER_VERSION) $$(TARGET_ARCH) | $$($(1)._CXXFLAGS) | $$($(1)._CFLAGS))
endef

$(foreach t,$(TARGETS),$(eval $(call COMPILE_FLAGS,$t)))

###############################################################################
# Pass 4: a third party is compiled once per configuration in the cache. Its
# object directory there is the one whose compilation flags are the same.
###############################################################################

cache-match = $(firstword $(foreach d,$(patsubst %/compile-flags.txt,%,$(wildcard $1-*/compile-flags.txt)),$(if $(call same,$(call read-stamp,$d/compile-flags.txt),$2),$d)))
cache-new = $1-$(words $(wildcard $1-*/compile-flags.txt) x)

define CACHED_BUILD
$(1)._CACHE_BASE := $$(EXTERNAL_CACHE)/builds/$(1)/$$($(1)._SHA)/$$(notdir $$(BUILD))
$(1)._OBJDIR := $$(or $$(call cache-match,$$($(1)._CACHE_BASE),$$($(1)._CC_SIG)),$$(call cache-new,$$($(1)._CACHE_BASE)))
$(1)._LIBDIR := $$($(1)._OBJDIR)
$(1)._OBJS := $$(foreach s,$$($(1)._SRCS),$$(call object-of,$(1),$$s))
$(1)._ARCHIVE := $$(if $$($(1)._ARCHIVE),$$($(1)._OBJDIR)/$$(notdir $$($(1)._ARCHIVE)))
$(1)._SHARED := $$(if $$($(1)._SHARED),$$($(1)._OBJDIR)/$$(notdir $$($(1)._SHARED)))
$(1)._IMPLIB := $$(if $$($(1)._IMPLIB),$$($(1)._OBJDIR)/$$(notdir $$($(1)._IMPLIB)))
$(1)._CC_STAMP := $$($(1)._OBJDIR)/compile-flags.txt
$(1)._LD_STAMP := $$($(1)._OBJDIR)/link-flags.txt
endef

ifneq ($(and $(EXTERNAL_CACHE),$(BUILDING)),)
    $(foreach t,$(GIT_TARGETS),$(if $($t._SRCS),$(eval $(call CACHED_BUILD,$t))))
endif

# What a target builds, and what the targets depending on it link with: the
# static library first, the objects themselves for an 'objects' target.
$(foreach t,$(TARGETS),$(eval $t._OUTS := $(strip $($t._ARCHIVE) $($t._SHARED) $($t._EXE) $($t._BUNDLE) $($t._PC))))
$(foreach t,$(TARGETS),$(eval $t._LINKABLE := $(if $(filter objects,$($t.TYPE)),$($t._OBJS),$(or $($t._ARCHIVE),$($t._IMPLIB),$($t._SHARED)))))

###############################################################################
# Pass 5: link flags. 't.MERGE := imgui path/libfoo.a' puts the objects of
# these static libraries in the static library of t (the targets depending on
# t then do not link them again).
###############################################################################

define LINK_FLAGS
$(1)._MERGE_TARGETS := $$(filter $$(TARGETS),$$($(1).MERGE))
$(1)._MERGE_ARCHIVES := $$(call resolve,$$(filter-out $$(TARGETS),$$($(1).MERGE)),$$($(1).DIR))
$(1)._MERGE_DIRS := $$(foreach a,$$($(1)._MERGE_ARCHIVES),$$($(1)._OBJDIR)/merged/$$(basename $$(notdir $$a)))
$(1)._ARCHIVE_OBJS := $$($(1)._OBJS) $$(foreach d,$$($(1)._MERGE_TARGETS),$$($$d._OBJS)) $$(addsuffix /*$$(OBJ_EXT),$$($(1)._MERGE_DIRS))
$(1)._LINK_OBJS := $$($(1)._OBJS)
$(1)._MERGED_BY_DEPS := $$(foreach d,$$($(1)._DEPS),$$($$d._MERGE_TARGETS))
$(1)._LINKDEPS := $$(foreach d,$$(filter-out $$($(1)._MERGED_BY_DEPS),$$($(1)._DEPS)),$$($$d._LINKABLE))
$(1)._LINKER := $$(if $$(filter-out %.c,$$($(1)._SRCS) $$(foreach d,$$($(1)._DEPS),$$($$d._SRCS))),$$(CXX),$$(CC))
$(1)._SHARED_DEPS := $$(foreach d,$$($(1)._DEPS),$$(if $$(filter $$($$d._LINKABLE),$$($$d._SHARED)),$$($$d._SHARED)))
$(1)._RPATHS := $$(if $$(filter Windows Emscripten,$$(TARGET_OS)),,$$(abspath $$(sort $$(dir $$($(1)._SHARED_DEPS)))) $$(subst :, ,$$(RPATH) $$($(1).RPATH)))
$(1)._LDFLAGS := $$(strip $$(TC_MODE_LDFLAGS) \
    $$(if $$($(1)._IS_EXE),$$(TC_EXE_LDFLAGS)) \
    $$(if $$($(1)._IS_EXE)$$($(1)._SHARED),$$(TC_HARDEN_LDFLAGS) $$(TC_STRIP_LDFLAGS)) \
    $$(addprefix -Wl$$(COMMA)-rpath$$(COMMA),$$($(1)._RPATHS)) \
    $$($(1).LDFLAGS) $$(LDFLAGS))
$(1)._LIBS := $$(strip $$($(1)._LINKDEPS) $$($(1)._MERGE_ARCHIVES) $$($(1).LIBS) \
    $$(foreach d,$$($(1)._DEPS),$$($$d.LIBS)) $$(call pkg-libs,$$($(1)._PKGS)))

# A changed flag rebuilds the objects, a changed list of objects relinks.
$(1)._LD_SIG := $$(strip $$($(1)._ARCHIVE_OBJS) | $$($(1)._LDFLAGS) $$($(1)._LIBS))
ifneq ($$(BUILDING),)
    ifneq ($$(call read-stamp,$$($(1)._CC_STAMP)),$$($(1)._CC_SIG))
        $$(call write-stamp,$$($(1)._CC_STAMP),$$($(1)._CC_SIG))
    endif
    ifneq ($$(call read-stamp,$$($(1)._LD_STAMP)),$$($(1)._LD_SIG))
        $$(call write-stamp,$$($(1)._LD_STAMP),$$($(1)._LD_SIG))
    endif
endif
endef

$(foreach t,$(TARGETS),$(eval $(call LINK_FLAGS,$t)))

###############################################################################
# Pass 6: rules.
###############################################################################

# $1: target, $2: source, $3: object, $4: cxx or c
define COMPILE_RULE
$(3): $(2) $$($(1)._CC_STAMP) | $(patsubst %/,%,$(dir $(3))) $$($(1)._INFO)
	$$(call check-packages,$(1))
	$$(call print-from,Compiling $(if $(filter c,$(4)),C,C++),$(1),$$<)
	$$(Q)$$(call tc-compile-$(4),$(1))
endef

# Objects of the static libraries given to 't.MERGE'.
extract-archive = $(call cmd,$(call remove-dir,$2))$(call cmd,$(call make-dir,$2))$(call cmd,cd $2 && $(AR) x $(abspath $1))

define TARGET_RULES
.PHONY: $(1)
$(1): $$($(1)._OUTS)

$$(foreach s,$$($(1)._SRCS),$$(eval $$(call COMPILE_RULE,$(1),$$s,$$(call object-of,$(1),$$s),$$(if $$(filter %.c,$$s),c,cxx))))
-include $$(wildcard $$($(1)._OBJS:%$$(OBJ_EXT)=%.d))
BUILD_DIRS += $$(patsubst %/,%,$$(dir $$($(1)._OBJS) $$($(1)._OUTS) $$($(1)._IMPLIB))) $$($(1)._GENDIR)

ifneq ($$($(1)._ARCHIVE),)
$$($(1)._ARCHIVE): $$($(1)._OBJS) $$(foreach d,$$($(1)._MERGE_TARGETS),$$($$d._OBJS)) $$($(1)._MERGE_ARCHIVES) $$($(1)._LD_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._ARCHIVE)))
	$$(call print-to,Static library,$(1),$$@)
	$$(Q)$$(call remove-files,$$@)
	$$(foreach a,$$($(1)._MERGE_ARCHIVES),$$(call extract-archive,$$a,$$($(1)._OBJDIR)/merged/$$(basename $$(notdir $$a))))
	$$(Q)$$(call tc-archive,$(1))
endif

ifneq ($$($(1)._SHARED),)
$$($(1)._SHARED): $$($(1)._OBJS) $$($(1)._LINKDEPS) $$($(1)._LD_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._SHARED) $$($(1)._IMPLIB)))
	$$(call check-packages,$(1))
	$$(call print-to,Shared library,$(1),$$@)
	$$(Q)$$(call tc-link-shared,$(1))
	$$(if $$(tc-shared-post),$$(Q)$$(call tc-shared-post,$(1)))
ifneq ($$($(1)._IMPLIB),)
$$($(1)._IMPLIB): $$($(1)._SHARED) ;
endif
endif

ifneq ($$($(1)._PC),)
$$($(1)._PC): $$($(1)._LD_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._PC)))
	$$(call print-to,pkg-config,$(1),$$@)
	$$(file >$$@,$$(call PKG_CONFIG_BUILD,$(1)))
endif

ifneq ($$($(1)._EXE),)
$$($(1)._EXE): $$($(1)._OBJS) $$($(1)._LINKDEPS) $$($(1)._LD_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._EXE)))
	$$(call check-packages,$(1))
	$$(call print-to,Linking,$(1),$$@)
	$$(Q)$$(call tc-link-exe,$(1))

.PHONY: run-$(1)
run-$(1): $(1)
	$$(call print-simple,Running,$(1))
	$$(Q)$$(call run-target,$(1),$$(ARGS))
endif

ifneq ($$($(1)._BUNDLE),)
$$($(1)._GENDIR)/Info.plist: $$($(1)._LD_STAMP) | $$($(1)._GENDIR)
	$$(file >$$@,$$(call INFO_PLIST,$(1)))

$$($(1)._BUNDLE): $$($(1)._EXE) $$($(1)._GENDIR)/Info.plist $$($(1)._ICON)
	$$(call print-to,Bundle,$(1),$$@)
	$$(Q)$$(call remove-dir,$$@)
	$$(Q)mkdir -p $$@/Contents/MacOS $$@/Contents/Resources
	$$(Q)cp -f $$($(1)._EXE) $$@/Contents/MacOS/$$($(1).NAME)
	$$(Q)cp -f $$($(1)._GENDIR)/Info.plist $$@/Contents/Info.plist
	$$(if $$($(1)._ICON),$$(Q)cp -f $$($(1)._ICON) $$@/Contents/Resources/$$($(1).NAME).icns)
	$$(foreach d,$$($(1)._DATA),$$(call cmd,cp -R $$d/. $$@/Contents/Resources/))
endif

ifneq ($$($(1)._INFO),)
$$($(1)._INFO): $$($(1)._GENDIR)/info.txt | $$($(1)._GENDIR)
	$$(call print-to,Generating,$(1),$$@)
	$$(file >$$@,$$(call PROJECT_INFO_HPP,$(1)))
endif

.PHONY: clean-$(1)
clean-$(1):
	$$(call print-simple,Cleaning,$(1))
	$$(Q)$$(call remove-dir,$$($(1)._OBJDIR))
	$$(if $$($(1)._GENDIR),$$(Q)$$(call remove-dir,$$($(1)._GENDIR)))
	$$(if $$(strip $$($(1)._OUTS) $$($(1)._IMPLIB)),$$(Q)$$(call remove-files,$$(filter-out %.app,$$($(1)._OUTS)) $$($(1)._IMPLIB)))
	$$(if $$($(1)._BUNDLE),$$(Q)$$(call remove-dir,$$($(1)._BUNDLE)))
endef

# One command of a recipe built by a function: $(call cmd,mkdir -p foo)
cmd = $(Q)$1$(NEWLINE)

# Run an executable of the project, with the options of the sanitizers.
run-target = $(call with-env,$(TC_RUN_ENV),$(if $(filter test,$($1.TYPE)),$(TEST_RUNNER),$(RUNNER)) $(call run-path,$($1._EXE)) $($1.ARGS) $2)

$(foreach t,$(TARGETS),$(eval $(call TARGET_RULES,$t)))

# One rule per directory of the build, shared by all the targets.
$(foreach d,$(sort $(BUILD_DIRS)),$(eval $d: ; $$(Q)$$(call make-dir,$$@)))
