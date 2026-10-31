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

TARGET_TYPES := executable test static shared library objects header-only cmake
LIBRARY_TYPES := static shared library
COMPILED_TYPES := executable test static shared library objects
C_EXTS := %.c
CXX_EXTS := %.cc %.cpp %.cxx %.c++
ASM_EXTS := %.s %.S
SOURCE_EXTS := $(C_EXTS) $(CXX_EXTS) $(ASM_EXTS)
source-kind = $(if $(filter $(CXX_EXTS),$1),cxx,$(if $(filter $(ASM_EXTS),$1),asm,c))
SOURCE_KIND_NAME.cxx := C++
SOURCE_KIND_NAME.c := C
SOURCE_KIND_NAME.asm := assembly
HEADER_EXTS := %.h %.hh %.hpp %.hxx %.ipp %.tpp %.inl %.incl
BUILD_DIRS :=

#? What a target can define: anything else is reported as a typo.
TARGET_ATTRIBUTES := TYPE SOURCES INCLUDES PUBLIC_INCLUDES DEFINES \
    PUBLIC_DEFINES DEPENDS PKG_CONFIG CXXFLAGS CFLAGS LDFLAGS LIBS RPATH \
    WARNINGS NAME DESCRIPTION PROJECT_INFO DATA ARGS WORKDIR INSTALL CLEAN \
    PUBLIC_HEADERS PRIVATE_HEADERS MERGE BUNDLE ICON BUNDLE_ID EXT SYSTEM \
    ASFLAGS NODELETE POST_BUILD CMAKE_ARGS LIBRARIES URL SHA256 SUBDIR \
    GENERATED_SOURCES GENERATED_HEADERS \
    GIT VERSION COMMIT SUBMODULES MAKEFILES PATH DIR LOCKED LOCKED_REF

# The object file of a source: the tree of the sources is kept below the
# object directory, and never escapes from it. The sources of a third party
# are taken from its own directory.
object-stem = $(if $(call is-absolute,$1),_abs/$(subst :,,$(patsubst /%,%,$1)),$1)
object-of = $($1._OBJDIR)/$(basename $(call object-stem,$(if $(filter $1,$(EXTERNAL_TARGETS)),$(patsubst $($1.DIR)%,%,$2),$2)))$(OBJ_EXT)

# Sources given to a target but not found: a pattern matching nothing, or a
# file which does not exist.
missing-sources = $(foreach p,$1,$(if $(wildcard $(call glob,$p,$2)),,$p))

# Files made by a rule of the project, in GEN_DIR (an include directory of
# the targets using them) unless they are absolute:
#   app.GENERATED_HEADERS := shaders.hpp      # $(GEN_DIR)/shaders.hpp
#   $(GEN_DIR)/shaders.hpp: shaders/*.glsl ; ...
generated-path = $(call normalize,$(foreach p,$1,$(if $(call is-absolute,$p),$p,$(GEN_DIR)/$p)))

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

$(1)._GEN_SRCS := $$(filter $$(SOURCE_EXTS),$$(call generated-path,$$($(1).GENERATED_SOURCES),$$($(1).DIR)))
$(1)._GEN_HDRS := $$(call generated-path,$$($(1).GENERATED_HEADERS),$$($(1).DIR))
$(1)._SRCS := $$(filter $$(SOURCE_EXTS),$$(call glob,$$($(1).SOURCES),$$($(1).DIR))) $$($(1)._GEN_SRCS)
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

# project_info.hpp, included as "<name>/project_info.hpp" from the build
# (GEN_DIR is an include directory) and once installed.
ifneq ($$($(1).PROJECT_INFO),)
    $(1)._INFO := $$(GEN_DIR)/$$($(1).NAME)/project_info.hpp
    $(1)._INFO_STAMP := $$($(1)._OBJDIR)/info.txt
endif
$(1)._CC_STAMP := $$($(1)._OBJDIR)/compile-flags.txt
$(1)._LD_STAMP := $$($(1)._OBJDIR)/link-flags.txt
endef

$(foreach t,$(TARGETS),$(eval $(call RESOLVE_TARGET,$t)))

###############################################################################
# Pass 2: dependency graph. t._DEPS holds every target t depends on, directly
# or not, in link order: a library comes after the libraries using it.
###############################################################################

# Without building (clean, help...), the targets of the projects given by
# 't.MAKEFILES' are not read: a dependency on them is not an error then.
UNREAD_EMBEDDED := $(if $(BUILDING),,$(strip $(foreach t,$(TARGETS),$(if $($t.MAKEFILES),$t))))
closure = $(foreach d,$($1.DEPENDS),$(if $(filter $d,$2),$(call fail,dependency cycle: $2 $d))$(if $(filter $d,$(TARGETS))$(UNREAD_EMBEDDED),,$(call fail,'$(lastword $2)' depends on '$d' which is not in TARGETS))$(if $($d._IS_EXE),$(call fail,'$(lastword $2)' depends on the $($d.TYPE) '$d': only libraries can be linked))$d $(call closure,$d,$2 $d))

$(foreach t,$(TARGETS),$(eval $t._DEPS := $(call uniq-last,$(call closure,$t,$t))))

###############################################################################
# Third parties built by their CMake ('t.TYPE := cmake'): configured, built
# and installed in their own prefix; 't.LIBRARIES' names what to link (z for
# libz.a, or file names), 't.PUBLIC_INCLUDES' is relative to the prefix
# (include by default), 't.CMAKE_ARGS' are given to the configuration.
###############################################################################

CMAKE ?= cmake
CMAKE_TARGETS := $(strip $(foreach t,$(TARGETS),$(if $(filter cmake,$($t.TYPE)),$t)))
CMAKE_BUILD_TYPE.debug := Debug
CMAKE_BUILD_TYPE.normal := RelWithDebInfo
CMAKE_BUILD_TYPE.release := Release
CMAKE_BUILD_TYPE.release-with-debug := RelWithDebInfo
CMAKE_BUILD_TYPE.size := MinSizeRel
CMAKE_BUILD_TYPE.fast := Release

cmake-configure = $(if $(filter emscripten,$(TOOLCHAIN)),emcmake )$(CMAKE) --no-warn-unused-cli -S $($1.DIR) -B $($1._OBJDIR)/build \
    -DCMAKE_INSTALL_PREFIX=$(abspath $($1._PREFIX)) $(call cmake-options,$1)
cmake-options = -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE.$(COMPILATION_MODE)) -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_SHARED_LIBS=OFF \
    $(if $(filter emscripten,$(TOOLCHAIN)),,-DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX)) \
    $(if $(COMPILER_LAUNCHER),-DCMAKE_C_COMPILER_LAUNCHER=$(COMPILER_LAUNCHER) -DCMAKE_CXX_COMPILER_LAUNCHER=$(COMPILER_LAUNCHER)) \
    $(if $(and $(filter mingw,$(TOOLCHAIN)),$(MINGW_PREFIX)),-DCMAKE_SYSTEM_NAME=Windows) \
    $($1.CMAKE_ARGS)

# The build directory of a third party in the cache: the one whose
# compilation flags are the same.
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

define CMAKE_FLAGS
$(1)._IS_OWN :=
$(1)._CC_SIG := $$(strip cmake $$(COMPILER_FAMILY) $$(COMPILER_VERSION) $$(TARGET_ARCH) $$(TOOLCHAIN) | $$(call cmake-options,$(1)))
endef

define CMAKE_OUTPUTS
$(1)._PREFIX := $$($(1)._OBJDIR)/prefix
$(1)._PUB_INCS := $$(addprefix $$($(1)._PREFIX)/,$$(or $$($(1).PUBLIC_INCLUDES),include))
$(1)._CMAKE_DONE := $$($(1)._OBJDIR)/cmake-installed.txt
$(1)._LINKABLE := $$(foreach l,$$($(1).LIBRARIES),$$($(1)._PREFIX)/lib/$$(if $$(findstring .,$$l),$$l,$$(LIB_PREFIX)$$l$$(STATIC_EXT)))
$(1)._OUTS := $$($(1)._CMAKE_DONE)
endef

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

# A macro holding parentheses is quoted for the shell: "-DAPI=__declspec(dllexport)",
# a string keeps its quotes: '-DDATA="/usr/share/foo/"' (cmd: "-DDATA=\"...\"").
quote-string-define = $(if $(filter cmd,$(HOST_SHELL)),"$(subst ",\",$1)",'$1')
define-flags = $(foreach d,$1,$(if $(findstring ",$d),$(call quote-string-define,$(TC_DEF)$d),$(if $(findstring $(OPEN_PAREN),$d),"$(TC_DEF)$d",$(TC_DEF)$d)))

#? Macro of MyMakefile 2 for the symbols exported by a DLL: __declspec(dllexport)
#? while building a library for Windows, empty otherwise. EXPORT_MACRO= to
#? do without.
EXPORT_MACRO ?= API_LINKAGE
export-define = $(if $(and $(EXPORT_MACRO),$($1._IS_OWN)),$(EXPORT_MACRO)=$(if $(and $($1._SHARED),$(filter Windows,$(TARGET_OS))),__declspec(dllexport)))

define COMPILE_FLAGS
$(1)._IS_OWN := $$(if $$(filter $(1),$$(EXTERNAL_TARGETS)),,1)
# The project_info.hpp of the target and of the libraries it uses.
$(1)._INFO_ORDER := $$(strip $$($(1)._INFO) $$(foreach d,$$($(1)._DEPS),$$($$d._INFO)))
# Generated headers of the target and of its libraries: made before compiling.
$(1)._GEN_ORDER := $$(strip $$($(1)._GEN_HDRS) $$(foreach d,$$($(1)._DEPS),$$($$d._GEN_HDRS)))
$(1)._PKGS := $$(call uniq,$$($(1).PKG_CONFIG) $$(foreach d,$$($(1)._DEPS),$$($$d.PKG_CONFIG)))
$(1)._PKG_MISSING := $$(strip $$(call pkg-missing,$$($(1)._PKGS)))
$(1)._CPPFLAGS := $$(TC_UNDEFINES) \
    $$(call define-flags,$$(TC_MODE_DEFINES) $$(call export-define,$(1)) $$($(1).DEFINES) $$($(1).PUBLIC_DEFINES) \
        $$(foreach d,$$($(1)._DEPS),$$($$d.PUBLIC_DEFINES))) \
    $$(addprefix $$(TC_INC),$$($(1)._PRIV_INCS) $$($(1)._PUB_INCS) $$(if $$($(1)._INFO_ORDER)$$($(1)._GEN_ORDER),$$(GEN_DIR))) \
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
$(1)._ASFLAGS := $$(strip $$(TC_MODE_FLAGS) $$($(1)._TYPE_FLAGS) $$($(1)._CPPFLAGS) \
    $$($(1).ASFLAGS) $$(ASFLAGS))
# The compiler is part of it: a new compiler rebuilds everything.
$(1)._CC_SIG := $$(strip $$(COMPILER_FAMILY) $$(COMPILER_VERSION) $$(TARGET_ARCH) | $$($(1)._CXXFLAGS) | $$($(1)._CFLAGS) | $$($(1)._ASFLAGS))
endef

# A CMake target is configured with its own flags only: the targets using it
# need the place of its headers, known once its build directory is.
$(foreach t,$(CMAKE_TARGETS),$(eval $(call CMAKE_FLAGS,$t)))
ifneq ($(and $(EXTERNAL_CACHE),$(BUILDING)),)
    $(foreach t,$(filter $(FETCHED_TARGETS),$(CMAKE_TARGETS)),$(eval $(call CACHED_BUILD,$t)))
endif
$(foreach t,$(CMAKE_TARGETS),$(eval $(call CMAKE_OUTPUTS,$t)))
$(foreach t,$(filter-out $(CMAKE_TARGETS),$(TARGETS)),$(eval $(call COMPILE_FLAGS,$t)))

###############################################################################
# Pass 4: a third party is compiled once per configuration in the cache (see
# CACHED_BUILD); the CMake ones got their directory before pass 3.
###############################################################################


ifneq ($(and $(EXTERNAL_CACHE),$(BUILDING)),)
    $(foreach t,$(filter-out $(CMAKE_TARGETS),$(FETCHED_TARGETS)),$(if $($t._SRCS),$(eval $(call CACHED_BUILD,$t))))
endif

# What a target builds, and what the targets depending on it link with: the
# static library first, the objects themselves for an 'objects' target.
$(foreach t,$(filter-out $(CMAKE_TARGETS),$(TARGETS)),$(eval $t._OUTS := $(strip $($t._ARCHIVE) $($t._SHARED) $($t._EXE) $($t._BUNDLE) $($t._PC))))
# A target without sources may give libraries built elsewhere: LIBRARIES,
# relative to its directory (the binaries of an archive).
$(foreach t,$(filter-out $(CMAKE_TARGETS),$(TARGETS)),$(eval $t._LINKABLE := $(if $(filter objects,$($t.TYPE)),$($t._OBJS),$(if $(filter header-only,$($t.TYPE)),$(call resolve,$($t.LIBRARIES),$($t.DIR)),$(or $($t._ARCHIVE),$($t._IMPLIB),$($t._SHARED))))))

###############################################################################
# Pass 5: link flags. 't.MERGE := imgui path/libfoo.a' puts the objects of
# these static libraries in the static library of t (the targets depending on
# t then do not link them again). A target without objects of its own (cmake,
# prebuilt LIBRARIES) gives its static libraries.
###############################################################################

define LINK_FLAGS
$(1)._MERGED := $$(filter $$(TARGETS),$$($(1).MERGE))
$(1)._MERGE_TARGETS := $$(foreach d,$$($(1)._MERGED),$$(if $$($$d._OBJS),$$d))
$(1)._MERGE_ARCHIVES := $$(call resolve,$$(filter-out $$(TARGETS),$$($(1).MERGE)),$$($(1).DIR)) \
    $$(foreach d,$$($(1)._MERGED),$$(if $$($$d._OBJS),,$$(filter %$$(STATIC_EXT),$$($$d._LINKABLE))))
$(1)._MERGE_DIRS := $$(foreach a,$$($(1)._MERGE_ARCHIVES),$$($(1)._OBJDIR)/merged/$$(basename $$(notdir $$a)))
$(1)._ARCHIVE_OBJS := $$($(1)._OBJS) $$(foreach d,$$($(1)._MERGE_TARGETS),$$($$d._OBJS)) $$(addsuffix /*$$(OBJ_EXT),$$($(1)._MERGE_DIRS))
$(1)._LINK_OBJS := $$($(1)._OBJS)
$(1)._MERGED_BY_DEPS := $$(foreach d,$$($(1)._DEPS),$$($$d._MERGED))
$(1)._LINKDEPS := $$(foreach d,$$(filter-out $$($(1)._MERGED_BY_DEPS),$$($(1)._DEPS)),$$($$d._LINKABLE))
$(1)._LINKER := $$(if $$(filter $$(CXX_EXTS),$$($(1)._SRCS) $$(foreach d,$$($(1)._DEPS),$$($$d._SRCS)))$$(filter $$(CMAKE_TARGETS),$$($(1)._DEPS)),$$(CXX),$$(CC))
$(1)._SHARED_DEPS := $$(foreach d,$$($(1)._DEPS),$$(foreach l,$$($$d._LINKABLE),$$(if $$(findstring $$(SHARED_EXT),$$(notdir $$l)),$$l)))
# The folders of the shared libraries it links: of the project, and of the
# pkg-config packages (an installed library named @rpath/libfoo.dylib on
# macOS is found only so).
$(1)._RPATHS := $$(if $$(filter Windows Emscripten,$$(TARGET_OS)),,$$(call uniq,$$(abspath $$(sort $$(dir $$($(1)._SHARED_DEPS)))) \
    $$(patsubst -L%,%,$$(filter -L%,$$(call pkg-libs,$$($(1)._PKGS)))) $$(subst :, ,$$(RPATH) $$($(1).RPATH))))
$(1)._LDFLAGS := $$(strip $$(TC_MODE_LDFLAGS) \
    $$(if $$($(1)._IS_EXE),$$(TC_EXE_LDFLAGS)) \
    $$(if $$($(1)._IS_EXE)$$($(1)._SHARED),$$(TC_HARDEN_LDFLAGS) $$(TC_STRIP_LDFLAGS)) \
    $$(if $$(and $$($(1).NODELETE),$$($(1)._SHARED),$$(IS_ELF)),-Wl$$(COMMA)-z$$(COMMA)nodelete) \
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

# $1: target, $2: source, $3: object, $4: cxx, c or asm. Before compiling:
# PRE_BUILD, and the third parties built by CMake whose headers are needed.
define COMPILE_RULE
$(3): $(2) $$($(1)._CC_STAMP) | $(patsubst %/,%,$(dir $(3))) $$($(1)._INFO_ORDER) $$($(1)._GEN_ORDER) pre-build $$(foreach d,$$($(1)._DEPS),$$($$d._CMAKE_DONE))
	$$(call check-packages,$(1))
	$$(call print-from,Compiling $$(SOURCE_KIND_NAME.$(4)),$(1),$$<)
	$$(Q)$$(call tc-compile-$(4),$(1))
endef

#? Commands run before compiling anything, and after building 'all'. Each
#? target can also have its own 't.POST_BUILD', run after it is linked.
PRE_BUILD ?=
POST_BUILD ?=
.PHONY: pre-build
pre-build:
	$(PRE_BUILD)
	@$(NOOP)

# Objects of the static libraries given to 't.MERGE'.
extract-archive = $(call cmd,$(call remove-dir,$2))$(call cmd,$(call make-dir,$2))$(call cmd,cd $2 && $(AR) x $(abspath $1))

define TARGET_RULES
.PHONY: $(1)
$(1): $$($(1)._OUTS)

$$(foreach s,$$($(1)._SRCS),$$(eval $$(call COMPILE_RULE,$(1),$$s,$$(call object-of,$(1),$$s),$$(call source-kind,$$s))))
-include $$(wildcard $$($(1)._OBJS:%$$(OBJ_EXT)=%.d))
BUILD_DIRS += $$(patsubst %/,%,$$(dir $$($(1)._OBJS) $$($(1)._OUTS) $$($(1)._IMPLIB) $$($(1)._INFO))) $$(if $$($(1)._BUNDLE),$$($(1)._OBJDIR))

ifneq ($$($(1)._ARCHIVE),)
$$($(1)._ARCHIVE): $$($(1)._OBJS) $$(foreach d,$$($(1)._MERGE_TARGETS),$$($$d._OBJS)) $$(foreach d,$$($(1)._MERGED),$$(if $$($$d._OBJS),,$$($$d._OUTS))) $$($(1)._MERGE_ARCHIVES) $$($(1)._LD_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._ARCHIVE)))
	$$(call print-to,Static library,$(1),$$@)
	$$(Q)$$(call remove-files,$$@)
	$$(foreach a,$$($(1)._MERGE_ARCHIVES),$$(call extract-archive,$$a,$$($(1)._OBJDIR)/merged/$$(basename $$(notdir $$a))))
	$$(Q)$$(call tc-archive,$(1))
	$$(if $$($(1)._SHARED)$$($(1)._EXE),,$$($(1).POST_BUILD))
endif

ifneq ($$($(1)._SHARED),)
$$($(1)._SHARED): $$($(1)._OBJS) $$($(1)._LINKDEPS) $$($(1)._LD_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._SHARED) $$($(1)._IMPLIB)))
	$$(call check-packages,$(1))
	$$(call print-to,Shared library,$(1),$$@)
	$$(Q)$$(call tc-link-shared,$(1))
	$$(if $$(tc-shared-post),$$(Q)$$(call tc-shared-post,$(1)))
	$$($(1).POST_BUILD)
ifneq ($$($(1)._IMPLIB),)
$$($(1)._IMPLIB): $$($(1)._SHARED) ;
endif
endif

ifneq ($$($(1)._PC),)
$$($(1)._PC): $$($(1)._CC_STAMP) $$($(1)._LD_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._PC)))
	$$(call print-to,pkg-config,$(1),$$@)
	$$(file >$$@,$$(call PKG_CONFIG_BUILD,$(1)))
endif

ifneq ($$($(1)._EXE),)
$$($(1)._EXE): $$($(1)._OBJS) $$($(1)._LINKDEPS) $$($(1)._LD_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._EXE)))
	$$(call check-packages,$(1))
	$$(call print-to,Linking,$(1),$$@)
	$$(Q)$$(call tc-link-exe,$(1))
	$$($(1).POST_BUILD)

.PHONY: run-$(1) gdb-$(1)
run-$(1): $(1)
	$$(call print-simple,Running,$(1))
	$$(Q)$$(call run-target,$(1),$$(ARGS))

gdb-$(1): $(1)
	$$(Q)$$(GDB) --args $$(call run-path,$$($(1)._EXE)) $$($(1).ARGS) $$(ARGS)
endif

ifneq ($$($(1)._CMAKE_DONE),)
$$($(1)._CMAKE_DONE): $$($(1)._CC_STAMP)
	$$(call print-to,Building with CMake,$(1),$$($(1)._PREFIX))
	$$(Q)$$(call cmake-configure,$(1)) $$(if $$(Q),>$$(DEVNULL))
	+$$(Q)$$(CMAKE) --build $$($(1)._OBJDIR)/build $$(if $$(Q),>$$(DEVNULL))
	$$(Q)$$(CMAKE) --install $$($(1)._OBJDIR)/build $$(if $$(Q),>$$(DEVNULL))
	$$(Q)$$(call touch-file,$$@)

$$($(1)._LINKABLE): $$($(1)._CMAKE_DONE) ;
endif

ifneq ($$($(1)._BUNDLE),)
$$($(1)._OBJDIR)/Info.plist: $$($(1)._LD_STAMP) | $$($(1)._OBJDIR)
	$$(file >$$@,$$(call INFO_PLIST,$(1)))

$$($(1)._BUNDLE): $$($(1)._EXE) $$($(1)._OBJDIR)/Info.plist $$($(1)._ICON)
	$$(call print-to,Bundle,$(1),$$@)
	$$(Q)$$(call remove-dir,$$@)
	$$(Q)mkdir -p $$@/Contents/MacOS $$@/Contents/Resources
	$$(Q)cp -f $$($(1)._EXE) $$@/Contents/MacOS/$$($(1).NAME)
	$$(Q)cp -f $$($(1)._OBJDIR)/Info.plist $$@/Contents/Info.plist
	$$(if $$($(1)._ICON),$$(Q)cp -f $$($(1)._ICON) $$@/Contents/Resources/$$($(1).NAME).icns)
	$$(foreach d,$$($(1)._DATA),$$(call cmd,cp -R $$d/. $$@/Contents/Resources/))
endif

ifneq ($$($(1)._INFO),)
$$($(1)._INFO): $$($(1)._INFO_STAMP) | $$(patsubst %/,%,$$(dir $$($(1)._INFO)))
	$$(call print-to,Generating,$(1),$$@)
	$$(file >$$@,$$(call PROJECT_INFO_HPP,$(1)))
endif

.PHONY: clean-$(1)
clean-$(1):
	$$(call print-simple,Cleaning,$(1))
	$$(Q)$$(call remove-dir,$$($(1)._OBJDIR))
	$$(if $$($(1)._INFO),$$(Q)$$(call remove-files,$$($(1)._INFO)))
	$$(if $$(strip $$($(1)._OUTS) $$($(1)._IMPLIB)),$$(Q)$$(call remove-files,$$(filter-out %.app,$$($(1)._OUTS)) $$($(1)._IMPLIB)))
	$$(if $$($(1)._BUNDLE),$$(Q)$$(call remove-dir,$$($(1)._BUNDLE)))
endef

# One command of a recipe built by a function: $(call cmd,mkdir -p foo)
cmd = $(Q)$1$(NEWLINE)

# Run an executable of the project, with the options of the sanitizers.
# 't.WORKDIR': the directory it runs in, relative to the one of the target
# (the root of the project by default).
run-target = $(if $($1.WORKDIR),cd $(call run-path,$(call resolve,$($1.WORKDIR),$($1.DIR))) && )$(call with-env,$(TC_RUN_ENV),$(if $(filter test,$($1.TYPE)),$(TEST_RUNNER),$(RUNNER)) $(call run-path,$(if $($1.WORKDIR),$(abspath $($1._EXE)),$($1._EXE))) $($1.ARGS) $2)

$(foreach t,$(TARGETS),$(eval $(call TARGET_RULES,$t)))

# One rule per directory of the build, shared by all the targets.
$(foreach d,$(sort $(BUILD_DIRS)),$(eval $d: ; $$(Q)$$(call make-dir,$$@)))
