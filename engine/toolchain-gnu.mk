# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
#
# Compilers with a GCC-like command line: TOOLCHAIN=gcc, clang, mingw (also as
# a cross compiler from Linux) and emscripten.

# Set a tool unless the user gave it (command line or environment).
_mm_tool = $(if $(filter default undefined,$(origin $1)),$(eval $1 := $2))

ifeq ($(TOOLCHAIN),gcc)
    $(call _mm_tool,CC,gcc)
    $(call _mm_tool,CXX,g++)
    $(call _mm_tool,AR,ar)
    TARGET_OS ?= $(HOST_OS)
else ifeq ($(TOOLCHAIN),clang)
    $(call _mm_tool,CC,clang)
    $(call _mm_tool,CXX,clang++)
    $(call _mm_tool,AR,$(if $(filter Darwin,$(HOST_OS)),ar,llvm-ar))
    TARGET_OS ?= $(HOST_OS)
else ifeq ($(TOOLCHAIN),mingw)
    # From Linux: x86_64-w64-mingw32-g++. From MSYS2 the compiler is g++.
    MINGW_PREFIX ?= $(if $(filter Windows,$(HOST_OS)),,x86_64-w64-mingw32-)
    $(call _mm_tool,CC,$(MINGW_PREFIX)gcc)
    $(call _mm_tool,CXX,$(MINGW_PREFIX)g++)
    $(call _mm_tool,AR,$(MINGW_PREFIX)ar)
    # The pkg-config of the cross compiler, not the one of the host.
    PKG_CONFIG ?= $(MINGW_PREFIX)pkg-config
    TARGET_OS := Windows
else ifeq ($(TOOLCHAIN),emscripten)
    $(call _mm_tool,CC,emcc)
    $(call _mm_tool,CXX,em++)
    $(call _mm_tool,AR,emar)
    TARGET_OS := Emscripten
else
    $(call _mm_fail,unknown TOOLCHAIN '$(TOOLCHAIN)': gcc$(_mm_comma) clang$(_mm_comma) mingw$(_mm_comma) emscripten or msvc)
endif

# CPU of the binaries: x86_64, arm64, wasm...
ifeq ($(TOOLCHAIN),emscripten)
    TARGET_ARCH := wasm
else ifneq ($(MINGW_PREFIX),)
    TARGET_ARCH := $(firstword $(subst -, ,$(MINGW_PREFIX)))
else
    TARGET_ARCH := $(HOST_ARCH)
endif

###############################################################################
# Compiler identity, read with a single command (no pipe: also runs in cmd).
###############################################################################

ifneq ($(findstring clang,$(shell $(CXX) --version 2>$(_mm_devnull))),)
    COMPILER_FAMILY := clang
else
    COMPILER_FAMILY := gcc
endif
COMPILER_VERSION := $(firstword $(shell $(CXX) -dumpversion 2>$(_mm_devnull)))
COMPILER_MAJOR := $(call _mm_version_field,1,$(COMPILER_VERSION))
ifeq ($(TOOLCHAIN),emscripten)
    # -dumpversion gives the version of Emscripten, not of its clang.
    COMPILER_MAJOR := 18
endif

###############################################################################
# Command line syntax and file names
###############################################################################

TC_INC := -I
TC_SYSINC := -isystem$(_mm_space)
TC_DEF := -D
OBJ_EXT := .o
LIB_PREFIX := lib
STATIC_EXT := .a
EXE_EXT :=
SHARED_SUPPORTED := 1
PIC_FLAGS := -fPIC

ifeq ($(TARGET_OS),Windows)
    EXE_EXT := .exe
    SHARED_EXT := .dll
    PIC_FLAGS :=
else ifeq ($(TARGET_OS),Darwin)
    SHARED_EXT := .dylib
else ifeq ($(TARGET_OS),Emscripten)
    EXE_EXT := .html
    TEST_EXT := .js
    TEST_RUNNER ?= node
    RUNNER ?= emrun
    SHARED_SUPPORTED :=
    PIC_FLAGS :=
else
    SHARED_EXT := .so
endif
TEST_EXT ?= $(EXE_EXT)

_mm_tc_std = -std=$(patsubst -std=%,%,$(patsubst --std=%,%,$1))

###############################################################################
# Compilation modes
###############################################################################

ifeq ($(COMPILATION_MODE),debug)
    TC_MODE_FLAGS := -O0 -g3
    TC_MODE_DEFINES := _GLIBCXX_ASSERTIONS
else ifeq ($(COMPILATION_MODE),normal)
    TC_MODE_FLAGS := -O2 -g
    TC_MODE_DEFINES := _GLIBCXX_ASSERTIONS
else ifeq ($(COMPILATION_MODE),release)
    TC_MODE_FLAGS := -O3 -ffunction-sections -fdata-sections
    TC_MODE_DEFINES := NDEBUG
    ifneq ($(filter Linux Windows,$(TARGET_OS)),)
        TC_MODE_LDFLAGS := -Wl,--gc-sections
    endif
endif

ifdef COVERAGE
    TC_MODE_FLAGS += --coverage
    TC_MODE_LDFLAGS += --coverage
endif
ifdef SANITIZER
    TC_MODE_FLAGS += -fsanitize=$(SANITIZER) -fno-omit-frame-pointer
    TC_MODE_LDFLAGS += -fsanitize=$(SANITIZER)
endif

###############################################################################
# Warnings: WARNINGS := strict (default), default or none, set per target.
###############################################################################

_mm_warn_common := -Wall -Wextra -Wpedantic -Wshadow -Wconversion \
    -Wsign-conversion -Wcast-align -Wcast-qual -Wfloat-equal -Wpointer-arith \
    -Wswitch-enum -Wundef -Wuninitialized -Wunused -Wformat=2 \
    -Wformat-security -Wnull-dereference -Wdouble-promotion -Wvla

_mm_warn_cxx := -Wold-style-cast -Woverloaded-virtual -Wnon-virtual-dtor \
    -Wdelete-non-virtual-dtor

_mm_warn_c := -Wstrict-prototypes -Wmissing-prototypes -Wold-style-definition

ifeq ($(COMPILER_FAMILY),gcc)
    _mm_warn_common += -Wduplicated-cond -Wduplicated-branches -Wlogical-op
    _mm_warn_cxx += -Wuseless-cast -Wnoexcept -Wstrict-null-sentinel
    ifneq ($(call _mm_ge,$(COMPILER_MAJOR),10),)
        _mm_warn_cxx += -Wmismatched-tags -Wredundant-tags
    endif
else
    _mm_warn_common += -Wcomma -Wloop-analysis -Wshadow-all \
        -Wunreachable-code -Wno-unknown-warning-option
    _mm_warn_cxx += -Winconsistent-missing-override
endif

_mm_tc_warnings_cxx = $(if $(filter none,$1),-w,$(if $(filter default,$1),-Wall -Wextra,$(_mm_warn_common) $(_mm_warn_cxx)))
_mm_tc_warnings_c = $(if $(filter none,$1),-w,$(if $(filter default,$1),-Wall -Wextra,$(_mm_warn_common) $(_mm_warn_c)))

###############################################################################
# Recipes. $1 is the name of the MyMakefile target.
###############################################################################

_mm_tc_compile_cxx = $(CXX) $($1._CXXFLAGS) -MMD -MP -c $< -o $@
_mm_tc_compile_c = $(CC) $($1._CFLAGS) -MMD -MP -c $< -o $@
_mm_tc_archive = $(AR) crs $@ $($1._OBJS)
_mm_tc_link_exe = $($1._LINKER) -o $@ $($1._OBJS) $($1._LDFLAGS) $($1._LIBS)

ifeq ($(TARGET_OS),Windows)
    _mm_tc_shared_name = $(LIB_PREFIX)$1$(SHARED_EXT)
    _mm_tc_link_shared = $($1._LINKER) -shared -o $@ $($1._OBJS) \
        -Wl,--out-implib,$($1._IMPLIB) $($1._LDFLAGS) $($1._LIBS)
else ifeq ($(TARGET_OS),Darwin)
    _mm_tc_shared_name = $(LIB_PREFIX)$1$(SHARED_EXT)
    _mm_tc_link_shared = $($1._LINKER) -dynamiclib -o $@ $($1._OBJS) \
        -install_name @rpath/$(notdir $@) \
        -current_version $(PROJECT_VERSION) $($1._LDFLAGS) $($1._LIBS)
else
    # libfoo.so.1.2.3 with the soname libfoo.so.1, and the two usual links.
    _mm_tc_shared_name = $(LIB_PREFIX)$1$(SHARED_EXT).$(PROJECT_VERSION)
    _mm_tc_soname = $(LIB_PREFIX)$1$(SHARED_EXT).$(call _mm_version_field,1,$(PROJECT_VERSION))
    _mm_tc_link_shared = $($1._LINKER) -shared -o $@ $($1._OBJS) \
        -Wl,-soname,$(call _mm_tc_soname,$($1.NAME)) $($1._LDFLAGS) $($1._LIBS)
    _mm_tc_shared_post = cd $(@D) && ln -sf $(@F) $(call _mm_tc_soname,$($1.NAME)) && ln -sf $(@F) $(LIB_PREFIX)$($1.NAME)$(SHARED_EXT)
endif
