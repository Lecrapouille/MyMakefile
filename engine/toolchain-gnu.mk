###############################################################################
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
###############################################################################
#
# Compilers with a GCC-like command line: TOOLCHAIN=gcc, clang, mingw (also as
# a cross compiler from Linux) and emscripten.

# Set a tool unless the user gave it (command line or environment).
set-tool = $(if $(filter default undefined,$(origin $1)),$(eval $1 := $2))

ifeq ($(TOOLCHAIN),gcc)
    $(call set-tool,CC,gcc)
    $(call set-tool,CXX,g++)
    $(call set-tool,AR,ar)
    TARGET_OS ?= $(HOST_OS)
else ifeq ($(TOOLCHAIN),clang)
    $(call set-tool,CC,clang)
    $(call set-tool,CXX,clang++)
    # The archiver of LLVM understands the objects of the LTO.
    $(call set-tool,AR,$(if $(filter Darwin,$(HOST_OS)),ar,$(if $(call which,llvm-ar),llvm-ar,ar)))
    TARGET_OS ?= $(HOST_OS)
else ifeq ($(TOOLCHAIN),mingw)
    # From Linux: x86_64-w64-mingw32-g++. From MSYS2 the compiler is g++.
    MINGW_PREFIX ?= $(if $(filter Windows,$(HOST_OS)),,x86_64-w64-mingw32-)
    $(call set-tool,CC,$(MINGW_PREFIX)gcc)
    $(call set-tool,CXX,$(MINGW_PREFIX)g++)
    $(call set-tool,AR,$(MINGW_PREFIX)ar)
    # The pkg-config of the cross compiler, not the one of the host.
    PKG_CONFIG ?= $(MINGW_PREFIX)pkg-config
    TARGET_OS := Windows
else ifeq ($(TOOLCHAIN),emscripten)
    $(call set-tool,CC,emcc)
    $(call set-tool,CXX,em++)
    $(call set-tool,AR,emar)
    TARGET_OS := Emscripten
else
    $(call fail,unknown TOOLCHAIN '$(TOOLCHAIN)': gcc$(COMMA) clang$(COMMA) mingw$(COMMA) emscripten or msvc)
endif

# CPU of the binaries: x86_64, arm64, wasm...
ifeq ($(TOOLCHAIN),emscripten)
    TARGET_ARCH := wasm
else ifneq ($(MINGW_PREFIX),)
    TARGET_ARCH := $(firstword $(subst -, ,$(MINGW_PREFIX)))
else
    TARGET_ARCH := $(HOST_ARCH)
endif
IS_X86_64 := $(filter x86_64 amd64 AMD64,$(TARGET_ARCH))

###############################################################################
# Compiler identity, read with a single command (no pipe: also runs in cmd).
###############################################################################

ifneq ($(findstring clang,$(shell $(CXX) --version 2>$(DEVNULL))),)
    COMPILER_FAMILY := clang
else
    COMPILER_FAMILY := gcc
endif
COMPILER_VERSION := $(firstword $(shell $(CXX) -dumpversion 2>$(DEVNULL)))
COMPILER_MAJOR := $(call version-field,1,$(COMPILER_VERSION))
ifeq ($(TOOLCHAIN),emscripten)
    # -dumpversion gives the version of Emscripten, not of its clang.
    COMPILER_MAJOR := 18
endif
gcc-ge = $(and $(filter gcc,$(COMPILER_FAMILY)),$(call ge,$(COMPILER_MAJOR),$1))
clang-ge = $(and $(filter clang,$(COMPILER_FAMILY)),$(call ge,$(COMPILER_MAJOR),$1))

###############################################################################
# ccache, when it is installed (CCACHE=0 to do without, CCACHE=path to give
# it). Not for Emscripten, whose compilers are scripts.
###############################################################################

ifneq ($(filter 0 no off,$(CCACHE)),)
    COMPILER_LAUNCHER :=
else ifneq ($(filter-out auto,$(CCACHE)),)
    COMPILER_LAUNCHER := $(CCACHE)
else ifneq ($(TOOLCHAIN),emscripten)
    COMPILER_LAUNCHER := $(call which,ccache)
endif
ifneq ($(COMPILER_LAUNCHER),)
    # Paths below the project are hashed relatively: two clones of a project
    # share their cache.
    export CCACHE_BASEDIR ?= $(CURDIR)
endif

###############################################################################
# Command line syntax and file names
###############################################################################

TC_INC := -I
TC_SYSINC := -isystem$(SPACE)
TC_DEF := -D
TC_WERROR := -Werror
GDB ?= $(if $(filter Darwin,$(HOST_OS)),lldb,gdb)
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
IS_ELF := $(filter-out Windows Darwin Emscripten,$(TARGET_OS))

tc-std = -std=$(patsubst -std=%,%,$(patsubst --std=%,%,$1))

###############################################################################
# Compilation modes: TC_MODE_FLAGS for compiling, TC_MODE_LDFLAGS for linking.
###############################################################################

OPTIMIZED_MODES := release release-with-debug size fast
TC_MODE_FLAGS := -pipe
TC_MODE_LDFLAGS :=

ifeq ($(COMPILATION_MODE),debug)
    TC_MODE_FLAGS += -O0 -g3 -fno-omit-frame-pointer
    ifeq ($(COMPILER_FAMILY),gcc)
        TC_MODE_FLAGS += -fasynchronous-unwind-tables -fvar-tracking-assignments
    endif
    TC_MODE_DEFINES := _GLIBCXX_ASSERTIONS
else ifeq ($(COMPILATION_MODE),normal)
    TC_MODE_FLAGS += -O2 -g
    TC_MODE_DEFINES := _GLIBCXX_ASSERTIONS
else ifeq ($(COMPILATION_MODE),release)
    TC_MODE_FLAGS += -O3 -fomit-frame-pointer -funroll-loops
else ifeq ($(COMPILATION_MODE),release-with-debug)
    TC_MODE_FLAGS += -O2 -g -funroll-loops
else ifeq ($(COMPILATION_MODE),size)
    TC_MODE_FLAGS += -Os -fmerge-all-constants
else ifeq ($(COMPILATION_MODE),fast)
    # -Ofast is deprecated by clang: the same, spelled out.
    TC_MODE_FLAGS += -O3 -ffast-math -fomit-frame-pointer -funroll-loops
    NATIVE ?= 1
endif

# Optimized modes: no assert(), unused functions and data removed at link.
ifneq ($(filter $(COMPILATION_MODE),$(OPTIMIZED_MODES)),)
    TC_MODE_DEFINES := NDEBUG
    ifneq ($(TOOLCHAIN),emscripten)
        TC_MODE_FLAGS += -ffunction-sections -fdata-sections
        TC_MODE_LDFLAGS += $(if $(filter Darwin,$(TARGET_OS)),-Wl$(COMMA)-dead_strip,-Wl$(COMMA)--gc-sections)
    endif
endif

# Options of MyMakefile 2: NATIVE=1, FAST_MATH=1, VECTORIZE_REPORT=1.
ifneq ($(and $(filter 1 yes,$(NATIVE)),$(filter-out emscripten mingw,$(TOOLCHAIN))),)
    TC_MODE_FLAGS += -march=native -mtune=native
endif
ifneq ($(filter 1 yes,$(FAST_MATH)),)
    TC_MODE_FLAGS += -ffast-math
endif
ifneq ($(filter 1 yes,$(VECTORIZE_REPORT)),)
    TC_MODE_FLAGS += $(if $(filter gcc,$(COMPILER_FAMILY)),-fopt-info-vec-optimized,-Rpass=loop-vectorize)
endif

# Coverage: exact line counts need no optimization.
ifneq ($(COVERAGE),)
    TC_MODE_FLAGS := $(filter-out -O% -g% -fomit-frame-pointer -funroll-loops,$(TC_MODE_FLAGS)) -O0 -g --coverage
    TC_MODE_FLAGS += $(if $(call gcc-ge,7),-fprofile-update=atomic)
    TC_MODE_LDFLAGS += --coverage
endif

# Profiling with gprof: GPROF=1.
ifneq ($(filter 1 yes,$(GPROF)),)
    TC_MODE_FLAGS += -pg
    TC_MODE_LDFLAGS += -pg
endif

# Profile guided optimization: PGO=generate, run the program, then PGO=use.
ifeq ($(PGO),generate)
    TC_MODE_FLAGS += -fprofile-generate
    TC_MODE_LDFLAGS += -fprofile-generate
else ifeq ($(PGO),use)
    TC_MODE_FLAGS += -fprofile-use $(if $(filter gcc,$(COMPILER_FAMILY)),-fprofile-correction,-Wno-profile-instr-unprofiled)
    TC_MODE_LDFLAGS += -fprofile-use
endif

# Valgrind: VALGRIND=1 keeps the frames and the calls valgrind shows.
ifneq ($(filter 1 yes,$(VALGRIND)),)
    TC_MODE_FLAGS += -fno-omit-frame-pointer $(if $(filter gcc,$(COMPILER_FAMILY)),-fno-inline-functions-called-once)
    TC_MODE_DEFINES += VALGRIND_FRIENDLY
endif

###############################################################################
# Sanitizers: SANITIZER=address, or a list: SANITIZER=address,undefined
###############################################################################

SANITIZERS := $(subst $(COMMA), ,$(SANITIZER))
KNOWN_SANITIZERS := address undefined thread memory leak hwaddress cfi safe-stack
CLANG_SANITIZERS := memory cfi safe-stack hwaddress

ifneq ($(SANITIZERS),)
    ifneq ($(filter-out $(KNOWN_SANITIZERS),$(SANITIZERS)),)
        $(call fail,unknown SANITIZER '$(filter-out $(KNOWN_SANITIZERS),$(SANITIZERS))': $(KNOWN_SANITIZERS))
    endif
    ifneq ($(word 2,$(filter address thread memory hwaddress,$(SANITIZERS))),)
        $(call fail,the sanitizers '$(filter address thread memory hwaddress,$(SANITIZERS))' cannot be used together)
    endif
    ifneq ($(and $(filter $(CLANG_SANITIZERS),$(SANITIZERS)),$(filter-out clang,$(COMPILER_FAMILY))),)
        $(call fail,the sanitizers '$(filter $(CLANG_SANITIZERS),$(SANITIZERS))' need clang: TOOLCHAIN=clang)
    endif
    TC_SANITIZE := -fsanitize=$(subst $(SPACE),$(COMMA),$(SANITIZERS))
    TC_MODE_FLAGS += $(TC_SANITIZE) -fno-omit-frame-pointer
    TC_MODE_FLAGS += $(if $(filter undefined,$(SANITIZERS)),-fno-sanitize-recover=undefined)
    TC_MODE_FLAGS += $(if $(filter memory,$(SANITIZERS)),-fsanitize-memory-track-origins=2)
    TC_MODE_FLAGS += $(if $(filter cfi,$(SANITIZERS)),-fvisibility=hidden)
    TC_MODE_LDFLAGS += $(TC_SANITIZE)
    # How the programs run by 'make run-<target>' and 'make check' report.
    SYMBOLIZER := $(call which,llvm-symbolizer)
    TC_RUN_ENV := \
        $(if $(filter address,$(SANITIZERS)),ASAN_OPTIONS=symbolize=1:check_initialization_order=1:strict_init_order=1$(if $(filter Darwin,$(TARGET_OS)),,:detect_leaks=1)) \
        $(if $(and $(filter address,$(SANITIZERS)),$(SYMBOLIZER)),ASAN_SYMBOLIZER_PATH=$(SYMBOLIZER)) \
        $(if $(filter undefined,$(SANITIZERS)),UBSAN_OPTIONS=symbolize=1:print_stacktrace=1:halt_on_error=1) \
        $(if $(filter thread,$(SANITIZERS)),TSAN_OPTIONS=symbolize=1:second_deadlock_stack=1) \
        $(if $(filter memory,$(SANITIZERS)),MSAN_OPTIONS=symbolize=1:print_stats=1) \
        $(if $(filter leak,$(SANITIZERS)),LSAN_OPTIONS=symbolize=1:print_suppressions=0)
endif

###############################################################################
# Link time optimization: on in the optimized modes, LTO=0 to do without.
###############################################################################

LTO ?= $(if $(filter $(COMPILATION_MODE),$(OPTIMIZED_MODES)),1)
ifneq ($(filter cfi,$(SANITIZERS)),)
    LTO := 1
endif
# Neither with the instrumentations nor in the web build. clang outside of
# macOS needs the linker and the archiver of LLVM.
ifneq ($(COVERAGE)$(filter 1 yes,$(GPROF))$(filter emscripten,$(TOOLCHAIN))$(filter 0 no off,$(LTO)),)
    LTO :=
else ifneq ($(and $(filter clang,$(COMPILER_FAMILY)),$(filter-out Darwin,$(TARGET_OS))),)
    LTO := $(if $(and $(call which,ld.lld),$(filter %llvm-ar,$(AR))),$(LTO))
endif
ifneq ($(LTO),)
    ifeq ($(COMPILER_FAMILY),gcc)
        # Fat objects: the static libraries also work without LTO.
        TC_LTO := $(if $(call gcc-ge,10),-flto=auto,-flto)
        TC_MODE_FLAGS += $(TC_LTO) -ffat-lto-objects
        TC_MODE_LDFLAGS += $(TC_LTO)
    else
        TC_MODE_FLAGS += -flto=thin
        TC_MODE_LDFLAGS += -flto=thin $(if $(filter Darwin,$(TARGET_OS)),,-fuse-ld=lld)
    endif
endif

###############################################################################
# Hardening (HARDENING=0 to do without): stack protections, checks of the C
# library, position independent executables, read only relocations.
###############################################################################

HARDENING ?= 1
ifneq ($(and $(filter 1 yes,$(HARDENING)),$(filter-out emscripten,$(TOOLCHAIN))),)
    TC_MODE_FLAGS += -fstack-protector-strong
    ifneq ($(TARGET_OS),Darwin)
        TC_MODE_FLAGS += $(if $(or $(call gcc-ge,8),$(call clang-ge,11)),-fstack-clash-protection)
        TC_MODE_FLAGS += $(if $(and $(IS_X86_64),$(or $(call gcc-ge,8),$(call clang-ge,7))),-fcf-protection=full)
    endif
    # The checks of _FORTIFY_SOURCE need the optimizer.
    ifneq ($(filter-out debug,$(COMPILATION_MODE)),)
        ifeq ($(COVERAGE),)
            TC_MODE_DEFINES += $(if $(or $(call gcc-ge,12),$(call clang-ge,16)),_FORTIFY_SOURCE=3,_FORTIFY_SOURCE=2)
            TC_UNDEFINES := -U_FORTIFY_SOURCE
        endif
    endif
    ifneq ($(IS_ELF),)
        TC_EXE_FLAGS := -fPIE
        TC_EXE_LDFLAGS := -pie
        TC_HARDEN_LDFLAGS := -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack
    endif
endif

###############################################################################
# Strip the executables and the shared libraries of release, size and fast
# (STRIP=0 to keep the symbols), unless a tool needs the symbols.
###############################################################################

STRIP ?= $(if $(filter release size fast,$(COMPILATION_MODE)),1)
ifneq ($(SANITIZERS)$(COVERAGE)$(filter 1 yes,$(GPROF) $(VALGRIND))$(filter 0 no off,$(STRIP))$(filter Darwin Emscripten,$(TARGET_OS)),)
    STRIP :=
endif
TC_STRIP_LDFLAGS := $(if $(STRIP),-s)

###############################################################################
# Warnings, set per target: WARNINGS := none, default, strict (the default) or
# paranoid. The versions gate the flags an older compiler would refuse.
###############################################################################

WARN_COMMON := -Wall -Wextra -Wpedantic -Wuninitialized -Wundef -Wunused \
    -Wunused-result -Wunused-parameter -Wtype-limits -Wcast-align \
    -Wcast-qual -Wconversion -Wsign-conversion -Wfloat-equal -Wpointer-arith \
    -Wswitch-enum -Wpacked -Wdeprecated -Wvariadic-macros -Wvla -Wshadow \
    -Wnull-dereference -Wdouble-promotion -Wformat=2 -Wformat-security \
    -Werror=format-security
WARN_CXX := -Wold-style-cast -Woverloaded-virtual -Wnon-virtual-dtor \
    -Wctor-dtor-privacy -Wdelete-non-virtual-dtor
WARN_C := -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations \
    -Wbad-function-cast -Wnested-externs -Wold-style-definition

# Code which the next C++ standard would break.
CXX_STD_NUMBER := $(patsubst c++%,%,$(patsubst gnu++%,%,$(patsubst -std=%,%,$(patsubst --std=%,%,$(CXX_STANDARD)))))
WARN_CXX += $(if $(filter 11,$(CXX_STD_NUMBER)),-Wc++14-compat)$(if $(filter 14,$(CXX_STD_NUMBER)),-Wc++17-compat)$(if $(filter 17,$(CXX_STD_NUMBER)),$(if $(or $(call gcc-ge,10),$(call clang-ge,10)),-Wc++20-compat))

ifeq ($(COMPILER_FAMILY),gcc)
    WARN_COMMON += -Wduplicated-cond -Wduplicated-branches -Wlogical-op
    WARN_COMMON += $(if $(call gcc-ge,6),-Wtautological-compare -Wshift-overflow=2 -Wshift-negative-value)
    WARN_COMMON += $(if $(call gcc-ge,7),-Walloc-zero -Walloca)
    WARN_COMMON += $(if $(call gcc-ge,8),-Wcast-align=strict)
    WARN_COMMON += $(if $(call gcc-ge,10),-Warith-conversion)
    WARN_COMMON += $(if $(call gcc-ge,12),-Wbidi-chars=any)
    WARN_CXX += -Wuseless-cast -Wnoexcept -Wstrict-null-sentinel
    WARN_CXX += $(if $(call gcc-ge,8),-Wcatch-value=3 -Wextra-semi)
    WARN_CXX += $(if $(call gcc-ge,9),-Wpessimizing-move -Wredundant-move)
    WARN_CXX += $(if $(call gcc-ge,10),-Wcomma-subscript -Wmismatched-tags -Wredundant-tags)
    WARN_CXX += $(if $(call gcc-ge,11),-Wrange-loop-construct)
    WARN_C += -Wjump-misses-init
    WARN_PARANOID := -Wwrite-strings -Wredundant-decls -Winline \
        -Wdisabled-optimization
    WARN_PARANOID_CXX := -Weffc++
else
    # clang ignores, with a warning, the flags it does not know.
    WARN_COMMON += -Wno-unknown-warning-option -Wno-unused-command-line-argument \
        -Wconditional-uninitialized -Wused-but-marked-unused \
        -Wunused-exception-parameter -Wunneeded-internal-declaration \
        -Wshadow-all -Wunreachable-code-aggressive -Wvector-conversion \
        -Wzero-length-array -Wthread-safety -Wcomma -Wdocumentation \
        -Wloop-analysis -Wshift-sign-overflow -Wstring-conversion \
        -Wtautological-overlap-compare -Wtautological-compare \
        -Wrange-loop-analysis -Wfor-loop-analysis -Wsuspicious-bzero \
        -Wbitwise-instead-of-logical -Wbitwise-op-parentheses \
        -Warray-parameter -Wcast-function-type-strict
    WARN_CXX += -Wunused-member-function -Wunneeded-member-function \
        -Wundefined-reinterpret-cast -Wsuper-class-method-mismatch \
        -Winconsistent-missing-override -Wabstract-vbase-init
    WARN_C += -Werror=implicit-function-declaration
    WARN_PARANOID := -Weverything -Wno-padded -Wno-c++98-compat \
        -Wno-c++98-compat-pedantic -Wno-weak-vtables -Wno-exit-time-destructors \
        -Wno-global-constructors
    WARN_PARANOID_CXX :=
endif

tc-warnings = $(if $(filter none,$1),-w,$(if $(filter default,$1),-Wall -Wextra,$(WARN_COMMON) $2 $(if $(filter paranoid,$1),$(WARN_PARANOID) $3)))
tc-warnings-cxx = $(call tc-warnings,$1,$(WARN_CXX),$(WARN_PARANOID_CXX))
tc-warnings-c = $(call tc-warnings,$1,$(WARN_C))

###############################################################################
# Recipes. $1 is the name of the MyMakefile target.
###############################################################################

tc-compile-cxx = $(COMPILER_LAUNCHER) $(CXX) $($1._CXXFLAGS) -MMD -MP -c $< -o $@
tc-compile-c = $(COMPILER_LAUNCHER) $(CC) $($1._CFLAGS) -MMD -MP -c $< -o $@
# Only .S files go through the preprocessor, which writes the dependencies.
tc-compile-asm = $(CC) $($1._ASFLAGS) $(if $(filter %.S,$<),-MMD -MP) -c $< -o $@
tc-archive = $(AR) crs $@ $($1._ARCHIVE_OBJS)
tc-link-exe = $($1._LINKER) -o $@ $($1._LINK_OBJS) $($1._LDFLAGS) $($1._LIBS)

ifeq ($(TARGET_OS),Windows)
    tc-shared-name = $(LIB_PREFIX)$1$(SHARED_EXT)
    tc-link-shared = $($1._LINKER) -shared -o $@ $($1._LINK_OBJS) \
        -Wl,--out-implib,$($1._IMPLIB) $($1._LDFLAGS) $($1._LIBS)
else ifeq ($(TARGET_OS),Darwin)
    tc-shared-name = $(LIB_PREFIX)$1$(SHARED_EXT)
    tc-link-shared = $($1._LINKER) -dynamiclib -o $@ $($1._LINK_OBJS) \
        -install_name @rpath/$(notdir $@) \
        -current_version $(PROJECT_VERSION) $($1._LDFLAGS) $($1._LIBS)
else
    # libfoo.so.1.2.3 with the soname libfoo.so.1, and the two usual links.
    tc-shared-name = $(LIB_PREFIX)$1$(SHARED_EXT).$(PROJECT_VERSION)
    tc-soname = $(LIB_PREFIX)$1$(SHARED_EXT).$(call version-field,1,$(PROJECT_VERSION))
    tc-link-shared = $($1._LINKER) -shared -o $@ $($1._LINK_OBJS) \
        -Wl,-soname,$(call tc-soname,$($1.NAME)) $($1._LDFLAGS) $($1._LIBS)
    tc-shared-post = cd $(@D) && ln -sf $(@F) $(call tc-soname,$($1.NAME)) && ln -sf $(@F) $(LIB_PREFIX)$($1.NAME)$(SHARED_EXT)
endif
