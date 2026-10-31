###############################################################################
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
###############################################################################
#
# EXPERIMENTAL: Microsoft Visual C++ (TOOLCHAIN=msvc), or clang-cl with
# CXX=clang-cl CC=clang-cl. GNU Make has to run from a "Developer Command
# Prompt" so that cl.exe, lib.exe and link.exe are in the PATH.
#
# Not supported yet: tracking of included headers (cl.exe cannot write a
# Makefile dependency file; a modified header needs 'make clean'), pkg-config,
# DLLs (a DLL exports nothing without __declspec(dllexport) in the code, so a
# 'library' target only builds its static library).

set-tool = $(if $(filter default undefined,$(origin $1)),$(eval $1 := $2))
$(call set-tool,CC,cl)
$(call set-tool,CXX,cl)
$(call set-tool,AR,lib)
LINK_EXE ?= link
TARGET_OS := Windows
TARGET_ARCH := $(HOST_ARCH)
COMPILER_FAMILY := msvc
COMPILER_MAJOR :=
COMPILER_LAUNCHER :=

TC_INC := /I
TC_SYSINC := /external:I
TC_DEF := /D
TC_WERROR := /WX
OBJ_EXT := .obj
LIB_PREFIX :=
STATIC_EXT := .lib
SHARED_EXT := .dll
EXE_EXT := .exe
TEST_EXT := .exe
SHARED_SUPPORTED :=
PIC_FLAGS :=

tc-std = /std:$(patsubst -std=%,%,$(patsubst --std=%,%,$1))

OPTIMIZED_MODES := release release-with-debug size fast
TC_MODE_FLAGS := /nologo /utf-8 /Zc:__cplusplus
ifeq ($(COMPILATION_MODE),debug)
    TC_MODE_FLAGS += /Od /Zi /MDd /FS /RTC1
    TC_MODE_LDFLAGS := /DEBUG
else ifeq ($(COMPILATION_MODE),normal)
    TC_MODE_FLAGS += /O2 /Zi /MD /FS
    TC_MODE_LDFLAGS := /DEBUG
else ifeq ($(COMPILATION_MODE),release-with-debug)
    TC_MODE_FLAGS += /O2 /Zi /MD /FS /Gy
    TC_MODE_LDFLAGS := /DEBUG /OPT:REF /OPT:ICF
else ifeq ($(COMPILATION_MODE),size)
    TC_MODE_FLAGS += /O1 /MD /Gy
    TC_MODE_LDFLAGS := /OPT:REF /OPT:ICF
else
    TC_MODE_FLAGS += /O2 /MD /Gy $(if $(filter fast,$(COMPILATION_MODE)),/fp:fast)
    TC_MODE_LDFLAGS := /OPT:REF /OPT:ICF
endif
ifneq ($(filter $(COMPILATION_MODE),$(OPTIMIZED_MODES)),)
    TC_MODE_DEFINES := NDEBUG
endif

HARDENING ?= 1
ifneq ($(filter 1 yes,$(HARDENING)),)
    TC_MODE_FLAGS += /sdl /guard:cf
    TC_MODE_LDFLAGS += /GUARD:CF /DYNAMICBASE /NXCOMPAT
endif
ifneq ($(filter address,$(subst $(COMMA), ,$(SANITIZER))),)
    TC_MODE_FLAGS += /fsanitize=address
endif

tc-warnings-cxx = $(if $(filter none,$1),/W0,$(if $(filter default,$1),/W3,/W4 /permissive- $(if $(filter paranoid,$1),/Wall))) /external:W0
tc-warnings-c = $(tc-warnings-cxx)

tc-compile-cxx = $(CXX) /EHsc $($1._CXXFLAGS) /c $< /Fo$@
tc-compile-c = $(CC) $($1._CFLAGS) /c $< /Fo$@
tc-compile-asm = $(call fail,assembly sources are not supported with MSVC)
GDB ?= devenv /debugexe
tc-archive = $(AR) /nologo /OUT:$@ $($1._ARCHIVE_OBJS)
tc-link-exe = $(LINK_EXE) /nologo /OUT:$@ $($1._LINK_OBJS) $($1._LDFLAGS) $($1._LIBS)
tc-shared-name = $1$(SHARED_EXT)
tc-link-shared = $(LINK_EXE) /nologo /DLL /OUT:$@ /IMPLIB:$($1._IMPLIB) \
    $($1._LINK_OBJS) $($1._LDFLAGS) $($1._LIBS)
