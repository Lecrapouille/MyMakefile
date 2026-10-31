###############################################################################
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
###############################################################################
#
# Goals working on all the targets. The goals of one target 't' are generated
# with it: 't', 'run-t', 'clean-t'. clean, distclean, veryclean, install and
# uninstall are double-colon rules: a project can add its own recipe to them.

TEST_TARGETS := $(strip $(foreach t,$(TARGETS),$(if $(filter test,$($t.TYPE)),$t)))
OWN_TARGETS := $(filter-out $(EXTERNAL_TARGETS),$(TARGETS))
PRODUCT_TARGETS := $(filter-out $(TEST_TARGETS),$(OWN_TARGETS))

.DEFAULT_GOAL := all

#? Build every target, except the tests; then run POST_BUILD.
.PHONY: all
all: $(PRODUCT_TARGETS)
	$(POST_BUILD)
	@$(NOOP)

###############################################################################
# Tests
###############################################################################

run-test = $(call cmd,$(call echo-simple,Testing,$1))$(call cmd,$(call run-target,$1))

.PHONY: run-all-tests
run-all-tests: $(TEST_TARGETS)
	$(foreach t,$(TEST_TARGETS),$(call run-test,$t))

#? Build and run the tests, from the root of the project.
.PHONY: check
check: run-all-tests
	$(call print-ok,$(words $(TEST_TARGETS)) test program(s) passed)
	@$(NOOP)

###############################################################################
# Cleaning
###############################################################################

#? Remove the build of the current configuration.
.PHONY: clean
clean::
	$(call print-simple,Cleaning,$(PROJECT_NAME),$(SPACE)$(BUILD))
	$(Q)$(call remove-dir,$(BUILD))

#? Remove the builds of all configurations.
.PHONY: distclean
distclean::
	$(call print-simple,Cleaning,$(PROJECT_NAME),$(SPACE)$(BUILD_DIR))
	$(Q)$(call remove-dir,$(BUILD_DIR))
	$(Q)$(call remove-files,compile_commands.json)

# Leftovers of the tools, anywhere in the project: coverage, profiling,
# patches, editors.
VERYCLEAN_PATTERNS ?= %.gcda %.gcno %.gcov gmon.out perf.data% %.prof \
    %.orig %.rej %~
leftovers = $(strip $(foreach f,$(filter-out ./$(BUILD_DIR)/%,$(call rwildcard,.,*)),$(if $(filter $(VERYCLEAN_PATTERNS),$(notdir $f)),$f)))

# What the targets of the SUBMAKEFILES ask to remove: 't.CLEAN', relative to
# the directory of the file declaring them.
target-clean = $(foreach t,$(TARGETS),$(call glob,$($t.CLEAN),$($t.DIR)))

#? Remove everything that can be generated again: the builds, the clones of
#? the third parties in EXTERNAL_DIR (not the shared cache: cache-clean), the
#? documentation, the coverage report, the leftovers of the tools, and the
#? files given by 't.CLEAN' and CLEAN_FILES.
.PHONY: veryclean
veryclean:: distclean
	$(call print-simple,Cleaning,$(PROJECT_NAME),$(SPACE)everything)
	$(foreach t,$(EXTERNAL_TARGETS),$(if $(wildcard $(EXTERNAL_DIR)/$t/.git),$(call cmd,$(call remove-dir,$(EXTERNAL_DIR)/$t))))
	$(Q)$(call remove-dir,$(DOXYGEN_DIR))
	$(Q)$(call remove-dir,$(COVERAGE_DIR))
	$(Q)$(call remove-dir,$(PROFILE_DIR))
	$(foreach f,$(target-clean) $(CLEAN_FILES),$(call cmd,$(if $(filter %/,$(wildcard $f/)),$(call remove-dir,$f),$(call remove-files,$f))))
	$(if $(leftovers),$(call cmd,$(call remove-files,$(leftovers))))

#? Build the current configuration again from scratch.
.PHONY: rebuild
rebuild: all

###############################################################################
# compile_commands.json for clangd and the IDEs.
###############################################################################

json-escape = $(subst ",\",$(subst \,\\,$1))
compile-entry = {"directory": "$(CURDIR)", "file": "$2", "output": "$3", "command": "$(call json-escape,$(if $(filter %.c,$2),$(CC) $($1._CFLAGS),$(CXX) $($1._CXXFLAGS)) -c $2 -o $3)"}
compile-entries = $(foreach t,$(TARGETS),$(foreach s,$($t._SRCS),$(call compile-entry,$t,$s,$(call object-of,$t,$s))))

#? Write compile_commands.json for clangd.
.PHONY: compile-commands
compile-commands:
	$(call print-to,Generating,$(PROJECT_NAME),compile_commands.json)
	@$(NOOP)
	$(file >compile_commands.json,[$(NEWLINE)$(subst } {,}$(COMMA)$(NEWLINE){,$(compile-entries))$(NEWLINE)])

###############################################################################
# Continuous integration
###############################################################################

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
	$(info os=$(OS_NAME))
	$(info arch=$(TARGET_ARCH))
	$(info toolchain=$(TOOLCHAIN))
	$(info mode=$(COMPILATION_MODE))
	$(info build=$(BUILD))
	$(info cache=$(EXTERNAL_CACHE))
	$(info dist_name=$(DIST_NAME))
	$(info dist_dir=$(DIST_DIR))
	$(info dist_archive=$(DIST_ARCHIVE))
	@$(NOOP)

#? Print a variable: make -s print-PROJECT_VERSION
print-%:
	$(info $($*))
	@$(NOOP)

###############################################################################
# Information
###############################################################################

#? Print the configuration: compiler, mode, options, flags of every target.
.PHONY: show-flags
show-flags:
	$(info $(PURPLE)$(PROJECT_NAME)$(COLOR_DEFAULT): $(COMPILER_FAMILY) $(COMPILER_VERSION) $(TARGET_OS) $(TARGET_ARCH) $(COMPILATION_MODE))
	$(info $(SPACE) ccache=$(or $(COMPILER_LAUNCHER),no) lto=$(or $(LTO),no) hardening=$(or $(filter 1 yes,$(HARDENING)),no) strip=$(or $(STRIP),no) sanitizers=$(or $(SANITIZERS),none) coverage=$(or $(COVERAGE),no))
	$(foreach t,$(TARGETS),$(info $(CYAN)$t$(COLOR_DEFAULT))$(if $($t._SRCS),$(info $(SPACE) CXXFLAGS $($t._CXXFLAGS)))$(if $($t._EXE)$($t._SHARED),$(info $(SPACE) LDFLAGS  $($t._LDFLAGS))$(info $(SPACE) LIBS     $($t._LIBS))))
	@$(NOOP)

target-kind = $(if $(filter $1,$(EXTERNAL_TARGETS)),external $(if $(filter header-only,$($1.TYPE)),headers,$($1.TYPE)),$($1.TYPE))

#? List the targets and what they depend on.
.PHONY: list-targets
list-targets:
	$(foreach t,$(TARGETS),$(info $(CYAN)$t$(COLOR_DEFAULT) ($(call target-kind,$t))$(if $($t.DEPENDS),: $($t.DEPENDS))))
	@$(NOOP)

help-line = $(info $(SPACE) $(GREEN)$1$(COLOR_DEFAULT)$(SPACE)$2)

#? Print this help.
.PHONY: help
help:
	$(info $(PURPLE)$(PROJECT_NAME) $(PROJECT_VERSION)$(COLOR_DEFAULT), built in $(BUILD) by MyMakefile $(MYMAKEFILE_VERSION))
	$(info $(SPACE) TOOLCHAIN=$(TOOLCHAIN) ($(COMPILER_FAMILY) $(COMPILER_VERSION)) TARGET_OS=$(TARGET_OS) COMPILATION_MODE=$(COMPILATION_MODE))
	$(info )
	$(info Build:)
	$(call help-line,all               ,every target except the tests (default))
	$(call help-line,<target>          ,one target and what it depends on)
	$(call help-line,run-<target>      ,build and run an executable$(COMMA) with ARGS="...")
	$(call help-line,gdb-<target>      ,build it and run it in the debugger (GDB=lldb...))
	$(call help-line,check             ,build and run the tests)
	$(call help-line,coverage          ,run the tests and write the coverage report)
	$(call help-line,rebuild           ,build this configuration from scratch)
	$(call help-line,install$(COMMA) uninstall,in DESTDIR/PREFIX ($(DESTDIR)$(PREFIX)))
	$(info Clean:)
	$(call help-line,clean-<target>    ,the build of one target)
	$(call help-line,clean             ,the build of this configuration)
	$(call help-line,distclean         ,the builds of all configurations)
	$(call help-line,veryclean         ,also third parties$(COMMA) documentation$(COMMA) reports$(COMMA) leftovers)
	$(info Third parties:)
	$(call help-line,update-externals  ,move them to the last commit of their VERSION)
	$(call help-line,cache-info        ,where they are in the cache)
	$(call help-line,cache-clean       ,remove the cache shared by all the projects)
	$(info Tools:)
	$(call help-line,doc               ,Doxygen documentation in $(DOXYGEN_DIR))
	$(call help-line,format            ,clang-format the sources; check-format only checks them)
	$(call help-line,lint$(COMMA) tidy        ,cppcheck$(COMMA) clang-tidy)
	$(call help-line,memcheck          ,run the tests in valgrind)
	$(call help-line,gprof             ,profile GPROF_TARGET$(COMMA) report in $(PROFILE_DIR))
	$(call help-line,size-analysis     ,sizes of the sections of the binaries)
	$(call help-line,check-harden      ,hardening of the executables (hardening-check$(COMMA) checksec))
	$(call help-line,coverity          ,archive of a build under cov-build)
	$(call help-line,compile-commands  ,write compile_commands.json)
	$(call help-line,tarball$(COMMA) rpm      ,archive of the sources$(COMMA) RPM package)
	$(info CI:)
	$(call help-line,ci                ,$(CI_GOALS))
	$(call help-line,dist              ,$(DIST_ARCHIVE))
	$(call help-line,ci-info           ,key=value lines for $$GITHUB_OUTPUT)
	$(call help-line,print-<VAR>       ,print a variable)
	$(info Information:)
	$(call help-line,list-targets      ,the targets and their dependencies)
	$(call help-line,show-flags        ,the options and the flags of each target)
	$(info )
	$(info Modes:   COMPILATION_MODE=debug|normal|release|release-with-debug|size|fast)
	$(info Options: TOOLCHAIN=gcc|clang|mingw|emscripten|msvc V=1 COLORS=0|1 WERROR=1)
	$(info $(SPACE)        SANITIZER=address,undefined|thread|memory|leak|... COVERAGE=1 GPROF=1)
	$(info $(SPACE)        LTO=0 HARDENING=0 STRIP=0 NATIVE=1 FAST_MATH=1 PGO=generate|use CCACHE=0)
	$(info $(SPACE)        BACKWARD=0 DBG_MACRO=0 EXTERNAL_CACHE= BUILD_DIR=build JOBS=$(JOBS))
	$(info $(SPACE)        PREFIX=/usr/local INSTALL_VERSIONED=1 FORCE_LOWER_CASE=1 EXPORT_MACRO=API_LINKAGE)
	$(info )
	$(info Targets: $(TARGETS))
	@$(NOOP)
