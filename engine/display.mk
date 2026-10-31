###############################################################################
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-MyMakefile-Commercial
# Copyright (c) 2019-2026 Quentin Quadrat
#
# This file is part of MyMakefile. See LICENSING.md for details.
###############################################################################
#
# Colored messages, as in MyMakefile 2:
#   *** Compiling C++: OpenGlassBox <= src/City.cpp
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

# $1: action, $2: target, $3: file read (print-from) or written (print-to)
print-simple = $(info $(PURPLE)*** $1: $(CYAN)$2$(COLOR_DEFAULT)$3)
print-from = $(info $(PURPLE)*** $1: $(CYAN)$2$(COLOR_DEFAULT) <= $(YELLOW)$3$(COLOR_DEFAULT))
print-to = $(info $(PURPLE)*** $1: $(CYAN)$2$(COLOR_DEFAULT) => $(YELLOW)$3$(COLOR_DEFAULT))
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
