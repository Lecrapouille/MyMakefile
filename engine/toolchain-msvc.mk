# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
#
# EXPERIMENTAL: Microsoft Visual C++ (TOOLCHAIN=msvc), or clang-cl with
# CXX=clang-cl CC=clang-cl. GNU Make has to run from a "Developer Command
# Prompt" so that cl.exe, lib.exe and link.exe are in the PATH.
#
# Not supported yet: tracking of included headers (cl.exe cannot write a
# Makefile dependency file; a modified header needs 'make clean'), pkg-config,
# DLLs (a DLL exports nothing without __declspec(dllexport) in the code, so a
# 'library' target only builds its static library).

_mm_tool = $(if $(filter default undefined,$(origin $1)),$(eval $1 := $2))
$(call _mm_tool,CC,cl)
$(call _mm_tool,CXX,cl)
$(call _mm_tool,AR,lib)
LINK_EXE ?= link
TARGET_OS := Windows
TARGET_ARCH := $(HOST_ARCH)
COMPILER_FAMILY := msvc
COMPILER_MAJOR :=

TC_INC := /I
TC_SYSINC := /external:I
TC_DEF := /D
OBJ_EXT := .obj
LIB_PREFIX :=
STATIC_EXT := .lib
SHARED_EXT := .dll
EXE_EXT := .exe
TEST_EXT := .exe
SHARED_SUPPORTED :=
PIC_FLAGS :=

_mm_tc_std = /std:$(patsubst -std=%,%,$(patsubst --std=%,%,$1))

ifeq ($(COMPILATION_MODE),debug)
    TC_MODE_FLAGS := /Od /Zi /MDd /FS
    TC_MODE_LDFLAGS := /DEBUG
else ifeq ($(COMPILATION_MODE),normal)
    TC_MODE_FLAGS := /O2 /Zi /MD /FS
    TC_MODE_LDFLAGS := /DEBUG
else ifeq ($(COMPILATION_MODE),release)
    TC_MODE_FLAGS := /O2 /MD /Gy
    TC_MODE_DEFINES := NDEBUG
    TC_MODE_LDFLAGS := /OPT:REF /OPT:ICF
endif

_mm_tc_warnings_cxx = $(if $(filter none,$1),/W0,$(if $(filter default,$1),/W3,/W4 /permissive-)) /external:W0
_mm_tc_warnings_c = $(_mm_tc_warnings_cxx)

_mm_tc_compile_cxx = $(CXX) /nologo /EHsc $($1._CXXFLAGS) /c $< /Fo$@
_mm_tc_compile_c = $(CC) /nologo $($1._CFLAGS) /c $< /Fo$@
_mm_tc_archive = $(AR) /nologo /OUT:$@ $($1._OBJS)
_mm_tc_link_exe = $(LINK_EXE) /nologo /OUT:$@ $($1._OBJS) $($1._LDFLAGS) $($1._LIBS)
_mm_tc_shared_name = $1$(SHARED_EXT)
_mm_tc_link_shared = $(LINK_EXE) /nologo /DLL /OUT:$@ /IMPLIB:$($1._IMPLIB) \
    $($1._OBJS) $($1._LDFLAGS) $($1._LIBS)
