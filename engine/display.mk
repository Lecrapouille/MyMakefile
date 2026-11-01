###############################################################################
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
###############################################################################
#
# Colored messages, as in MyMakefile 2:
#   [ 42%] Compiling C++: OpenGlassBox <= src/City.cpp
#   *** Linking: OpenGlassBox-demo => build/linux-gcc-normal/bin/OpenGlassBox-demo
#
# Colors are on when make writes to a terminal, off otherwise (CI logs, pipes)
# and with cmd.exe. COLORS=1 or COLORS=0 forces them; NO_COLOR (no-color.org)
# turns them off.

ifneq ($(filter 0 no off false,$(COLORS)),)
    USE_COLORS :=
else ifneq ($(COLORS),)
    USE_COLORS := 1
else ifneq ($(NO_COLOR),)
    USE_COLORS :=
else ifeq ($(HOST_SHELL),cmd)
    USE_COLORS :=
else
    USE_COLORS := $(if $(MAKE_TERMOUT),1)
endif

# The escape character itself: make has no other way to write it.
ESC := 

ifneq ($(USE_COLORS),)
    COLOR_DEFAULT := $(ESC)[00m
    RED := $(ESC)[31m
    GREEN := $(ESC)[32m
    YELLOW := $(ESC)[33m
    BLUE := $(ESC)[34m
    PURPLE := $(ESC)[35m
    CYAN := $(ESC)[36m
    COLOR_INFO := $(ESC)[42m
    COLOR_WARNING := $(ESC)[43m
    COLOR_ERROR := $(ESC)[41m
else
    COLOR_DEFAULT :=
    RED :=
    GREEN :=
    YELLOW :=
    BLUE :=
    PURPLE :=
    CYAN :=
    COLOR_INFO :=
    COLOR_WARNING :=
    COLOR_ERROR :=
endif

###############################################################################
# Messages printed by make itself ($(info)): no process is started. In a
# recipe they come out when the recipe starts, before its first command.
###############################################################################

# $1: action, $2: target, $3: file read (print-from) or written (print-to),
# $4: what print-to adds in the color of the text, between brackets
print-simple = $(info $(PURPLE)*** $1: $(CYAN)$2$(COLOR_DEFAULT)$3)
print-from = $(info $(PURPLE)*** $1: $(CYAN)$2$(COLOR_DEFAULT) <= $(YELLOW)$3$(COLOR_DEFAULT))
print-to = $(info $(PURPLE)*** $1: $(CYAN)$2$(COLOR_DEFAULT) => $(YELLOW)$3$(COLOR_DEFAULT)$(if $4, [$4]))
print-ok = $(info $(GREEN)*** $1$(COLOR_DEFAULT))
print-info = $(info $(COLOR_INFO)!!! $1 !!!$(COLOR_DEFAULT))
print-warning = $(info $(COLOR_WARNING)!!! $1 !!!$(COLOR_DEFAULT))
fail = $(error $(RED)MyMakefile: $1$(COLOR_DEFAULT))

###############################################################################
# The same, as a command: for a message between two commands of a recipe.
###############################################################################

ifeq ($(HOST_SHELL),cmd)
    echo-text = echo $(subst >,^>,$(subst <,^<,$(subst |,^|,$(subst &,^&,$1))))
else
    echo-text = echo '$(subst ','\'',$1)'
endif
echo-simple = $(call echo-text,$(PURPLE)*** $1: $(CYAN)$2$(COLOR_DEFAULT)$3)

###############################################################################
# Percentage of the compilations, printed before each file compiled:
#   [ 42%] Compiling C++: OpenGlassBox <= src/City.cpp
# make cannot know before running which objects are out of date: when the
# first file is compiled, a dry run of the same goals counts the compilations
# make will do (once, and only when something is compiled). The percentage is
# then counted without a process: each compilation adds 100 words to an
# accumulator, and each TOTAL words taken from it add one percent.
# PROGRESS=0 turns it off.
###############################################################################

# Goals of the dry run: those of make, without the cleaning goals (already
# done), 'rebuild' (it removes the build) and the goals calling make again.
progress-goals = $(or $(strip $(filter-out $(PASSIVE_GOALS) rebuild coverity rpm,$(MAKECMDGOALS)) $(if $(filter rebuild,$(MAKECMDGOALS)),all)),all)
progress-count = $(words $(filter MYMAKEFILE-COMPILES,$(shell $(MAKE) -n -j1 --no-print-directory -C $(CURDIR) -f $(abspath $(firstword $(MAKEFILE_LIST))) $(progress-goals) PROGRESS_COUNTING=1 2>$(DEVNULL))))

PROGRESS_TOTAL = $(eval PROGRESS_TOTAL := $(progress-count))$(PROGRESS_TOTAL)
PROGRESS_ACC :=
PROGRESS_PERCENT :=
PROGRESS_HUNDRED := $(foreach i,0 1 2 3 4 5 6 7 8 9,x x x x x x x x x x)

# The words of $1 but the first.
progress-drop = $(wordlist 2,$(words $1),$1)
progress-carry = $(if $(word $(PROGRESS_TOTAL),$(PROGRESS_ACC)),$(eval PROGRESS_ACC := $(call progress-drop,$(wordlist $(PROGRESS_TOTAL),$(words $(PROGRESS_ACC)),$(PROGRESS_ACC))))$(eval PROGRESS_PERCENT += x)$(call progress-carry))
progress-number = $(if $(word 100,$(PROGRESS_PERCENT)),100,$(words $(PROGRESS_PERCENT)))
progress-step = $(eval PROGRESS_ACC += $(PROGRESS_HUNDRED))$(call progress-carry)[$(if $(word 10,$(PROGRESS_PERCENT)),,$(SPACE))$(if $(word 100,$(PROGRESS_PERCENT)),,$(SPACE))$(progress-number)%]

# $1: action, $2: target, $3: file compiled. The dry run only counts.
ifneq ($(PROGRESS_COUNTING),)
    print-compile = $(info MYMAKEFILE-COMPILES)
else ifeq ($(filter 0 no off false,$(PROGRESS)),)
    print-compile = $(info $(PURPLE)$(if $(filter-out 0,$(PROGRESS_TOTAL)),$(progress-step),***) $1: $(CYAN)$2$(COLOR_DEFAULT) <= $(YELLOW)$3$(COLOR_DEFAULT))
else
    print-compile = $(print-from)
endif
