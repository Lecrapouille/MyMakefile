# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
#
# Goals working on all the targets. The goals of one target 't' are generated
# with it: 't', 'run-t', 'clean-t'. clean, distclean, veryclean and install
# are double-colon rules: a project can add its own recipe to them.

_mm_tests := $(foreach t,$(TARGETS),$(if $(filter test,$($t.TYPE)),$t))
_mm_externals := $(foreach t,$(TARGETS),$(if $($t.GIT),$t))
_mm_products := $(filter-out $(_mm_tests) $(_mm_externals),$(TARGETS))
_mm_installed := $(foreach t,$(_mm_products),$(if $(filter 0 no,$($t.INSTALL)),,$t))

# One command of a recipe built by a function: $(call _mm_cmd,mkdir -p foo)
_mm_cmd = $(Q)$1$(_mm_newline)

.DEFAULT_GOAL := all

#? Build every target, except the tests.
.PHONY: all
all: $(_mm_products)

###############################################################################
# Tests
###############################################################################

_mm_run_test = $(call _mm_cmd,$(call _mm_echo_simple,Testing,$1))$(call _mm_cmd,$(TEST_RUNNER) $(call _mm_exec,$($1._EXE)) $($1.ARGS))

.PHONY: _mm_run_tests
_mm_run_tests: $(_mm_tests)
	$(foreach t,$(_mm_tests),$(call _mm_run_test,$t))

#? Build and run the tests, from the root of the project.
.PHONY: check
check: _mm_run_tests
	$(call _mm_say_ok,$(words $(_mm_tests)) test program(s) passed)
	@$(_mm_noop)

###############################################################################
# Cleaning
###############################################################################

#? Remove the build of the current configuration.
.PHONY: clean
clean::
	$(call _mm_say_simple,Cleaning,$(PROJECT_NAME),$(_mm_space)$(BUILD))
	$(Q)$(call _mm_rmdir,$(BUILD))

#? Remove the builds of all configurations.
.PHONY: distclean
distclean::
	$(call _mm_say_simple,Cleaning,$(PROJECT_NAME),$(_mm_space)$(BUILD_DIR))
	$(Q)$(call _mm_rmdir,$(BUILD_DIR))
	$(Q)$(call _mm_rm,compile_commands.json)

# Leftovers of the tools, anywhere in the project: coverage, profiling,
# patches, editors.
VERYCLEAN_PATTERNS ?= %.gcda %.gcno %.gcov gmon.out perf.data% %.prof \
    %.orig %.rej %~
_mm_leftovers = $(strip $(foreach f,$(filter-out ./$(BUILD_DIR)/%,$(call _mm_rwildcard,.,*)),$(if $(filter $(VERYCLEAN_PATTERNS),$(notdir $f)),$f)))

# What the targets of the SUBMAKEFILES ask to remove: 't.CLEAN', relative to
# the directory of the file declaring them.
_mm_target_clean = $(foreach t,$(TARGETS),$(call _mm_glob,$($t.CLEAN),$($t.DIR)))

#? Remove everything that can be generated again: the builds, the clones of
#? the third parties, the documentation, the coverage report, the leftovers
#? of the tools, and the files given by 't.CLEAN' and CLEAN_FILES.
.PHONY: veryclean
veryclean:: distclean
	$(call _mm_say_simple,Cleaning,$(PROJECT_NAME),$(_mm_space)everything)
	$(foreach t,$(_mm_externals),$(if $(wildcard $(EXTERNAL_DIR)/$t/.git),$(call _mm_cmd,$(call _mm_rmdir,$(EXTERNAL_DIR)/$t))))
	$(Q)$(call _mm_rmdir,$(DOXYGEN_DIR))
	$(Q)$(call _mm_rmdir,$(COVERAGE_DIR))
	$(foreach f,$(_mm_target_clean) $(CLEAN_FILES),$(call _mm_cmd,$(if $(filter %/,$(wildcard $f/)),$(call _mm_rmdir,$f),$(call _mm_rm,$f))))
	$(if $(strip $(_mm_leftovers)),$(call _mm_cmd,$(call _mm_rm,$(_mm_leftovers))))

#? Build the current configuration again from scratch.
.PHONY: rebuild
rebuild: all

###############################################################################
# compile_commands.json for clangd and the IDEs.
###############################################################################

_mm_json = $(subst ",\",$(subst \,\\,$1))
_mm_cc_entry = {"directory": "$(CURDIR)", "file": "$2", "output": "$3", "command": "$(call _mm_json,$(if $(filter %.c,$2),$(CC) $($1._CFLAGS),$(CXX) $($1._CXXFLAGS)) -c $2 -o $3)"}
_mm_cc_entries = $(foreach t,$(TARGETS),$(foreach s,$($t._SRCS),$(call _mm_cc_entry,$t,$s,$($t._OBJDIR)/$(basename $(call _mm_objstem,$s))$(OBJ_EXT))))

#? Write compile_commands.json for clangd.
.PHONY: compile-commands
compile-commands:
	$(call _mm_say_to,Generating,$(PROJECT_NAME),compile_commands.json)
	@$(_mm_noop)
	$(file >compile_commands.json,[$(_mm_newline)$(subst } {,}$(_mm_comma)$(_mm_newline){,$(_mm_cc_entries))$(_mm_newline)])

###############################################################################
# Copy of what the project delivers, shared by install and dist: executables
# (and bundles), libraries with their public headers and a pkg-config file,
# data. Works with sh and cmd.exe.
###############################################################################

_mm_misc := $(BUILD)/misc
$(_mm_misc): ; $(Q)$(call _mm_mkdir,$@)

# The prefix is found from the place of the .pc file: the same file works
# installed in /usr/local and unpacked from an archive of 'make dist'.
define _mm_pc_file
prefix=$${pcfiledir}/../..
libdir=$${prefix}/lib
includedir=$${prefix}/include

Name: $($1.NAME)
Description: $(or $($1.DESCRIPTION),$(PROJECT_NAME))
Version: $(PROJECT_VERSION)
Requires: $($1.PKG_CONFIG)
Libs: -L$${libdir} -l$($1.NAME) $($1.LIBS)
Cflags: -I$${includedir} $(addprefix -D,$($1.PUBLIC_DEFINES))
endef

_mm_pc = $(_mm_misc)/$($1.NAME).pc
_mm_pc_libs := $(foreach t,$(_mm_installed),$(if $($t._IS_LIB),$t))
_mm_pcs := $(foreach t,$(_mm_pc_libs),$(call _mm_pc,$t))

define _mm_pc_rule
$$(call _mm_pc,$(1)): $$($(1)._LD_STAMP) | $$(_mm_misc)
	$$(file >$$@,$$(call _mm_pc_file,$(1)))
endef
$(foreach t,$(_mm_pc_libs),$(eval $(call _mm_pc_rule,$t)))

# Files beside an executable: .js, .wasm and .data of Emscripten.
_mm_exe_files = $(if $(filter Emscripten,$(TARGET_OS)),$(basename $($1._EXE)).*,$($1._EXE))
_mm_shared_files = $(if $(filter Windows,$(TARGET_OS)),$($1._SHARED),$(dir $($1._SHARED))$(LIB_PREFIX)$($1.NAME)$(SHARED_EXT)*)

# $1: target, $2: destination
_mm_stage = \
    $(if $($1._EXE),$(call _mm_cmd,$(call _mm_mkdir,$2/bin))$(call _mm_cmd,$(call _mm_copy,$(call _mm_exe_files,$1),$2/bin/))) \
    $(if $($1._BUNDLE),$(call _mm_cmd,$(call _mm_copydir,$($1._BUNDLE),$2/bin/$(notdir $($1._BUNDLE))))) \
    $(if $($1._IS_LIB),$(call _mm_cmd,$(call _mm_mkdir,$2/lib/pkgconfig))$(call _mm_cmd,$(call _mm_copy,$(call _mm_pc,$1),$2/lib/pkgconfig/))) \
    $(if $($1._ARCHIVE),$(call _mm_cmd,$(call _mm_copy,$($1._ARCHIVE),$2/lib/))) \
    $(if $($1._IMPLIB),$(call _mm_cmd,$(call _mm_copy,$($1._IMPLIB),$2/lib/))) \
    $(if $($1._SHARED),$(call _mm_cmd,$(call _mm_mkdir,$2/$(if $(filter Windows,$(TARGET_OS)),bin,lib)))$(call _mm_cmd,$(call _mm_copy,$(call _mm_shared_files,$1),$2/$(if $(filter Windows,$(TARGET_OS)),bin,lib)/))) \
    $(if $($1._IS_LIB),$(foreach d,$($1._PUB_INCS),$(call _mm_cmd,$(call _mm_copydir,$d,$2/include)))) \
    $(foreach d,$($1._DATA),$(call _mm_cmd,$(call _mm_copydir,$d,$2/share/$(PROJECT_NAME))))

_mm_dest = $(DESTDIR)$(PREFIX)

#? Install the project in $(DESTDIR)$(PREFIX).
.PHONY: install
install:: all $(_mm_pcs)
	$(call _mm_say_to,Installing,$(PROJECT_NAME),$(_mm_dest))
	$(foreach t,$(_mm_installed),$(call _mm_stage,$t,$(_mm_dest)))

###############################################################################
# Continuous integration
###############################################################################

#? Name and place of the archive made by 'make dist'.
DIST_NAME ?= $(PROJECT_NAME)-$(PROJECT_VERSION)-$(_mm_os)-$(TARGET_ARCH)
DIST_DIR ?= $(BUILD_DIR)/dist/$(DIST_NAME)
DIST_ARCHIVE ?= $(DIST_DIR).tar.gz
#? Files copied at the root of the archive.
DIST_FILES ?= $(wildcard LICENSE* LICENCE* LICENSING* COPYING* README* AUTHORS ChangeLog CHANGELOG*)

$(_mm_misc)/VERSION: | $(_mm_misc)
	$(file >$@,$(PROJECT_VERSION))

#? Gather what the project delivers in DIST_DIR and DIST_ARCHIVE: the files
#? of 'make install', DIST_FILES and VERSION. For the artifacts of a CI.
.PHONY: dist
dist: all $(_mm_pcs) $(_mm_misc)/VERSION
	$(call _mm_say_to,Packaging,$(PROJECT_NAME),$(DIST_ARCHIVE))
	$(Q)$(call _mm_rmdir,$(DIST_DIR))
	$(Q)$(call _mm_mkdir,$(DIST_DIR))
	$(foreach t,$(_mm_installed),$(call _mm_stage,$t,$(DIST_DIR)))
	$(foreach f,$(DIST_FILES) $(_mm_misc)/VERSION,$(call _mm_cmd,$(call _mm_copy,$f,$(DIST_DIR)/)))
	$(Q)tar -czf $(DIST_ARCHIVE) -C $(dir $(DIST_DIR)) $(notdir $(DIST_DIR))

#? Goals of 'make ci'.
CI_GOALS ?= all check

#? Everything a CI checks, in one command: CI_GOALS (default: all check).
.PHONY: ci
ci: $(CI_GOALS)

#? Print 'key=value' lines describing the build, for $GITHUB_OUTPUT or
#? $GITHUB_ENV: make -s ci-info >> "$GITHUB_OUTPUT"
.PHONY: ci-info
ci-info:
	$(info name=$(PROJECT_NAME))
	$(info version=$(PROJECT_VERSION))
	$(info os=$(_mm_os))
	$(info arch=$(TARGET_ARCH))
	$(info toolchain=$(TOOLCHAIN))
	$(info mode=$(COMPILATION_MODE))
	$(info build=$(BUILD))
	$(info dist_name=$(DIST_NAME))
	$(info dist_dir=$(DIST_DIR))
	$(info dist_archive=$(DIST_ARCHIVE))
	@$(_mm_noop)

#? Print a variable: make -s print-PROJECT_VERSION
print-%:
	$(info $($*))
	@$(_mm_noop)

#? Print the flags of every target.
.PHONY: show-flags
show-flags:
	$(foreach t,$(TARGETS),$(info $(CYAN)$t$(COLOR_DEFAULT))$(if $($t._SRCS),$(info $(_mm_space) CXXFLAGS $($t._CXXFLAGS)))$(if $($t._EXE)$($t._SHARED),$(info $(_mm_space) LDFLAGS  $($t._LDFLAGS))$(info $(_mm_space) LIBS     $($t._LIBS))))
	@$(_mm_noop)

###############################################################################
# Help
###############################################################################

_mm_kind = $(if $($1.GIT),external $(if $(filter header-only,$($1.TYPE)),headers,$($1.TYPE)),$($1.TYPE))

#? List the targets and what they depend on.
.PHONY: list-targets
list-targets:
	$(foreach t,$(TARGETS),$(info $(CYAN)$t$(COLOR_DEFAULT) ($(call _mm_kind,$t))$(if $($t.DEPENDS),: $($t.DEPENDS))))
	@$(_mm_noop)

#? Print this help.
.PHONY: help
help:
	$(info $(PURPLE)$(PROJECT_NAME) $(PROJECT_VERSION)$(COLOR_DEFAULT), built in $(BUILD) by MyMakefile $(MYMAKEFILE_VERSION))
	$(info $(_mm_space) TOOLCHAIN=$(TOOLCHAIN) ($(COMPILER_FAMILY) $(COMPILER_VERSION)) TARGET_OS=$(TARGET_OS) COMPILATION_MODE=$(COMPILATION_MODE))
	$(info )
	$(info Build:)
	$(info $(_mm_space) $(GREEN)all$(COLOR_DEFAULT)                every target except the tests (default))
	$(info $(_mm_space) $(GREEN)<target>$(COLOR_DEFAULT)           one target and what it depends on)
	$(info $(_mm_space) $(GREEN)run-<target>$(COLOR_DEFAULT)       build and run an executable, with ARGS="...")
	$(info $(_mm_space) $(GREEN)check$(COLOR_DEFAULT)              build and run the tests)
	$(info $(_mm_space) $(GREEN)coverage$(COLOR_DEFAULT)           run the tests and write the coverage report)
	$(info $(_mm_space) $(GREEN)rebuild$(COLOR_DEFAULT)            build this configuration from scratch)
	$(info $(_mm_space) $(GREEN)install$(COLOR_DEFAULT)            install in DESTDIR/PREFIX ($(_mm_dest)))
	$(info Clean:)
	$(info $(_mm_space) $(GREEN)clean-<target>$(COLOR_DEFAULT)     the build of one target)
	$(info $(_mm_space) $(GREEN)clean$(COLOR_DEFAULT)              the build of this configuration)
	$(info $(_mm_space) $(GREEN)distclean$(COLOR_DEFAULT)          the builds of all configurations)
	$(info $(_mm_space) $(GREEN)veryclean$(COLOR_DEFAULT)          also third parties, documentation, reports, leftovers)
	$(info Tools:)
	$(info $(_mm_space) $(GREEN)doc$(COLOR_DEFAULT)                Doxygen documentation in $(DOXYGEN_DIR))
	$(info $(_mm_space) $(GREEN)format, check-format$(COLOR_DEFAULT) clang-format the sources, or only check them)
	$(info $(_mm_space) $(GREEN)lint$(COLOR_DEFAULT)               cppcheck)
	$(info $(_mm_space) $(GREEN)compile-commands$(COLOR_DEFAULT)   write compile_commands.json)
	$(info $(_mm_space) $(GREEN)tarball, rpm$(COLOR_DEFAULT)       archive of the sources, RPM package)
	$(info CI:)
	$(info $(_mm_space) $(GREEN)ci$(COLOR_DEFAULT)                 $(CI_GOALS))
	$(info $(_mm_space) $(GREEN)dist$(COLOR_DEFAULT)               $(DIST_ARCHIVE))
	$(info $(_mm_space) $(GREEN)ci-info$(COLOR_DEFAULT)            key=value lines for $$GITHUB_OUTPUT)
	$(info $(_mm_space) $(GREEN)print-<VAR>$(COLOR_DEFAULT)        print a variable)
	$(info Information:)
	$(info $(_mm_space) $(GREEN)list-targets, show-flags, help$(COLOR_DEFAULT))
	$(info )
	$(info Options: COMPILATION_MODE=debug|normal|release TOOLCHAIN=gcc|clang|mingw|emscripten|msvc)
	$(info $(_mm_space)        V=1 COLORS=0|1 COVERAGE=1 SANITIZER=address|undefined|thread BUILD_DIR=build)
	$(info )
	$(info Targets: $(TARGETS))
	@$(_mm_noop)
