# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
#
# Goals working on all the targets. The goals of one target 't' are generated
# with it: 't', 'run-t', 'clean-t'.

_mm_tests := $(foreach t,$(TARGETS),$(if $(filter test,$($t.TYPE)),$t))
_mm_externals := $(foreach t,$(TARGETS),$(if $($t.GIT),$t))
_mm_installed := $(foreach t,$(filter-out $(_mm_tests) $(_mm_externals),$(TARGETS)),$(if $(filter 0 no,$($t.INSTALL)),,$t))

.DEFAULT_GOAL := all

#? Build every target, except the tests.
.PHONY: all
all: $(filter-out $(_mm_tests) $(_mm_externals),$(TARGETS))

#? Build and run the tests, from the root of the project.
.PHONY: check
check: $(_mm_tests)
	$(foreach t,$(_mm_tests),$(Q)$(TEST_RUNNER) $(call _mm_exec,$($t._EXE)) $($t.ARGS)$(_mm_newline))

#? Remove the build of the current configuration.
.PHONY: clean
clean:
	$(Q)$(call _mm_rmdir,$(BUILD))

#? Remove the builds of all configurations.
.PHONY: distclean
distclean:
	$(Q)$(call _mm_rmdir,$(BUILD_DIR))
	$(Q)$(call _mm_rm,compile_commands.json)

###############################################################################
# compile_commands.json for clangd and the IDEs.
###############################################################################

_mm_json = $(subst ",\",$(subst \,\\,$1))
_mm_cc_entry = {"directory": "$(CURDIR)", "file": "$2", "output": "$3", "command": "$(call _mm_json,$(if $(filter %.c,$2),$(CC) $($1._CFLAGS),$(CXX) $($1._CXXFLAGS)) -c $2 -o $3)"}
_mm_cc_entries = $(foreach t,$(TARGETS),$(foreach s,$($t._SRCS),$(call _mm_cc_entry,$t,$s,$($t._OBJDIR)/$(basename $(call _mm_objstem,$s))$(OBJ_EXT))))

#? Write compile_commands.json for clangd.
.PHONY: compile-commands
compile-commands:
	$(call _mm_say,$(PROJECT_NAME),GEN,compile_commands.json)
	@$(_mm_noop)
	$(file >compile_commands.json,[$(_mm_newline)$(subst } {,}$(_mm_comma)$(_mm_newline){,$(_mm_cc_entries))$(_mm_newline)])

###############################################################################
# Installation (POSIX shell only): executables, libraries with their public
# headers and a pkg-config file, data. Use DESTDIR for staging and PREFIX.
###############################################################################

_mm_dest = $(DESTDIR)$(PREFIX)

define _mm_pc_file
prefix=$(PREFIX)
libdir=$${prefix}/lib
includedir=$${prefix}/include

Name: $($1.NAME)
Description: $(or $($1.DESCRIPTION),$(PROJECT_NAME))
Version: $(PROJECT_VERSION)
Requires: $($1.PKG_CONFIG)
Libs: -L$${libdir} -l$($1.NAME) $($1.LIBS)
Cflags: -I$${includedir} $(addprefix -D,$($1.PUBLIC_DEFINES))
endef

_mm_pc = $(BUILD)/pkgconfig/$($1.NAME).pc
_mm_pc_libs := $(foreach t,$(_mm_installed),$(if $($t._IS_LIB),$t))

define _mm_pc_rule
$$(call _mm_pc,$(1)): $$($(1)._LD_STAMP) | $$(BUILD)/pkgconfig
	$$(file >$$@,$$(call _mm_pc_file,$(1)))
endef
$(foreach t,$(_mm_pc_libs),$(eval $(call _mm_pc_rule,$t)))
$(BUILD)/pkgconfig: ; $(Q)$(call _mm_mkdir,$@)

define _mm_install_target
$(if $($1._EXE),$(Q)mkdir -p $(_mm_dest)/bin && cp -f $($1._EXE) $(_mm_dest)/bin/
)$(if $($1._IS_LIB),$(Q)cp -fP $($1._ARCHIVE) $(if $($1._SHARED),$(dir $($1._SHARED))$(LIB_PREFIX)$($1.NAME)$(SHARED_EXT)*) $(_mm_dest)/lib/
$(Q)cp -f $(call _mm_pc,$1) $(_mm_dest)/lib/pkgconfig/
)$(if $($1._IS_LIB),$(foreach d,$($1._PUB_INCS),$(Q)$(call _mm_copydir,$d,$(_mm_dest)/include)
))$(foreach d,$($1._DATA),$(Q)$(call _mm_copydir,$d,$(_mm_dest)/share/$(PROJECT_NAME))
)
endef

#? Install the project in $(DESTDIR)$(PREFIX).
.PHONY: install
install: all $(foreach t,$(_mm_pc_libs),$(call _mm_pc,$t))
	$(call _mm_say,$(PROJECT_NAME),INSTALL,$(_mm_dest))
	$(Q)mkdir -p $(_mm_dest)/lib/pkgconfig
	$(foreach t,$(_mm_installed),$(call _mm_install_target,$t))

###############################################################################
# Help
###############################################################################

_mm_kind = $(if $($1.GIT),external $(if $(filter header-only,$($1.TYPE)),headers,$($1.TYPE)),$($1.TYPE))

#? List the targets and what they depend on.
.PHONY: list-targets
list-targets:
	$(foreach t,$(TARGETS),$(info $t ($(call _mm_kind,$t))$(if $($t.DEPENDS),: $($t.DEPENDS))))
	@$(_mm_noop)

#? Print this help.
.PHONY: help
help:
	$(info Project $(PROJECT_NAME) $(PROJECT_VERSION), build in $(BUILD))
	$(info $(_mm_space) TOOLCHAIN=$(TOOLCHAIN) ($(COMPILER_FAMILY) $(COMPILER_VERSION)) TARGET_OS=$(TARGET_OS) COMPILATION_MODE=$(COMPILATION_MODE))
	$(info )
	$(info Goals:)
	$(info $(_mm_space) all               build every target except the tests (default))
	$(info $(_mm_space) <target>          build one target and what it depends on)
	$(info $(_mm_space) run-<target>      build and run an executable, with ARGS="...")
	$(info $(_mm_space) check             build and run the tests)
	$(info $(_mm_space) clean-<target>    remove the build of one target)
	$(info $(_mm_space) clean, distclean  remove the build of this configuration, of all)
	$(info $(_mm_space) install           install in DESTDIR/PREFIX ($(_mm_dest)))
	$(info $(_mm_space) compile-commands  write compile_commands.json)
	$(info $(_mm_space) list-targets      list the targets)
	$(info )
	$(info Options: COMPILATION_MODE=debug|normal|release TOOLCHAIN=gcc|clang|mingw|emscripten|msvc)
	$(info $(_mm_space)        V=1 COVERAGE=1 SANITIZER=address|undefined|thread BUILD_DIR=build)
	$(info )
	$(info Targets: $(TARGETS))
	@$(_mm_noop)
